package crossbyte.brotli;

import crossbyte.errors.IOError;
import crossbyte.errors.RangeError;
import crossbyte.io.ByteArray;
import crossbyte.utils.CompressionAlgorithm;
import haxe.io.Bytes;
import utest.Assert;

#if cpp
// The process's peak resident set, for the tests that say a call did not take
// memory it had no need of.
@:cppFileCode('#ifdef HX_WINDOWS\n#ifndef NOMINMAX\n#define NOMINMAX\n#endif\n#include <windows.h>\n#include <psapi.h>\n#pragma comment(lib, "psapi.lib")\n#else\n#include <sys/resource.h>\n#endif\nstatic double crossbyte_test_peak_megabytes() {\n#ifdef HX_WINDOWS\n\tPROCESS_MEMORY_COUNTERS counters;\n\tif (!GetProcessMemoryInfo(GetCurrentProcess(), &counters, sizeof(counters))) return 0;\n\treturn (double)counters.PeakWorkingSetSize / 1048576.0;\n#else\n\tstruct rusage usage;\n\tif (getrusage(RUSAGE_SELF, &usage) != 0) return 0;\n#ifdef __APPLE__\n\treturn (double)usage.ru_maxrss / 1048576.0;\n#else\n\treturn (double)usage.ru_maxrss / 1024.0;\n#endif\n#endif\n}\n')
#end
class NativeBrotliTest extends utest.Test {
	#if (cpp && crossbyte_brotli_native)
	/** 211 bytes that decode to 256 MB of zeros, declaring a 16 MB window. **/
	private static inline var BOMB_256_MB:String = "cfffff7ff82700e2b14020f7fe9ffffffff04f00c4610180eefd3fffffffe19f0088c32200ddfb7ffeffffc33f0110870500baf7fffcffff877f02200e0b0074effff9ffff0fff04401c1600e8defff3ffff1ffe0980382c00d0bdffe7ffff3ffc1300715800a07bffcfffff7ff82700e2b00040f7fe9ffffffff04f00c4610180eefd3fffffffe19f0088c30200ddfb7ffeffffc33f0110870500baf7fffcffff877f02200e0b0074effff9ffff0fff04401c1600e8defff3ffff1ffe0980382c00d0bdffcfffff7ffc1300715800a07bff0f";

	/** What refusing the bomb in `setupClass` did: the error, and the peak's growth in MB. **/
	private static var __bombRefusal:Dynamic = null;
	private static var __bombGrowth:Int = -1;

	/**
		The bomb is refused here rather than in its test: the process's peak
		is what says whether the memory was taken, and the other tests here
		raise it, in whatever order they run.
	**/
	public function setupClass():Void {
		var bomb = Bytes.ofHex(BOMB_256_MB);
		var before = __peakMegabytes();
		try {
			NativeBrotli.decompress(bomb, 1 << 20);
		} catch (e:Dynamic) {
			__bombRefusal = e;
		}
		__bombGrowth = __peakMegabytes() - before;
	}
	#end

	public function testAvailabilityMatchesBuildDefine():Void {
		#if (cpp && crossbyte_brotli_native)
		Assert.isTrue(NativeBrotli.isAvailable());
		Assert.isTrue(NativeBrotli.version().indexOf("google-brotli-") == 0);
		#else
		Assert.isFalse(NativeBrotli.isAvailable());
		Assert.equals("unavailable", NativeBrotli.version());
		#end
	}

	#if (cpp && crossbyte_brotli_native)
	public function testNativeRoundTrip():Void {
		var input = Bytes.ofString("hello native brotli hello native brotli");
		var compressed = NativeBrotli.compress(input, 4);
		var decompressed = NativeBrotli.decompress(compressed);

		Assert.equals(input.toString(), decompressed.toString());
	}

