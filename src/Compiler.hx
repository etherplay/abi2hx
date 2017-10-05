import haxe.DynamicAccess;
import haxe.Json;

typedef ContractInfos = DynamicAccess<DynamicAccess<Dynamic>>;
typedef ContractType = {
	?indexed:Bool,
	name : String,
	type : String
};
typedef ContractFunction = {
	?constant : Bool,
 	inputs : Array<ContractType>,
 	?name : String,
 	?outputs: Array<ContractType>,
 	?type : String
};
typedef ContractABI = Array<ContractFunction>;


typedef Param = {
	name : String,
	type : String,
	last : Bool,
	index:Int,
	alone:Bool,
	transform:String
}

typedef EParam = {
	indexed : Bool,
	name : String,
	type : String,
	last : Bool,
	index : Int,
	alone : Bool,
	transform : String
}

typedef CFunction = {
	name : String,
	inputs : Array<Param>,
	outputs : Array<Param>
}

typedef CEvent = {
	name : String,
	inputs:Array<EParam>
}

typedef TemplateData = {
	packagePath:String,
	className:String,
	commitFunctions : Array<CFunction>,
	probeFunctions : Array<CFunction>,
	events : Array<CEvent>,
	inputs : Array<Param>,
	bytecode : String,
	abi : String
}


class Compiler{

	static function getRecursiveFileList(dir : String) : Array<String>{
		var list = new Array();
		walkSync(dir, list);
		return list;
	}

	static function walkSync(dir:String, list : Array<String>) : Void{
		var files = js.node.Fs.readdirSync(dir);
		for(file in files){
			var newDir = js.node.Path.join(dir,file);
			if (js.node.Fs.statSync(newDir).isDirectory()) {
				walkSync(newDir, list);
			}else{
				list.push(file);
			}
		}
	}

	public static function main(){

		var args = Sys.args();
		
		if(args.length < 2){
			Sys.println("please specify the source folder followed by the destination folder");
			Sys.exit(1);
		}

		var sourceDir = args[0];
		var dir = args[1];

		var input : DynamicAccess<String> = {};
		var files = getRecursiveFileList(sourceDir);
		for (file in files) {
			trace("adding " + file + " ...");
			input[file] = js.node.Fs.readFileSync(sourceDir + '/' + file).toString();
		}

		trace("compiling ...");
		var output = Solc.compile({sources: input}, 1);
		if(output.errors != null){
			trace(output.errors);
		}

		var contractInfos : ContractInfos = output.contracts;

		// var output_filename = "compiled_contracts.json";
		// trace("writing to " + output_filename + " ...");
		// js.node.Fs.writeFileSync(output_filename, haxe.Json.stringify(contractInfos)); 

		// var contractInfos : ContractInfos = Json.parse(js.node.Fs.readFileSync("compiled_contracts.json").toString());

		trace("generating haxe classes ...");

		
		try{
			js.node.Fs.mkdirSync(dir);
		}catch(e:Dynamic){
		}
		
		var packagePath = ["web3","contract"]; //TODO "ethjs", "contract" 
		for(path in packagePath){
			dir = js.node.Path.join(dir,path);
			try{
				js.node.Fs.mkdirSync(dir);
			}catch(e:Dynamic){
			}	
		}

		
		for(fileContractName in contractInfos.keys()){
			var splitName = fileContractName.split(":");
			var contractName = splitName[0];
			if(splitName.length == 2){
				contractName = splitName[1];
			}

			var contractInfo = contractInfos[fileContractName];

			var info_filename = contractName + "_info.json";
			trace("writing to " + info_filename + " ...");
			js.node.Fs.writeFileSync(info_filename, haxe.Json.stringify(contractInfo)); 


			var contractABIString = contractInfo["interface"];
			var contractABI : ContractABI = Json.parse(contractABIString);
			var contractBytecode = contractInfo["bytecode"]; 

			// var output_filename = contractName + "_abi.json"; //TODO output code too in _code.json
			// trace("writing to " + output_filename + " ...");
			// js.node.Fs.writeFileSync(output_filename, haxe.Json.stringify(contractABI)); 


			// var code_filename = contractName + ".code"; //TODO output code too in _code.json
			// trace("writing to " + code_filename + " ...");
			// js.node.Fs.writeFileSync(code_filename, haxe.Json.stringify(contractBytecode)); 


			trace("contract : " + contractName);

			var filename = contractName + ".hx";
			var template = haxe.Resource.getString("template"); //TODO template is passed as argument (ethjs) if not found access filesystem

			var commitFunctions = new Array<CFunction>();
			var probeFunctions = new Array<CFunction>();
			var events = new Array<CEvent>();
			var inputs = new Array<Param>();


			var constructorFunc : ContractFunction = null;
			var funcSet = new Map<String,ContractFunction>();
			var eventSet = new Map<String,ContractFunction>(); //TODO ContractEvent
			for(func in contractABI){
				if((func.type == null || func.type == "function") && func.name != null){
					if(!funcSet.exists(func.name)){
						funcSet.set(func.name,func);
					}else{
						//trace("duplicate func with name : " + func.name);
						//TODO support overloading?
					}
					
				}else if(func.type == "constructor"){
					constructorFunc = func; //TODO overloading
				}else if(func.type == "event"){
					if(!eventSet.exists(func.name)){
						eventSet.set(func.name,func);
					}else{
						//trace("duplicate func with name : " + func.name);
						//TODO support overloading?
					}
				}
			}


			if(constructorFunc != null){ 
				var i = 0;
				for(input in constructorFunc.inputs){
					inputs.push({
						name:input.name,
						type:inputHaxeType(input.type),
						last:false,
						index:i,
						alone:false,
						transform:""
					});
					i++;
				}	
				if(inputs.length > 0){
					inputs[inputs.length-1].last = true;
				}
				if(inputs.length == 1){
					inputs[0].alone = true;	
				}
			}

			for(func in funcSet){
				if(func.name != null){
							
					// trace(" --- " + func.name);

					var cfunc = {
						name : func.name,
						inputs : [],
						outputs : []
					};
					var i = 0;
					for(input in func.inputs){
						cfunc.inputs.push({
							name:input.name,
							type:inputHaxeType(input.type),
							last:false,
							index:i,
							alone:false,
							transform:""
						});
						i++;
					}
					if(cfunc.inputs.length > 0){
						cfunc.inputs[cfunc.inputs.length-1].last = true;
					}
					if(cfunc.inputs.length == 1){
						cfunc.inputs[0].alone = true;	
					}

					i = 0;
					for(output in func.outputs){
						// trace(" output " + output.name);
						cfunc.outputs.push({
							name:output.name,
							type:haxeType(output.type),
							last:false,
							index:i,
							alone:false,
							transform:transform(output.type)
						});
						i++;
					}
					if(cfunc.outputs.length > 0){
						cfunc.outputs[cfunc.outputs.length-1].last = true;
					}
					if(cfunc.outputs.length == 1){
						cfunc.outputs[0].alone = true;	
					}
					
					if(!func.constant){
						commitFunctions.push(cfunc);
					}
					probeFunctions.push(cfunc);	
				}
			}


			for(func in eventSet){
				if(func.name != null){
							
					// trace(" --- " + func.name);

					var cevent = {
						name : func.name,
						inputs : []
					};

					var i = 0;
					for(input in func.inputs){
						// trace(" input " + input.name);
						cevent.inputs.push({
							indexed:input.indexed,
							name:input.name,
							type:haxeType(input.type),
							last:false,
							index:i,
							alone:false,
							transform:transform(input.type)
						});
						i++;
					}
					if(cevent.inputs.length > 0){
						cevent.inputs[cevent.inputs.length-1].last = true;
					}
					if(cevent.inputs.length == 1){
						cevent.inputs[0].alone = true;	
					}
				
					events.push(cevent);	
				}
			}



			var templateData : TemplateData = {
				packagePath : packagePath.join("."),
				className : contractName, 
				commitFunctions : commitFunctions,
				probeFunctions : probeFunctions,
				events : events,
				inputs : inputs,
				bytecode:contractBytecode,
				abi : contractABIString
			};

			
			var output = Mustache.render(template, templateData);
			
			
			var path = js.node.Path.join(dir,filename);
			trace("writing  " + path + " ...");
			js.node.Fs.writeFileSync(path, output); 
		}

	}


