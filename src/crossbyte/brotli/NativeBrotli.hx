package crossbyte.brotli;

import crossbyte.brotli._internal.NativeBrotliBridge;
import haxe.io.Bytes;

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

	public static function compress(bytes:Bytes, quality:Int = 4):Bytes {
		if (quality < 0 || quality > 11) {
			throw "Brotli quality must be between 0 and 11";
		}

		#if (cpp && crossbyte_brotli_native)
		var input = bytes == null ? __empty : bytes;
		return Bytes.ofData(NativeBrotliBridge.compress(input.getData(), input.length, quality));
		#else
		throw "Native Brotli is only available on cpp targets with -D crossbyte_brotli_native.";
		#end
	}

	public static function decompress(bytes:Bytes):Bytes {
		#if (cpp && crossbyte_brotli_native)
		var input = bytes == null ? __empty : bytes;
		return Bytes.ofData(NativeBrotliBridge.decompress(input.getData(), input.length));
		#else
		throw "Native Brotli is only available on cpp targets with -D crossbyte_brotli_native.";
		#end
	}
}
