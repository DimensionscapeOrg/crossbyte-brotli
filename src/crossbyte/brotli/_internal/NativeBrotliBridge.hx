package crossbyte.brotli._internal;

#if (cpp && crossbyte_brotli_native)
@:buildXml("
<files id='haxe'>
	<compilerflag value='-I${haxelib:crossbyte-brotli}/native'/>
	<compilerflag value='-I${haxelib:crossbyte-brotli}/native/vendor/brotli/c/include'/>
	<file name='${haxelib:crossbyte-brotli}/native/NativeBrotli.cpp'>
		<depend name='${haxelib:crossbyte-brotli}/native/NativeBrotli.h'/>
	</file>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/common/constants.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/common/context.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/common/dictionary.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/common/platform.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/common/shared_dictionary.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/common/transform.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/dec/bit_reader.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/dec/decode.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/dec/huffman.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/dec/prefix.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/dec/state.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/dec/static_init.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/backward_references.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/backward_references_hq.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/bit_cost.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/block_splitter.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/brotli_bit_stream.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/cluster.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/command.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/compound_dictionary.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/compress_fragment.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/compress_fragment_two_pass.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/dictionary_hash.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/encode.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/encoder_dict.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/entropy_encode.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/fast_log.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/histogram.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/literal_cost.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/memory.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/metablock.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/static_dict.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/static_dict_lut.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/static_init.c'/>
	<file name='${haxelib:crossbyte-brotli}/native/vendor/brotli/c/enc/utf8_util.c'/>
</files>
")
@:include("NativeBrotli.h")
extern class NativeBrotliBridge {
	@:native("crossbyte_brotli_available") public static function isAvailable():Bool;
	@:native("crossbyte_brotli_version") public static function version():String;
	@:native("crossbyte_brotli_compress") public static function compress(input:haxe.io.BytesData, inputLength:Int, quality:Int):haxe.io.BytesData;
	@:native("crossbyte_brotli_decompress") public static function decompress(input:haxe.io.BytesData, inputLength:Int):haxe.io.BytesData;
}
#else
extern class NativeBrotliBridge {}
#end
