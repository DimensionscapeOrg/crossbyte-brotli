#include <hxcpp.h>
#include "NativeBrotli.h"

#include <brotli/decode.h>
#include <brotli/encode.h>

#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <string>

/*
 * Every codec call copies its input out of the collector's memory and then
 * runs in a GC-free zone. A collection needs every thread at a safe point,
 * and a thread inside a long native call never reaches one: compressing 2 MB
 * at quality 11 on a worker held up every allocation on every other thread
 * for the whole 1.8 seconds.
 *
 * Nothing inside a zone may touch a Haxe object or throw, so the codec work
 * reports a status, and the Array is made, or the error thrown, once the zone
 * is left.
 */

namespace {

enum Status {
	STATUS_OK = 0,
	STATUS_INVALID,
	STATUS_LIMIT,
	STATUS_NO_MEMORY
};

// Copies input[0, length) into memory the collector does not own. Null for an
// empty input, which both codecs accept.
uint8_t* copyInput(Array<unsigned char> input, int length) {
	if (length < 0 || (length > 0 && (input.mPtr == 0 || length > input->length))) {
		hx::Throw(HX_CSTRING("Invalid Brotli input buffer."));
	}
	if (length == 0) {
		return 0;
	}
	uint8_t* copy = (uint8_t*)malloc((size_t)length);
	if (copy == 0) {
		hx::Throw(HX_CSTRING("Out of memory copying the Brotli input."));
	}
	memcpy(copy, input->GetBase(), (size_t)length);
	return copy;
}

// The window a stream of `length` bytes is written with: the smallest that
// holds all of it, since that is what the decoder at the other end allocates,
// and never past the library's default. 16 costs one header bit and 17 seven,
// so an input between the two goes up to 18, which costs four.
int windowBitsFor(size_t length) {
	if (length <= ((size_t)1 << 16) - 16) {
		return 16;
	}
	int bits = 18;
	while (bits < BROTLI_DEFAULT_WINDOW && ((size_t)1 << bits) - 16 < length) {
		bits++;
	}
	return bits;
}

// Decodes source[0, length) into a buffer of its own, giving the decoder room
// for `limit` bytes and no more. When it asks for more than that it is
// stopped: it may have decoded up to a window ahead into its ring buffer (16
// MB at most), but never the rest of the stream. Runs in a GC-free zone.
Status decode(const uint8_t* source, size_t length, size_t limit, uint8_t** out, size_t* produced, BrotliDecoderErrorCode* error) {
	BrotliDecoderState* state = BrotliDecoderCreateInstance(0, 0, 0);
	if (state == 0) {
		return STATUS_NO_MEMORY;
	}

	// A stream says nothing of its size, so the buffer starts at a guess and
	// doubles, never past the limit.
	size_t capacity = length < limit / 4 ? length * 4 : limit;
	if (capacity < 4096) {
		capacity = limit < 4096 ? limit : 4096;
	}
	uint8_t* buffer = (uint8_t*)malloc(capacity);
	if (buffer == 0) {
		BrotliDecoderDestroyInstance(state);
		return STATUS_NO_MEMORY;
	}

	Status status = STATUS_OK;
	size_t size = 0;
	const uint8_t* nextIn = source;
	size_t availableIn = length;
	for (;;) {
		uint8_t* nextOut = buffer + size;
		size_t availableOut = capacity - size;
		BrotliDecoderResult result = BrotliDecoderDecompressStream(state, &availableIn, &nextIn, &availableOut, &nextOut, 0);
		size = capacity - availableOut;
		if (result == BROTLI_DECODER_RESULT_SUCCESS) {
			break;
		}
		// NEEDS_MORE_OUTPUT comes only with the buffer full and output still
		// to give. A stream cut short says NEEDS_MORE_INPUT instead, whatever
		// it has decoded and not yet handed over, so that is asked for too:
		// what it has produced counts against the limit before where it ends
		// does, as it does in the Haxe decoder.
		if (result == BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT
			|| (result == BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT && BrotliDecoderHasMoreOutput(state))) {
			if (capacity >= limit) {
				status = STATUS_LIMIT;
				break;
			}
			size_t grown = capacity > limit / 2 ? limit : capacity * 2;
			uint8_t* bigger = (uint8_t*)realloc(buffer, grown);
			if (bigger == 0) {
				status = STATUS_NO_MEMORY;
				break;
			}
			buffer = bigger;
			capacity = grown;
			continue;
		}
		// An error, or NEEDS_MORE_INPUT with all of it given: the stream
		// ends before it says it does.
		*error = BrotliDecoderGetErrorCode(state);
		bool allocation = *error <= BROTLI_DECODER_ERROR_ALLOC_CONTEXT_MODES && *error >= BROTLI_DECODER_ERROR_ALLOC_BLOCK_TYPE_TREES;
		status = allocation ? STATUS_NO_MEMORY : STATUS_INVALID;
		break;
	}
	BrotliDecoderDestroyInstance(state);

	if (status != STATUS_OK) {
		free(buffer);
		return status;
	}
	*out = buffer;
	*produced = size;
	return STATUS_OK;
}

} // namespace

