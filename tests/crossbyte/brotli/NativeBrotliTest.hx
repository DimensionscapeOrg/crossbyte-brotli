package crossbyte.brotli;

import crossbyte.io.ByteArray;
import crossbyte.utils.CompressionAlgorithm;
import haxe.io.Bytes;
import utest.Assert;

class NativeBrotliTest extends utest.Test {
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
		Assert.raises(() -> NativeBrotli.decompress(Bytes.ofString("not brotli")));
	}
	#end
}
