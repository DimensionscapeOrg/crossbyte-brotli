#include <hxcpp.h>
#include "NativeBrotli.h"

#include <brotli/decode.h>
#include <brotli/encode.h>

#include <stdint.h>
#include <string>
#include <vector>

namespace {
const uint8_t* crossbyte_brotli_input(Array<unsigned char> input, int inputLength) {
	if (inputLength <= 0) {
		return 0;
	}
	if (input.mPtr == 0 || inputLength > input->length) {
		hx::Throw(HX_CSTRING("Invalid Brotli input buffer."));
		return 0;
	}
	return reinterpret_cast<const uint8_t*>(input->GetBase());
}
}

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

	const uint8_t* nextIn = crossbyte_brotli_input(input, inputLength);
	size_t maxOutput = BrotliEncoderMaxCompressedSize((size_t)inputLength);
	if (maxOutput == 0) {
		maxOutput = 1;
	}

	std::vector<uint8_t> output(maxOutput);
	size_t encodedSize = maxOutput;
	BROTLI_BOOL ok = BrotliEncoderCompress(quality, BROTLI_DEFAULT_WINDOW, BROTLI_MODE_GENERIC, (size_t)inputLength, nextIn, &encodedSize, output.data());
	if (!ok) {
		hx::Throw(HX_CSTRING("Native Brotli compression failed."));
	}

	return Array_obj<unsigned char>::fromData(output.data(), (int)encodedSize);
}

Array<unsigned char> crossbyte_brotli_decompress(Array<unsigned char> input, int inputLength) {
	if (inputLength < 0) {
		hx::Throw(HX_CSTRING("Invalid Brotli input length."));
	}

	const uint8_t* nextIn = crossbyte_brotli_input(input, inputLength);
	size_t availableIn = (size_t)inputLength;
	std::vector<uint8_t> output;
	BrotliDecoderState* state = BrotliDecoderCreateInstance(0, 0, 0);
	if (state == 0) {
		hx::Throw(HX_CSTRING("Failed to create Brotli decoder."));
	}

	BrotliDecoderResult result = BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT;
	uint8_t buffer[16384];
	do {
		uint8_t* nextOut = buffer;
		size_t availableOut = sizeof(buffer);
		result = BrotliDecoderDecompressStream(state, &availableIn, &nextIn, &availableOut, &nextOut, 0);
		size_t produced = sizeof(buffer) - availableOut;
		if (produced > 0) {
			output.insert(output.end(), buffer, buffer + produced);
		}
	} while (result == BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT);

	BrotliDecoderDestroyInstance(state);
	if (result != BROTLI_DECODER_RESULT_SUCCESS) {
		hx::Throw(HX_CSTRING("Native Brotli decompression failed."));
	}

	return output.empty()
		? Array_obj<unsigned char>::__new(0, 0)
		: Array_obj<unsigned char>::fromData(output.data(), (int)output.size());
}