bool crossbyte_brotli_available() {
	return true;
}

String crossbyte_brotli_version() {
	uint32_t version = BrotliEncoderVersion();
	int major = (version >> 24) & 0xFF;
	int minor = (version >> 12) & 0xFFF;
	int patch = version & 0xFFF;
	std::string label = "google-brotli-" + std::to_string(major) + "." + std::to_string(minor) + "." + std::to_string(patch);
	return String::create(label.c_str(), (int)label.size());
}

Array<unsigned char> crossbyte_brotli_compress(Array<unsigned char> input, int inputLength, int quality) {
	if (inputLength < 0 || quality < 0 || quality > 11) {
		hx::Throw(HX_CSTRING("Invalid Brotli compression arguments."));
	}

	size_t bound = BrotliEncoderMaxCompressedSize((size_t)inputLength);
	if (bound == 0 || bound > (size_t)INT_MAX) {
		hx::Throw(HX_CSTRING("Brotli input too large."));
	}
	uint8_t* source = copyInput(input, inputLength);
	uint8_t* output = (uint8_t*)malloc(bound);
	if (output == 0) {
		free(source);
		hx::Throw(HX_CSTRING("Out of memory for the Brotli output."));
	}

	size_t encodedSize = bound;
	BROTLI_BOOL ok;
	{
		hx::AutoGCFreeZone zone;
		ok = BrotliEncoderCompress(quality, windowBitsFor((size_t)inputLength), BROTLI_MODE_GENERIC, (size_t)inputLength, source, &encodedSize, output);
	}
	free(source);
	if (!ok) {
		free(output);
		hx::Throw(HX_CSTRING("Native Brotli compression failed."));
	}

	Array<unsigned char> result = Array_obj<unsigned char>::fromData(output, (int)encodedSize);
	free(output);
	return result;
}

Array<unsigned char> crossbyte_brotli_decompress(Array<unsigned char> input, int inputLength, int maxOutputSize) {
	uint8_t* source = copyInput(input, inputLength);
	// The caller's limit, or failing one the most an Array can hold.
	size_t limit = maxOutputSize > 0 ? (size_t)maxOutputSize : (size_t)INT_MAX;

	uint8_t* output = 0;
	size_t produced = 0;
	BrotliDecoderErrorCode error = BROTLI_DECODER_NO_ERROR;
	Status status;
	{
		hx::AutoGCFreeZone zone;
		status = decode(source, (size_t)inputLength, limit, &output, &produced, &error);
	}
	free(source);

	switch (status) {
		case STATUS_LIMIT:
			// Null: the stream decodes past the limit. The caller names it.
			return Array<unsigned char>();
		case STATUS_NO_MEMORY:
			hx::Throw(HX_CSTRING("Out of memory decoding Brotli."));
			break;
		case STATUS_INVALID: {
			if (error == BROTLI_DECODER_NEEDS_MORE_INPUT || error == BROTLI_DECODER_SUCCESS) {
				hx::Throw(HX_CSTRING("the stream ends early"));
			}
			// The library's name for it, "_ERROR_FORMAT_PADDING_1" and the
			// like, less the leading underscore.
			const char* name = BrotliDecoderErrorString(error);
			if (name[0] == '_') {
				name++;
			}
			hx::Throw(String::create(name, (int)strlen(name)));
			break;
		}
		default:
			break;
	}

	Array<unsigned char> result = Array_obj<unsigned char>::fromData(output, (int)produced);
	free(output);
	return result;
}
