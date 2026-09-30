package crossbyte.brotli;

import crossbyte.brotli._internal.NativeBrotliBridge;
import crossbyte.errors.ArgumentError;
import crossbyte.errors.IOError;
import crossbyte.errors.RangeError;
import haxe.io.Bytes;

/**
	Google's Brotli library, for hxcpp builds with `-D crossbyte_brotli_native`.

	Each call copies its input out of the collector's memory and runs the codec
	in a GC-free zone, so a long compress on one thread does not hold up the
	collections every other thread is waiting on.
**/
class NativeBrotli {
	private static final __empty:Bytes = Bytes.alloc(0);

	public static inline function isAvailable():Bool {
		#if (cpp && crossbyte_brotli_native)
		return NativeBrotliBridge.isAvailable();
		#else
		return false;
		#end
	}

	public static inline function version():String {
		#if (cpp && crossbyte_brotli_native)
		return NativeBrotliBridge.version();
		#else
		return "unavailable";
		#end
	}

	/**
		Compresses `bytes` as one Brotli stream.

		@throws ArgumentError `quality` is not between 0 and 11.
	**/
	public static function compress(bytes:Bytes, quality:Int = 4):Bytes {
		if (quality < 0 || quality > 11) {
			throw new ArgumentError("Brotli quality must be between 0 and 11, not " + quality);
		}

		#if (cpp && crossbyte_brotli_native)
		var input = bytes == null ? __empty : bytes;
		return Bytes.ofData(NativeBrotliBridge.compress(input.getData(), input.length, quality));
		#else
		throw "Native Brotli is only available on cpp targets with -D crossbyte_brotli_native.";
		#end
	}

	/**
		Decodes one Brotli stream. Bytes after its end are ignored.

		@param maxOutputSize Bytes to produce before giving up, or `0` for no
		       limit. Brotli ratios have no ceiling, so anything decoding a
		       stream it did not author wants to name one. The decoder is
		       given room for that many bytes and is stopped when it asks for
		       more. By then it may have decoded up to one window ahead into
		       its own ring buffer, the window the stream declares, 16 MB
		       at most, but never the rest of the stream.

		@throws IOError The data is not a valid Brotli stream.
		@throws RangeError It decodes past `maxOutputSize`.
	**/
	public static function decompress(bytes:Bytes, maxOutputSize:Int = 0):Bytes {
		#if (cpp && crossbyte_brotli_native)
		var input = bytes == null ? __empty : bytes;
		var data:haxe.io.BytesData;
		try {
			data = NativeBrotliBridge.decompress(input.getData(), input.length, maxOutputSize);
		} catch (e:String) {
			throw new IOError("Invalid Brotli data: " + e);
		}
		if (data == null) {
			throw new RangeError("Brotli stream exceeded " + (maxOutputSize > 0 ? maxOutputSize : 0x7FFFFFFF) + " bytes");
		}
		return Bytes.ofData(data);
		#else
		throw "Native Brotli is only available on cpp targets with -D crossbyte_brotli_native.";
		#end
	}
}
