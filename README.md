# crossbyte-brotli

Optional native Brotli backend and oracle for CrossByte.

The extension wraps Google's MIT-licensed Brotli C encoder/decoder for hxcpp
targets. CrossByte core remains pure Haxe by default; projects can opt into the
native backend with:

```hxml
-lib crossbyte-brotli
-D crossbyte_brotli_native
```

The vendored Brotli C sources live under `native/vendor/brotli`.
