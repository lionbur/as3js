var build = require("./build-core.js");

[
	{
		useAS3JS: true,
		runtime: "./runtime.js",
		bundle: "./compiled/es2015/using-importjs/bundle.js",
		options: {
			srcPaths: ['./src'],
			silent: false,
			verbose: false,
			safefRequire: true,
			entry: 'com.mcleodgaming.as3js.Main',
			entryMode: 'static',
			supports: {
				const: true,
				let: true,
				accessors: true,
				ImportJS: true
			}
		}
	},
	{
		useAS3JS: true,
		runtime: "./compiled/es2015/using-importjs/bundle.js",
		outputPath: "./compiled/es2015/using-require/",
		options: {
			srcPaths: ['./src'],
			silent: false,
			verbose: false,
			safeRequire: false,
			entry: 'com.mcleodgaming.as3js.Main',
			entryMode: 'static',
			supports: {
				const: true,
				let: true,
				accessors: true,
				class: true,
				super: true,
				defaultParameters: true,
				restParameter: true,
			}
		}
	},
	{
		runtime: "./compiled/es2015/using-require/Main",
		outputPath: "./compiled/es2015/using-import/",
		options: {
			srcPaths: ['./src'],
			silent: false,
			verbose: false,
			safeRequire: false,
			entry: 'com.mcleodgaming.as3js.Main',
			entryMode: 'static',
			supports: {
				const: true,
				let: true,
				accessors: true,
				class: true,
				super: true,
				import: true,
				defaultParameters: true,
				restParameter: true,
			}
		}
	},
	{
		runtime: "./compiled/es2015/using-require/Main",
		outputPath: "./compiled/es-next/using-import/",
		options: {
			srcPaths: ['./src'],
			silent: false,
			verbose: false,
			safeRequire: false,
			entry: 'com.mcleodgaming.as3js.Main',
			entryMode: 'static',
			supports: {
				const: true,
				let: true,
				accessors: true,
				class: true,
				super: true,
				static: true,
				import: true,
				memberVariables: true,
				flowTypes: true,
				defaultParameters: true,
				restParameter: true,
			}
		}
	},
	{
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
	},
	{
		runtime: "./",
		bundle: "./compiled/es2009/using-importjs/bundle.js",
		options: {
			srcPaths: ['./src'],
			silent: false,
			verbose: false,
			safeRequire: false,
			entry: 'com.mcleodgaming.as3js.Main',
			entryMode: 'static',
			supports: {
				ImportJS: true
			}
		}
	},
	{
		compare: [
			"./runtime.js",
			"./compiled/es2009/using-importjs/bundle.js"
		]
	},
	{
		cleanup: "./compiled"
	}
].forEach(build);
