package crossbyte.brotli;

class NativeBrotliTestMain {
	public static function main():Void {
		crossbyte.test.TestHarness.run(runner -> runner.addCase(new NativeBrotliTest()));
	}
}
