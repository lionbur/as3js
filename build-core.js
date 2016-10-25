var fs = require('fs');
var beautify = require('js-beautify').js_beautify;
// Now Pull in the actual AS3JS program
//var AS3JS = require('./compiled/com/mcleodgaming/as3js/Main');
var path = require('path');
var mkdirs = require('node-mkdirs');

var babel = require("babel-core");

function writeToSourceFile(buildOptions, filename, code) {
	if (buildOptions.useStrict) {
		code = "\"use strict\";\n\n" + code;
	}
	
	mkdirs(path.dirname(filename));

	if (fs.existsSync(filename)) {
		fs.unlinkSync(filename);
	}

	if (buildOptions.babelOptions)
	{
		var result = babel.transform(code, buildOptions.babelOptions);
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

module.exports = function build(buildOptions)
{
	if (buildOptions.compare)
	{
		var previousContent = null, content = null;

		for (var filename of buildOptions.compare)
		{
			content = fs.readFileSync(filename, "utf8");
			if (previousContent && (previousContent !== content))
			{
				break;
			}
			previousContent = content;
		}

		if (previousContent === content)
		{
			console.log("SUCCESS! " + buildOptions.compare.join(", ") + " are identical.");
		} else
		{
			console.log("ERROR! " + buildOptions.compare.join(", ") + " have failed on comparison test.");

			var lines1 = previousContent.split("\n");
			var lines2 = content.split("\n");
			var numLines = Math.min(lines1, lines2);

			for (var i = 0; i < numLines; ++i)
			{
				if (lines1[i] !== lines2[i])
				{
					console.log("Line " + i);
					console.log(lines1[i]);
					console.log(lines2[i]);
					break;
				}
			}
		}
	} else if (buildOptions.cleanup)
	{
		console.log("Cleaning " + buildOptions.cleanup + " up ...");
		require("rimraf")(buildOptions.cleanup, function (error) {
			if (error) console.log("ERROR while cleaning up: " + error);
		});
	} else
	{
		if (buildOptions.babelRegisterOptions) {
			require("babel-register")(buildOptions.babelRegisterOptions);
		}

		// Pull in loader library first
		if (buildOptions.useAS3JS)
		{
			global.AS3JS = require('./as3.js');
		} else
		{
			delete global.AS3JS;
		}

		var runtime = require(buildOptions.runtime);
		// Load the program
		var as3js = buildOptions.babelRegisterOptions
			?new runtime.default()
			:new runtime();

		// Execute the program 
		var result = as3js.compile(buildOptions.options);

		if (buildOptions.bundle)
		{
			// Output the resulting source code
			console.log("Bundling " + Object.keys(result.packageSources).length + " packages to " + buildOptions.bundle);
			writeToSourceFile(buildOptions, buildOptions.bundle, result.compiledSource);
		} else {
			var entry = buildOptions.options.entry;
			var basePackageName = entry.substring(0, entry.lastIndexOf("."));
			console.log("Base package: " + basePackageName + " --> " +  buildOptions.outputPath);

			for (var fullClassName in result.packageSources)
			{
				var relativeClassName = fullClassName.substring(basePackageName.length + 1);
				var relativePath = relativeClassName.replace(/\./g, "/") + ".js";
				var filename = path.join(buildOptions.outputPath, relativePath);

				console.log(relativeClassName + " --> " + relativePath);
				writeToSourceFile(buildOptions, filename, result.packageSources[fullClassName]);

				if (buildOptions.generateIndex && (fullClassName === entry))
				{
					writeToSourceFile(buildOptions, "./index.js", "module.exports = require(\"./" + path.join(buildOptions.outputPath, relativeClassName).replace(/\\/g, "/") + "\");");
				}
			}
		}
	}
}