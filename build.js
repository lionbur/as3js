var fs = require('fs');
var beautify = require('js-beautify').js_beautify;
// Pull in loader library first
global.AS3JS = require('./lib/as3.js');
// Now Pull in the actual AS3JS program
//var AS3JS = require('./compiled/com/mcleodgaming/as3js/Main');
var path = require('path');
var mkdirs = require('node-mkdirs');

var useStrict = true;
var testCompiledPackages = false;

var testCases = [
	{
		runtime: "./runtime.js",
		bundle: "./compiled/runtime.js",
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
		runtime: "./compiled/runtime.js",
		outputPath: "./compiled/",
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
//				static: true,
				ImportJS: false
			}
		}
	},
	{
		runtime: "./compiled/com/mcleodgaming/as3js/Main",
		bundle: "./compiled/rebundled.js",
		options: {
			srcPaths: ['./src'],
			silent: false,
			verbose: false,
			safeRequire: false,
			entry: 'com.mcleodgaming.as3js.Main',
			entryMode: 'static',
			supports: {
//				const: true,
//				let: true,
//				accessors: true,
				ImportJS: true
			}
		}
	},
];

function writeToSourceFile(filename, code) {
	if (useStrict) {
		code = "\"use strict\";\n\n" + code;
	}
	
	mkdirs(path.dirname(filename));

	if (fs.existsSync(filename)) {
		fs.unlinkSync(filename);
	}
	fs.writeFileSync(
		filename,
		beautify(code, { indent_size: 2, max_preserve_newlines: 2 }),
		"UTF-8",
		{flags: 'w+'}
	);
}

for (var testCase of testCases) {
var AS3JS = require(testCase.runtime);
// Load the program
var as3js = new AS3JS();

// Execute the program 
var result = as3js.compile(testCase.options);

if (testCase.bundle)
{
	// Output the resulting source code
	console.log("Bundling " + Object.keys(result.packageSources).length + " packages to " + testCase.bundle);
	writeToSourceFile(testCase.bundle, result.compiledSource);
} else {
	for (var fullClassName in result.packageSources)
	{
		var filename = path.join(testCase.outputPath, fullClassName.replace(/\./g, "/") + ".js");

		console.log("Writing Class " + fullClassName + " to " + filename);
		writeToSourceFile(filename, result.packageSources[fullClassName]);
	}
}

}