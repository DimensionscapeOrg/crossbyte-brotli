#ifndef CROSSBYTE_NATIVE_BROTLI_H
#define CROSSBYTE_NATIVE_BROTLI_H

#include <hx/CFFI.h>

bool crossbyte_brotli_available();
::String crossbyte_brotli_version();
Array<unsigned char> crossbyte_brotli_compress(Array<unsigned char> input, int inputLength, int quality);
Array<unsigned char> crossbyte_brotli_decompress(Array<unsigned char> input, int inputLength);

#endif
