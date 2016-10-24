var fs = require('fs');
var beautify = require('js-beautify').js_beautify;
// Now Pull in the actual AS3JS program
//var AS3JS = require('./compiled/com/mcleodgaming/as3js/Main');
var path = require('path');
var mkdirs = require('node-mkdirs');

var babel = require("babel-core");

var testCompiledPackages = false;

var testCases = [
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
		runtime: "./compiled/es2015/using-require/com/mcleodgaming/as3js/Main",
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
		runtime: "./compiled/es2015/using-require/com/mcleodgaming/as3js/Main",
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
		runtime: "./compiled/es-next/using-import/com/mcleodgaming/as3js/Main",
		bundle: "./compiled/es2009/using-importjs/bundle.js",
		babelRegisterOptions: {
			only: /es-next/,
			presets: [
//				"stage-0",
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
				ImportJS: true
			}
		}
	},
];

function writeToSourceFile(testCase, filename, code) {
	if (testCase.useStrict) {
		code = "\"use strict\";\n\n" + code;
	}
	
	mkdirs(path.dirname(filename));

	if (fs.existsSync(filename)) {
		fs.unlinkSync(filename);
	}

	if (testCase.babelOptions)
	{
		var result = babel.transform(code, testCase.babelOptions);
		code = result.code;
	}
	code = beautify(code, { indent_size: 2, max_preserve_newlines: 2 });

	fs.writeFileSync(
		filename,
		code,
		"UTF-8",
		{flags: 'w+'}
	);
}

for (var testCase of testCases) {
	if (testCase.babelRegisterOptions) {
		require("babel-register")(testCase.babelRegisterOptions);
	}

	// Pull in loader library first
	if (testCase.useAS3JS)
	{
		global.AS3JS = require('./lib/as3.js');
	} else
	{
		delete global.AS3JS;
	}

	var runtime = require(testCase.runtime);
	// Load the program
	var as3js = testCase.babelRegisterOptions
		?new runtime.default()
		:new runtime();

	// Execute the program 
	var result = as3js.compile(testCase.options);

	if (testCase.bundle)
	{
		// Output the resulting source code
		console.log("Bundling " + Object.keys(result.packageSources).length + " packages to " + testCase.bundle);
		writeToSourceFile(testCase, testCase.bundle, result.compiledSource);
	} else {
		for (var fullClassName in result.packageSources)
		{
			var filename = path.join(testCase.outputPath, fullClassName.replace(/\./g, "/") + ".js");

			console.log("Writing Class " + fullClassName + " to " + filename);
			writeToSourceFile(testCase, filename, result.packageSources[fullClassName]);
		}
	}
}