	public function testNativeDecodesKnownFixture():Void {
		var encoded = Bytes.ofHex("0b0c8068656c6c6f2066726f6d2062726f746c69206669787475726503");
		Assert.equals("hello from brotli fixture", NativeBrotli.decompress(encoded).toString());
	}

	public function testCoreAndNativeCanDecodeEachOther():Void {
		var input = Bytes.ofString("oracle parity payload");
		var coreEncoded:ByteArray = ByteArray.fromBytes(input);
		coreEncoded.compress(CompressionAlgorithm.BROTLI);
		Assert.equals(input.toString(), NativeBrotli.decompress(coreEncoded).toString());

		var nativeEncoded = NativeBrotli.compress(input, 4);
		var coreDecoded:ByteArray = ByteArray.fromBytes(nativeEncoded);
		coreDecoded.uncompress(CompressionAlgorithm.BROTLI);
		Assert.equals(input.toString(), coreDecoded.toString());
	}

	public function testNativeRejectsInvalidPayload():Void {
		Assert.raises(() -> NativeBrotli.decompress(Bytes.ofString("not brotli")), IOError);
		// Nothing at all is a stream that ends before its first header.
		Assert.raises(() -> NativeBrotli.decompress(Bytes.alloc(0)), IOError);
		var whole = NativeBrotli.compress(__text(4096), 4);
		Assert.raises(() -> NativeBrotli.decompress(whole.sub(0, whole.length - 1)), IOError);
	}

	public function testNativeStopsAtTheLimit():Void {
		// 256 MB of zeros in 211 bytes, in 16 MB meta-blocks. The decoder has
		// room for 1 MB and is stopped when it asks for more, and its ring
		// buffer is held to what 1 MB could need, so the first meta-block is
		// refused at its header. It used to decode the lot into a vector, copy
		// that into an Array, and only then let the caller measure it: the
		// process peaked 500 MB higher to refuse it. (It is refused in
		// setupClass; see there.)
		Assert.isOfType(__bombRefusal, RangeError, "a 256 MB stream at 1 MB: " + Std.string(__bombRefusal));
		Assert.isTrue(__bombGrowth >= 0 && __bombGrowth < 64, 'refusing a 256 MB stream at 1 MB raised the peak by $__bombGrowth MB');
	}

	public function testNativeHoldsItsOwnMemoryToTheLimit():Void {
		// CF FF FF FF: a 16 MB window, then a 16 MB uncompressed meta-block,
		// then nothing. The library sizes its ring buffer from that header
		// before it reads a byte of data, so four bytes cost 16 MB whatever
		// the limit, and said only that the stream ended early. Its
		// allocations are now counted against what the limit could need.
		var refusal:Dynamic = null;
		try {
			NativeBrotli.decompress(Bytes.ofHex("cfffffff"), 1 << 20);
		} catch (e:Dynamic) {
			refusal = e;
		}
		Assert.isOfType(refusal, RangeError, "four bytes announcing 16 MB, at a 1 MB limit: " + Std.string(refusal));

		// Within the limit it is only a stream cut short.
		Assert.raises(() -> NativeBrotli.decompress(Bytes.ofHex("cfffffff"), 32 << 20), IOError);
	}

	public function testNativeLimitComesBeforeWhereTheStreamEnds():Void {
		// 2 MB, one byte short of its end. The decoder hands a meta-block
		// over as it finishes it, so it reaches the missing byte holding
		// more than it has handed over, and says only that it needs more
		// input. What it has decoded is past the limit, and that is what the
		// caller hears, as from the Haxe decoder. The limit used to be
		// applied, if at all, by the caller afterwards.
		var whole = NativeBrotli.compress(__text(2 << 20), 4);
		var cut = whole.sub(0, whole.length - 1);

		Assert.raises(() -> NativeBrotli.decompress(cut, 1 << 20), RangeError);
		Assert.raises(() -> NativeBrotli.decompress(cut, 3 << 20), IOError);
		Assert.raises(() -> NativeBrotli.decompress(cut), IOError);
	}

