require("./build-core.js")({
	runtime: "./compiled/es-next/using-import/Main",
	outputPath: "./lib/",
	generateIndex: true,
	babelRegisterOptions: {
		only: /es-next/,
		presets: [
			"es2015",
		],
		plugins: [
			"transform-class-properties",
			"transform-flow-strip-types"
		]
	},
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
