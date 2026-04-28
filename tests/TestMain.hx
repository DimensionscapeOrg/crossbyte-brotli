import crossbyte.brotli.NativeBrotliTest;

class TestMain {
	public static function main():Void {
		crossbyte.test.TestHarness.run(runner -> runner.addCase(new NativeBrotliTest()));
	}
}
