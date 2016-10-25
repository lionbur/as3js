require("./build-core.js")({
	useAS3JS: true,
	runtime: "./runtime",
	outputPath: "./lib/",
	generateIndex: true,
	options: {
		srcPaths: ['./src'],
		silent: false,
		verbose: false,
		safeRequire: false,
		entry: 'com.mcleodgaming.as3js.Main',
		entryMode: 'static',
		supports: {
			ImportJS: false
		}
	}
});
