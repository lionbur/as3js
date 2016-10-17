var fs = require('fs');
var beautify = require('js-beautify').js_beautify;
// Pull in loader library first
global.AS3JS = require('./lib/as3.js');
// Now Pull in the actual AS3JS program
var AS3JS = require('./runtime.js');
var path = require('path');
var mkdirs = require('node-mkdirs');

// Load the program
var as3js = new AS3JS();

var useStrict = true;
var testCompiledPackages = false;

// Execute the program 
var result = as3js.compile({
	srcPaths: ['./src'],
	silent: false,
	verbose: false,
	safeRequire: !testCompiledPackages,
	entry: 'com.mcleodgaming.as3js.Main',
	entryMode: 'static',
	supports: {
		const: true,
		let: true
	}
});

function writeToSourceFile(filename, code) {
	if (useStrict) {
		code = "\"use strict\";\n\n" + code;
	}
	
	mkdirs(path.dirname(filename));
	return fs.writeFileSync(
		filename,
		beautify(code, { indent_size: 2, max_preserve_newlines: 2 }),
		"UTF-8",
		{flags: 'w+'}
	);
}

if (testCompiledPackages)
{
	var packages = result.packageSources;
	var outputPath = './compiled/';

	for (var fullClassName in packages)
	{
		var filename = path.join(outputPath, fullClassName.replace(/\./g, "/") + ".js");

		console.log("Writing Class " + fullClassName + " to " + filename);
		if (fs.existsSync(filename)) {
			fs.unlinkSync(filename);
		}
		writeToSourceFile(filename, packages[fullClassName]);
	}
} else {
	var filename = "./compiled/runtime.js";
	// Output the resulting source code
	if (fs.existsSync(filename))
	{
		fs.unlinkSync(filename);
	}
	writeToSourceFile(filename, result.compiledSource);
}