	//TODO haxeType and transform need to be tested and we night require different one for different templates : This is not good

	static function transform(solidityType : String) : String{
		if(solidityType == "address[]"){

		}else if(solidityType == "uint32"){
			return ".toNumber()";
		}else if(solidityType == "uint16"){
			return ".toNumber()";
		}else if(solidityType == "bytes"){

		}else if(solidityType == "uint8[]"){
			return ".map(function(curr,index,arr){return curr.toNumber();})";
		}else if(solidityType == "uint32[]"){
			return ".map(function(curr,index,arr){return curr.toNumber();})";
		}else if(solidityType == "uint8"){
			return ".toNumber()";
		}else if(solidityType == "int8"){
			return ".toNumber()";
		}else if(solidityType == "uint256"){
			
		}else if(solidityType == "address"){
			
		}else if(solidityType == "bytes32"){

		}else{
			
		}
		return "";
	}

	static function haxeType(solidityType : String) : String{
		return switch(solidityType){
			case "bool": "Bool";
			case "address[]": "Array<web3.Web3.Address>";
			case "uint32" | "uint8" | "uint16" : "UInt";
			case "int32" | "int8" | "int16" : "Int";
			case "bytes" | "bytes32" : "String";
			case "uint256" | "uint64" | "uint88" | "uint128" : "bignumberjs.BigNumber";
			case "address" : "web3.Web3.Address";
			case "uint8[]" | "uint32[]" : "Array<UInt>";
			case "string" : "String";
			default:	trace("TODO : solidityType mapping : ", solidityType); "Dynamic";	
		}
	}

	static function inputHaxeType(solidityType : String) : String{
		return switch(solidityType){
			case "bool": "Bool";
			case "address[]": "Array<web3.Web3.Address>";
			case "uint32" | "uint8" | "uint16" : "UInt";
			case "int32" | "int8" | "int16" : "Int";
			case "bytes" | "bytes32" : "String";
			case "uint256" | "uint64" | "uint88" | "uint128" : "String"; //TODO bigNumber but require conversion back to String
			case "address" : "web3.Web3.Address";
			case "uint8[]" | "uint32[]" : "Array<UInt>";
			case "string" : "String";
			default:	trace("TODO : solidityType mapping : ", solidityType); "Dynamic";	
		}
	}
}
