package com.mcleodgaming.as3js.parser
{
	import com.mcleodgaming.as3js.Main;
	import com.mcleodgaming.as3js.enums.*;
	import com.mcleodgaming.as3js.types.*;

	require "path"

	public class AS3Class 
	{
		public static var reservedWords:Array = ["as", "class", "delete", "false", "if", "instanceof", "native", "private", "super", "to", "use", "with", "break", "const", "do", "finally", "implements", "new", "protected", "switch", "true", "var", "case", "continue", "else", "for", "import", "internal", "null", "public", "this", "try", "void", "catch", "default", "extends", "function", "in", "is", "package", "return", "throw", "typeof", "while", "each", "get", "set", "namespace", "include", "dynamic", "final", "natiev", "override", "static", "abstract", "char", "export", "long", "throws", "virtual", "boolean", "debugger", "float", "prototype", "to", "volatile", "byte", "double", "goto", "short", "transient", "cast", "enum", "intrinsic", "synchronized", "type"];
		
		public static var nativeTypes:Array = ["Boolean", "Number", "int", "uint", "String" ];
		
		public var packageName:String;
		public var className:String;
		public var imports:Vector.<String>;
		public var requires:Vector.<String>;
		public var importWildcards:Vector.<String>;
		public var importExtras:Vector.<String>;
		public var interfaces:Vector.<String>;
		public var parent:String;
		public var parentDefinition:AS3Class;
		public var members:Vector.<AS3Member>;
		public var staticMembers:Vector.<AS3Member>;
		public var getters:Vector.<AS3Member>;
		public var setters:Vector.<AS3Member>;
		public var staticGetters:Vector.<AS3Member>;
		public var staticSetters:Vector.<AS3Member>;
		public var isInterface:Boolean;
		public var membersWithAssignments:Vector.<AS3Member>; //List of class members that have assignments in the class-level scope
		public var fieldMap:Object; //Maps instance field names to instance members
		public var staticFieldMap:Object; //Maps static field names to static members
		public var classMap:Object; //Maps class shorthand name to class
		public var classMapFiltered:Object; //Same as classMap but only references classes that are actually used (i.e. used in another way besides just a "type")
		public var packageMap:Object; //Maps full package path to class
		
		// Options
		public var safeRequire:Boolean; //Try catch around parsed require statements
		public var ignoreFlash:Boolean; //Ignore FL imports
		public var supports:Object; //Specification of all extended syntax (ES6 etc)
		public var entry:String; //Entry module initializes all dependencies automatically
			
		public function AS3Class(options:Object = null) 
		{
			options = options || { };
			safeRequire = false;
			supports = options.supports || { };
			entry = options.entry;
			
			if (typeof options.safeRequire !== 'undefined')
			{
				safeRequire = options.safeRequire;
			}
			if (typeof options.ignoreFlash !== 'undefined')
			{
				ignoreFlash = options.ignoreFlash;
			}
			
			packageName = null;
			className = null;
			imports = new Vector.<String>();
			requires = new Vector.<String>();
			importWildcards = new Vector.<String>();
			importExtras = new Vector.<String>();
			interfaces = new Vector.<String>();
			parent = null;
			parentDefinition = null;
			members = new Vector.<AS3Member>();
			staticMembers = new Vector.<AS3Member>();
			getters = new Vector.<AS3Member>();
			setters = new Vector.<AS3Member>();
			staticGetters = new Vector.<AS3Member>();
			staticSetters = new Vector.<AS3Member>();
			membersWithAssignments = new Vector.<AS3Member>();
			isInterface = false;
			fieldMap = {};
			staticFieldMap = {};
			classMap = { };
			classMapFiltered = { };
			packageMap = { };
		}
		public function registerImports(clsList:Object):void
		{
			var i;
			for (i in imports)
			{
				if (clsList[imports[i]])
				{
					var lastIndex:int = imports[i].lastIndexOf(".");
					var shorthand:String = (lastIndex < 0) ? imports[i] : imports[i].substr(lastIndex + 1);
					classMap[shorthand] = clsList[imports[i]];
				}
			}
			for (i in importExtras)
			{
				if (clsList[importExtras[i]])
				{
					var lastIndex:int = importExtras[i].lastIndexOf(".");
					var shorthand:String = (lastIndex < 0) ? importExtras[i] : importExtras[i].substr(lastIndex + 1);
					classMap[shorthand] = clsList[importExtras[i]];
				}
			}
			packageMap = clsList;
		}
		public function registerField(name:String, value:AS3Member):void
		{
			if (value && value.isStatic)
			{
				staticFieldMap[name] = staticFieldMap[name] || value;
			} else
			{
				fieldMap[name] = fieldMap[name] || value;
			}
		}
		public function retrieveField(name:String, isStatic:Boolean):AS3Member
		{
			if (isStatic)
			{
				if (staticFieldMap[name])
				{
					return staticFieldMap[name];
				} else if (parentDefinition)
				{
					return parentDefinition.retrieveField(name, isStatic);
				} else
				{
					return null;
				}
			} else
			{
				if (fieldMap[name])
				{
					return fieldMap[name];
				} else if (parentDefinition)
				{
					return parentDefinition.retrieveField(name, isStatic);
				} else
				{
					return null;
				}
			}
		}
		public function needsImport(pkg:String):Boolean
		{
			var i:*;
			var j:*;
			var lastIndex:int = pkg.lastIndexOf(".");
			var shorthand:String = (lastIndex < 0) ? pkg : pkg.substr(lastIndex + 1);
			var matches:Vector.<AS3Member>;

			if (imports.indexOf(pkg) >= 0)
			{
				return false; //Class was already imported
			}

			if (shorthand == className && pkg == packageName)
			{
				return true; //Don't need self
			}
				
			if (shorthand == parent)
			{
				return true; //Parent class is in another package
			}
			
			//Now we must parse through all members one by one, looking at functions and variable types to determine the necessary imports
				
			for (i in members)
			{
				//See if the function definition or variable assigment have a need for this package
				if (members[i] instanceof AS3Function)
				{
					matches = members[i].value.match(AS3Pattern.VARIABLE_DECLARATION[1]);
					for (j in matches)
					{
						if(matches[j].split(":")[1] == shorthand)
							return true;
					}
					for (j in members[i].argList)
					{
						if(typeof members[i].argList[j].type == 'string' && members[i].argList[j].type == shorthand)
							return true;
					}
				}
				if (typeof members[i].value == 'string' && members[i].value.match(new RegExp("([^a-zA-Z_$.])" + shorthand + "([^0-9a-zA-Z_$])", "g")))
				{
					return true;
				} else if (typeof members[i].type == 'string' && members[i].type == shorthand)
				{
					return true;
				}
			}
			for (i in staticMembers)
			{
				//See if the function definition or variable assigment have a need for this package
				if (staticMembers[i] instanceof AS3Function)
				{
					matches = staticMembers[i].value.match(AS3Pattern.VARIABLE_DECLARATION[1]);
					for (j in matches)
					{
						if (matches[j].split(":")[1] == shorthand)
						{
							return true;
						}
					}
					for (j in staticMembers[i].argList) 
					{
						if (typeof staticMembers[i].argList[j].type == 'string' && staticMembers[i].argList[j].type == shorthand)
						{
							return true;
						}
					}
				}
				if (typeof staticMembers[i].value == 'string' && staticMembers[i].value.match(new RegExp("([^a-zA-Z_$.])" + shorthand + "([^0-9a-zA-Z_$])", "g")))
				{
					return true;
				} else if (typeof staticMembers[i].type == 'string' && staticMembers[i].type == shorthand)
				{
					return true;
				}
			}
			for (i in getters)
			{
				//See if the function definition or variable assigment have a need for this package
				matches = getters[i].value.match(AS3Pattern.VARIABLE_DECLARATION[1]);
				for (j in matches)
				{
					if (matches[j].split(":")[1] == shorthand)
					{
						return true;
					}
				}
				for (j in getters[i].argList)
				{
					if (typeof getters[i].argList[j].type == 'string' && getters[i].argList[j].type == shorthand)
					{
						return true;
					}
				}
				if (typeof getters[i].value == 'string' && getters[i].value.match(new RegExp("([^a-zA-Z_$.])" + shorthand + "([^0-9a-zA-Z_$])", "g")))
				{
					return true;
				} else if (typeof getters[i].type == 'string' && getters[i].type == shorthand)
				{
					return true;
				}
			}
			for (i in setters)
			{
				matches = setters[i].value.match(AS3Pattern.VARIABLE_DECLARATION[1]);
				for (j in matches)
				{
					if (matches[j].split(":")[1] == shorthand)
					{
						return true;
					}
				}
				//See if the function definition or variable assigment have a need for this package
				for (j in setters[i].argList) 
				{
					if (typeof setters[i].argList[j].type == 'string' && setters[i].argList[j].type == shorthand)
					{
						return true;
					}
				}
				if (typeof setters[i].value == 'string' && setters[i].value.match(new RegExp("([^a-zA-Z_$.])" + shorthand + "([^0-9a-zA-Z_$])", "g")))
				{
					return true;
				} else if (typeof setters[i].type == 'string' && setters[i].type == shorthand)
				{
					return true;
				}
			}
			for (i in staticGetters)
			{
				matches = staticGetters[i].value.match(AS3Pattern.VARIABLE_DECLARATION[1]);
				for (j in matches)
				{
					if (matches[j].split(":")[1] == shorthand)
					{
						return true;
					}
				}
				//See if the function definition or variable assigment have a need for this package
				for (j in staticGetters[i].argList)
				{
					if (typeof staticGetters[i].argList[j].type == 'string' && staticGetters[i].argList[j].type == shorthand)
					{
						return true;
					}
				}
				if (typeof staticGetters[i].value == 'string' && staticGetters[i].value.match(new RegExp("([^a-zA-Z_$.])" + shorthand + "([^0-9a-zA-Z_$])", "g")))
				{
					return true;
				} else if (typeof staticGetters[i].type == 'string' && staticGetters[i].type == shorthand)
				{
					return true;
				}
			}
			for (i in staticSetters)
			{
				matches = staticSetters[i].value.match(AS3Pattern.VARIABLE_DECLARATION[1]);
				for (j in matches)
				{
					if (matches[j].split(":")[1] == shorthand)
					{
						return true;
					}
				}
				for (j in staticSetters[i].argList)
				{
					if (typeof staticSetters[i].argList[j].type == 'string' && staticSetters[i].argList[j].type == shorthand)
					{
						return true;
					}
				}
				//See if the function definition or variable assigment have a need for this package
				if (typeof staticSetters[i].value == 'string' && staticSetters[i].value.match(new RegExp("([^a-zA-Z_$.])" + shorthand + "([^0-9a-zA-Z_$])", "g")))
				{
					return true;
				} else if (typeof staticSetters[i].type == 'string' && staticSetters[i].type == shorthand)
				{
					return true;
				}
			}
			
			return false;
		}
		public function addImport(pkg:String):void
		{
			if (imports.indexOf(pkg) < 0)
			{
				imports.push(pkg);
			}
		}
		public function addExtraImport(pkg:String):void
		{
			if (importExtras.indexOf(pkg) < 0)
			{
				importExtras.push(pkg);
			}
		}
		public function findParents(classes:Vector.<AS3Class>):void
		{
			if (!parent)
			{
				return;
			}
			for (var i in classes)
			{
				//Only gather vars from the parent
				if (classes[i] != this && parent == classes[i].className)
				{
					parentDefinition = classes[i]; //Found our parent
					return;
				}
			}
		}
		public function checkMembersWithAssignments():void
		{
			var i:int;
			var j:*;
			var classMember:AS3Member;
			// If the type of this param is a Class
			for (i = 0; i < membersWithAssignments.length; i++)
			{
				classMember = membersWithAssignments[i];
				// Make a dumb attempt to identify use of the class as assignments here
				for (j in imports)
				{
					if (packageMap[imports[j]] && classMember.value.indexOf(packageMap[imports[j]].className) >= 0 && parentDefinition !== packageMap[imports[j]])
					{
						// If this is a token that matches a class from an import statement, store it in the filtered classMap
						classMapFiltered[packageMap[imports[j]].className] = packageMap[imports[j]];
					}
				}
			}
		}
		public function stringifyFunc(fn:AS3Member):String
		{
			var subTypeSeparator:String = this.supports.accessors ?" " :"_";
			var buffer:String = "";
			if (fn instanceof AS3Function)
			{
				//Functions need to be handled differently
				//Prepend sub-type if it exists
				if (fn.subType)
				{
					buffer += fn.subType + subTypeSeparator;
				}
				//Print out the rest of the name and start the function definition
				var isNewSyntax = this.supports.class && (this.supports.static || !fn.isStatic);

				buffer += fn.name;
				buffer += isNewSyntax?" (" :" = function(";
				//Concat all of the arguments together
				var tmpArr = [];
				for (var j = 0; j < fn.argList.length; j++)
				{
					if (!fn.argList[j].isRestParam)
					{
						tmpArr.push(fn.argList[j].name);
					}
				}
				buffer += tmpArr.join(", ") + ") ";
				//Function definition is finally added
				buffer += fn.value;
				if (!isNewSyntax) {
					buffer += ";";
				} 
				buffer += "\n";
			} else if (fn instanceof AS3Variable)
			{
				//Variables can be added immediately
				buffer += fn.name;
				buffer += " = " + fn.value + ";\n";
			}
			return buffer;
		}
		
		public function process(classes:Vector.<AS3Class>):void
		{
			var self:AS3Class = this;
			var i:int;
			var index:int;
			var currParent:AS3Class = this;
			var allMembers:Vector.<AS3Member> = new Vector.<AS3Member>();
			var allFuncs:Vector.<AS3Function> = new Vector.<AS3Function>();
			var allStaticMembers:Vector.<AS3Member> = new Vector.<AS3Member>();
			var allStaticFuncs:Vector.<AS3Function> = new Vector.<AS3Function>();

			while (currParent)
			{
				//Parse members of this parent
				for (i in currParent.setters)
				{
					allMembers.push(currParent.setters[i]);
				}
				for (i in currParent.staticSetters)
				{
					allStaticMembers.push(currParent.staticSetters[i]);
				}
				for (i in currParent.getters)
				{
					allMembers.push(currParent.getters[i]);
				}
				for (i in currParent.staticGetters)
				{
					allStaticMembers.push(currParent.staticGetters[i]);
				}
				for (i in currParent.members)
				{
					allMembers.push(currParent.members[i]);
				}
				for (i in currParent.staticMembers)
				{
					allStaticMembers.push(currParent.staticMembers[i]);
				}
					
				//Go to the next parent
				currParent = currParent.parentDefinition;
			}
			
			//Add copies of the setters and getters to the "all" arrays (for convenience)
			for (i in setters)
			{
				if (setters[i] instanceof AS3Function)
				{
					allFuncs.push(setters[i]);
				}
			}
			for (i in staticSetters)
			{
				if (staticSetters[i] instanceof AS3Function)
				{
					allStaticFuncs.push(staticSetters[i]);
				}
			}
			for (i in getters)
			{
				if (getters[i] instanceof AS3Function)
				{
					allFuncs.push(getters[i]);
				}
			}
			for (i in staticGetters)
			{
				if (staticGetters[i] instanceof AS3Function)
				{
					allStaticFuncs.push(staticGetters[i]);
				}
			}
			for (i in members)
			{
				if (members[i] instanceof AS3Function)
				{
					allFuncs.push(members[i]);
				}
			}
			for (i in staticMembers)
			{
				if (staticMembers[i] instanceof AS3Function)
				{
					allStaticFuncs.push(staticMembers[i]);
				}
			}

			
			for (i in allFuncs)
			{
				Main.debug("Now parsing function: " + className + ":" + allFuncs[i].name);
				allFuncs[i].value = AS3Parser.parseFunc(this, allFuncs[i].value, allFuncs[i].buildLocalVariableStack(), allFuncs[i].isStatic)[0];
				allFuncs[i].value = AS3Parser.checkArguments(allFuncs[i]);
				if (allFuncs[i].name === className)
				{
					//Inject instantiations here
					allFuncs[i].value = AS3Parser.injectInstantiations(this, allFuncs[i]);
				}
				allFuncs[i].value = AS3Parser.cleanup(allFuncs[i].value);
				//Fix supers
				if (!this.supports.super)
				{
					allFuncs[i].value = allFuncs[i].value.replace(/super\.(.*?)\(/g, parent + '.prototype.$1.call(this, ').replace(/\.call\(this,\s*\)/g, ".call(this)");
					allFuncs[i].value = allFuncs[i].value.replace(/super\(/g, parent + '.call(this, ').replace(/\.call\(this,\s*\)/g, ".call(this)");
				}
				allFuncs[i].value = allFuncs[i].value.replace(new RegExp("this[.]" + parent, "g"), parent); //Fix extra 'this' on the parent
			}
			for (i in allStaticFuncs)
			{
				Main.debug("Now parsing static function: " + className + ":" + allStaticFuncs[i].name);
				allStaticFuncs[i].value = AS3Parser.parseFunc(this, allStaticFuncs[i].value, allStaticFuncs[i].buildLocalVariableStack(), allStaticFuncs[i].isStatic)[0];
				allStaticFuncs[i].value = AS3Parser.checkArguments(allStaticFuncs[i]);
				allStaticFuncs[i].value = AS3Parser.cleanup(allStaticFuncs[i].value);
			}
		}
		private function packageNameToPath(pkg:String):String {
			var ownPath = packageName.replace(/\./g, "/");
			var thatPath = pkg.replace(/\./g, "/");

			var result = path.relative(ownPath, thatPath).replace(/\\/g, "/");

			if (/^\./.test(result)) {
				return result;
			}
			return result.length
				?"./" + result
				:".";
		}
		public function toString():String
		{
			//Outputs the class inside a JS function
			var i:*;
			var j:*;
			var buffer:String = "";
			var varOrConst:String = this.supports.const ?"const " :"var ";
			var requireCall:String = this.safeRequire ?"safeRequire" :"require";
			var requireTemplate = this.supports.import
				?"import ${module} from ${path};\n"
				:varOrConst + " ${module} = " + requireCall + "(${path});\n";
			var varOrLet:String = this.supports.let ?"let " :"var ";

			if (this.safeRequire) {
				buffer += "function safeRequire(mod) { try { return require(mod); } catch(e) { return undefined; } }\n\n";
			}

			if (requires.length > 0)
			{
				for (i in requires)
				{
					var require:String = requires[i];

					buffer += requireTemplate
						.replace("${module}", require.substring(1, require.length-1))
						.replace("${path}", require);
				}
				buffer += "\n";
			}
		
			var initClassFunctionName = "_initClass_";
			var tmpArr:Array = null;
			var injectedText = "";

			//Parent class must be imported if it exists
			if (parentDefinition)
			{
				var importParentTemplate = this.supports.import
					?"import ${name} from \"${path}/${name}\";\n"
					:this.supports.ImportJS
						?varOrConst + "${module} = module.import('${path}', '${name}');\n"
						:varOrConst + "${module} = " + requireCall + "(\"${path}/${name}\");\n";
				var packagePath:String = this.supports.ImportJS
					?parentDefinition.packageName
					:packageNameToPath(parentDefinition.packageName);
				
				buffer += importParentTemplate
						.replace("${module}", parentDefinition.className)
						.replace("${path}", packagePath)
						.replace(/\$\{name\}/g, parentDefinition.className);
				
				if (!this.supports.ImportJS)
				{
					injectedText += "if (" + parentDefinition.className + "." + initClassFunctionName + ") " + parentDefinition.className + " ." + initClassFunctionName + "();\n"
				}
			}

			//Create refs for all the other classes
			if (imports.length > 0)
			{
				tmpArr = [];
				for (i in imports)
				{
					if (!(ignoreFlash && imports[i].indexOf('flash.') >= 0) && parent != imports[i].substr(imports[i].lastIndexOf('.') + 1) && packageName + '.' + className != imports[i]) //Ignore flash imports
					{
						// Must be in the filtered map, otherwise no point in writing
						if (classMapFiltered[packageMap[imports[i]].className])
						{
							tmpArr.push(imports[i].substr(imports[i].lastIndexOf('.') + 1)); //<-This will return characters after the final '.', or the entire String if no '.'
						}
					}
				}
				//Join up separated by commas
				if (!this.supports.import && (tmpArr.length > 0))
				{
					buffer += varOrLet;
					buffer += tmpArr.join(", ") + ";\n";
				}
			}
			var importTemplate = this.supports.import
				?"import ${name} from \"${path}/${name}\";\n"
				:this.supports.ImportJS
					?"${module} = module.import('${path}', '${name}');\n"
					:"${module} = " + requireCall + "(\"${path}/${name}\"); if(${name}." + initClassFunctionName + ") ${name}." + initClassFunctionName + "();\n";
			for (i in imports)
			{
				if (!(ignoreFlash && imports[i].indexOf('flash.') >= 0) && packageName + '.' + className != imports[i] && !(parentDefinition && parentDefinition.packageName + '.' + parentDefinition.className == imports[i])) //Ignore flash imports and parent for injections
				{
					// Must be in the filtered map, otherwise no point in writing
					if (classMapFiltered[packageMap[imports[i]].className])
					{
						var packagePath:String = this.supports.ImportJS
							?packageMap[imports[i]].packageName
							:packageNameToPath(packageMap[imports[i]].packageName);

						injectedText += importTemplate
								.replace("${module}", imports[i].substr(imports[i].lastIndexOf('.') + 1))
								.replace("${path}", packagePath)
								.replace(/\$\{name\}/g, packageMap[imports[i]].className);
					}
				}
			}
			if (!this.supports.class || !this.supports.static)
			{
				//Set the non-native statics vars now
				for (i in staticMembers)
				{
					if (!(staticMembers[i] instanceof AS3Function))
					{
						injectedText += "\t" + AS3Parser.cleanup( className + '.' + staticMembers[i].name + ' = ' + staticMembers[i].value + ";\n");
					}
				}				
			}
			
			if (injectedText.length > 0)
			{
				if (this.supports.ImportJS) {
					buffer += "module.inject = function ()\n";
					buffer += "{\n" + injectedText + "};\n";
				} else {
					injectedText = "delete " + className + "." + initClassFunctionName + ";\n" + injectedText;

					var initClassFunc:AS3Function = new AS3Function();
					initClassFunc.isStatic = true;
					initClassFunc.name = initClassFunctionName;
					initClassFunc.value = "{\n" + injectedText + "}";
					staticMembers.push(initClassFunc);
				}
			}

			buffer += '\n';
			
			if (this.supports.import) {
				buffer += "export default ";
			}
			if (this.supports.class) {
				buffer += "class " + className;
			} else {
				buffer += (fieldMap[className]) 
					? varOrConst + stringifyFunc(fieldMap[className])
					: varOrConst + className + " = function " + className + "() {};";
			
				buffer += '\n';
			}
			
			if (parent)
			{
				if (this.supports.class) {
					buffer += " extends " + parent;
				} else
				{
					//Extend parent if necessary
					buffer += className + ".prototype = Object.create(" + parent + ".prototype);";
				}
			}
			
			if (this.supports.class) {
				buffer += "\n{\n";
			} else
			{
				buffer += "\n\n";
			}
			
			var staticMembersText:String = "";
			if (staticMembers.length > 0)
			{
				//Place the static members first (skip the ones that aren't native types, we will import later
				for (i in staticMembers)
				{
					if (this.supports.static)
					{
						staticMembersText += "static " + stringifyFunc(staticMembers[i]);
					}
					else if (staticMembers[i] instanceof AS3Function)
					{
						staticMembersText += className + "." + stringifyFunc(staticMembers[i]);
					} else if (staticMembers[i].type === "Number" || staticMembers[i].type === "int" || staticMembers[i].type === "uint")
					{
						if (isNaN(parseInt(staticMembers[i].value)))
						{
							staticMembersText += className + "." + staticMembers[i].name + ' = 0;\n';
						} else
						{
							staticMembersText += className + "." + stringifyFunc(staticMembers[i]);
						}
					} else if (staticMembers[i].type === "Boolean")
					{
						staticMembersText += className + "." + staticMembers[i].name + ' = false;\n';
					} else
					{
						staticMembersText += className + "." +  staticMembers[i].name + ' = null;\n';
					}
				}
				for (i in staticGetters)
				{
					staticMembersText += className + "." + stringifyFunc(staticGetters[i]);
				}
				for (i in staticSetters)
				{
					staticMembersText += className + "." + stringifyFunc(staticSetters[i]);
				}
				staticMembersText += '\n';
			}
	
			if (!this.supports.class || this.supports.static) {
				buffer += staticMembersText;
				buffer += "\n";
			}

			var areMemberVariablesOutOfClass:Boolean = this.supports.class && !this.supports.memberVariables; 
			var memberFunctionPrefix:String = this.supports.class
				?"\t"
				:className + ".prototype.";
			var memberVariablePrefix:String = areMemberVariablesOutOfClass
				?className + ".prototype."
				:memberFunctionPrefix;
			var memberVariablesText:String = areMemberVariablesOutOfClass ?"" :buffer;

			for (i in getters)
			{
				buffer += memberPrefix + stringifyFunc(getters[i]);
			}
			for (i in setters)
			{
				buffer += memberPrefix + stringifyFunc(setters[i]);
			}
			for (i in members)
			{
				if (members[i].name === className)
				{
					if (this.supports.class)
					{
						members[i].name = "constructor";
						if (this.supports.super && parentDefinition && !members[i].value.match(new RegExp("^\\{\\s*super\\(")))
						{
							members[i].value = members[i].value.replace(new RegExp("^\\{(\\s*)"), "{$1\tsuper ();\n");
						}
					} else
					{
						continue;
					}
				}
				if (members[i] instanceof AS3Function || (AS3Class.nativeTypes.indexOf(members[i].type) >= 0 && members[i].value))
				{
					if (members[i] instanceof AS3Function)
					{
						buffer += memberFunctionPrefix + stringifyFunc(members[i]); //Print functions immediately
					}
					else {
						memberVariablesText += memberVariablePrefix + stringifyFunc(members[i]);
					}
				} else if (members[i].type === "Number" || members[i].type === "int" || members[i].type === "uint")
				{
					if (isNaN(parseInt(members[i].value)))
					{
						memberVariablesText += memberVariablePrefix + members[i].name + ' = 0;\n';
					} else
					{
						memberVariablesText += memberVariablePrefix + stringifyFunc(members[i]);
					}
				} else if (members[i].type === "Boolean")
				{
					memberVariablesText += memberVariablePrefix + members[i].name + ' = false;\n';
				} else
				{
					memberVariablesText += memberVariablePrefix + members[i].name + ' = null;\n';
				}
			}

			if (this.supports.class)
			{
				buffer += "}\n"; 
			} else {
				buffer = buffer.substr(0, buffer.length - 2) + "\n"; //Strips the final comma out of the string
			}

			if (areMemberVariablesOutOfClass)
			{
				buffer += memberVariablesText;
			}

			if (this.supports.class && !this.supports.static) {
				buffer += staticMembersText;
				buffer += "\n";
			}

			if (!this.supports.import)
			{
				buffer += "\n\n";
				buffer += "module.exports = " + className + ";\n";
			}

			if (!this.supports.ImportJS && (entry === packageName + "." + className)) {
				buffer += className + "." + initClassFunctionName + "(); // Entry point module initializes all dependencies\n";
			}

			//Remaining fixes
			buffer = buffer.replace(/(this\.)+/g, "this.");

			return buffer;
		}
	}
}