	public function testByteArrayHandsTheLimitDown():Void {
		// CrossByte's ByteArray, on this backend, passes its limit down
		// rather than decoding the whole stream here and measuring it
		// afterwards -- which heard only that a stream cut short past the
		// limit was cut short.
		var whole = NativeBrotli.compress(__text(2 << 20), 4);
		var cut:ByteArray = ByteArray.fromBytes(whole.sub(0, whole.length - 1));
		Assert.raises(() -> cut.uncompress(CompressionAlgorithm.BROTLI, 1 << 20), RangeError);
	}

	public function testNativeLimitIsExact():Void {
		var input = __text(100000);
		var packed = NativeBrotli.compress(input, 4);

		Assert.equals(0, NativeBrotli.decompress(packed, input.length).compare(input));
		Assert.raises(() -> NativeBrotli.decompress(packed, input.length - 1), RangeError);
		Assert.equals(0, NativeBrotli.decompress(packed, 0).compare(input));
	}

	public function testNativeWindowFitsTheInput():Void {
		// The window is what the decoder at the other end allocates, so a
		// small body says so: WBITS 16 is the single bit 0. It was the
		// library's default of 22 whatever the size.
		var body = NativeBrotli.compress(Bytes.ofString("{\"ok\":true}"), 4);
		Assert.equals(0, body.get(0) & 1, "an 11-byte body asks for more than a 64 KB window");

		// Past 64 KB the window grows to fit, and still round trips.
		var input = __text(300000);
		Assert.equals(0, NativeBrotli.decompress(NativeBrotli.compress(input, 4)).compare(input));
	}

	public function testCompressLeavesTheCollectorFree():Void {
		// A collection needs every thread at a safe point, and a thread in a
		// native call reaches none until it returns. Compressing outside a
		// GC-free zone held every allocation on every other thread for the
		// whole call: 1.8 s of a 1.8 s compress.
		var text = __text(1 << 19);
		var finished = new sys.thread.Deque<Float>();
		sys.thread.Thread.create(() -> {
			var t0 = haxe.Timer.stamp();
			NativeBrotli.compress(text, 11);
			finished.add(haxe.Timer.stamp() - t0);
		});

		// Meanwhile, what any other thread does: small allocations, enough of
		// them to need collections.
		var longest:Float = 0;
		var last:Float = haxe.Timer.stamp();
		var keep:Array<Array<Int>> = [];
		var took:Null<Float> = null;
		var iterations:Int = 0;
		while (took == null) {
			keep[iterations++ & 1023] = [for (i in 0...64) i];
			var now = haxe.Timer.stamp();
			if (now - last > longest) {
				longest = now - last;
			}
			last = now;
			took = finished.pop(false);
		}

		Assert.isTrue(longest < took / 2,
			'this thread stalled ${Math.round(longest * 1000)} ms of a ${Math.round(took * 1000)} ms compress on another');
	}

	private static function __peakMegabytes():Int {
		var peak:Float = untyped __cpp__("crossbyte_test_peak_megabytes()");
		return Math.round(peak);
	}

	/** Deterministic text: words, so it compresses the way a page does. **/
	private static function __text(length:Int):Bytes {
		var words = ["the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog", "while", "native", "brotli", "decodes", "a", "stream"];
		var out = Bytes.alloc(length);
		var seed = 0x2545F491;
		var at = 0;
		while (at < length) {
			seed ^= seed << 13;
			seed ^= seed >>> 17;
			seed ^= seed << 5;
			var word = words[(seed >>> 1) % words.length];
			for (i in 0...word.length) {
				if (at < length) {
					out.set(at++, StringTools.fastCodeAt(word, i));
				}
			}
			if (at < length) {
				out.set(at++, (seed & 15) == 0 ? ".".code : " ".code);
			}
		}
		return out;
	}
	#end
}
