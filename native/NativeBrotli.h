#ifndef CROSSBYTE_NATIVE_BROTLI_H
#define CROSSBYTE_NATIVE_BROTLI_H

#include <hx/CFFI.h>

bool crossbyte_brotli_available();
::String crossbyte_brotli_version();
Array<unsigned char> crossbyte_brotli_compress(Array<unsigned char> input, int inputLength, int quality);
// Null when the stream decodes past maxOutputSize (0: no limit); throws a
// String when it is not valid Brotli.
Array<unsigned char> crossbyte_brotli_decompress(Array<unsigned char> input, int inputLength, int maxOutputSize);

#endif
