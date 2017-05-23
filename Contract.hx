package {{packagePath}};

import web3.Web3;

class {{className}}{

	public var address(default,null) : Address;

	public static function at(web3 : Web3, address : Address) : {{className}}{
		setup(web3);
		return new {{className}}(web3,address);
	}

	#if web3_allow_deploy
	public static function deploy(web3 : Web3, option:TransactionInfo, callback : Error -> Dynamic -> Void, mineCallback : Error -> Dynamic -> Void) : Void{ //TODO arguments + type of callback
		var mining = false;
		setup(web3);
		factory["new"]({ //TODO arguments
			from: option.from,
			gas : option.gas, 
			value : option.value,
			gasPrice : option.gasPrice,
			data: code
		}, function(err, deployedContract){
			if(err != null){
				if(mining){
					mineCallback(err, null);
				}else{
					callback(err, null);
				}
			}else{
				if(deployedContract.address != null){
					mineCallback(null, new {{className}}(web3,deployedContract.address));
				}else{
					if(mining){
						mineCallback("no address", null);
					}else{
						callback(null,deployedContract);
					}
				}
			}
			mining = true;
		});
	}
	#end

	{{#commitFunctions}}
	public function commit_to_{{{name}}}(
	{{#inputs.length}}params:{ {{#inputs}} {{{name}}}: {{{type}}}{{^last}},{{/last}} {{/inputs}} },{{/inputs.length}}
	option:TransactionInfo,
	callback:Error->TransactionHash->Void,
	?mineCallback:Error->String->TransactionReceipt->Void,
	?timeout : UInt
	):Void{

		// untyped __js__("
		_instance.{{{name}}}.sendTransaction(
			{{#inputs}} params.{{{name}}},{{/inputs}}
			option,
			function(err,txHash){
				callback(err,txHash);
				if(err == null && mineCallback != null){
					if(timeout != null){
						web3.Web3Util.waitForTransactionReceipt(_web3,txHash,mineCallback, timeout);
					}else{
						web3.Web3Util.waitForTransactionReceipt(_web3,txHash,mineCallback);
					}
				}
			}
		);
		// ");
	}
	{{/commitFunctions}}

	{{#probeFunctions}}
	public function probe_{{{name}}}(
	{{#inputs.length}}params:{ {{#inputs}} {{{name}}}: {{{type}}}{{^last}},{{/last}} {{/inputs}} },{{/inputs.length}}
	option:CallInfo,
	callback:Error{{#outputs.length}}->{ {{#outputs}} {{{name}}}: {{{type}}}{{^last}},{{/last}} {{/outputs}} }{{/outputs.length}}
	->Void
	):Void{
		_instance.{{{name}}}.call(
			{{#inputs}} params.{{{name}}},{{/inputs}}
			option,
			function(err,result){
				if(err != null){
					callback(err{{#outputs.length}},null{{/outputs.length}});
				}else{
					callback(null{{#outputs.length}},
						{
							{{#outputs}}
							{{{name}}}: cast {{#alone}}result{{transform}}{{/alone}}{{^alone}}result[{{index}}]{{transform}}{{/alone}}{{^last}},{{/last}}
							{{/outputs}}
						}
						{{/outputs.length}}
					);
				}
			}
		);
	}
	{{/probeFunctions}}

	// {{#probeFunctions}}
	// public function get_data_to_{{{name}}}(
	// {{#inputs.length}}params:{ {{#inputs}} {{{name}}}: {{{type}}}{{^last}},{{/last}} {{/inputs}} },{{/inputs.length}}
	// option:CallInfo,
	// callback:Error->String
	// ->Void
	// ):Void{
	// 	_instance.{{{name}}}.getData(
	// 		{{#inputs}} params.{{{name}}},{{/inputs}}
	// 		option,
	// 		function(err,data : String){
	// 			if(err != null){
	// 				callback(err, null);
	// 			}else{
	// 				callback(null,data);
	// 			}
	// 		}
	// 	);
	// }
	// {{/probeFunctions}}

	{{#probeFunctions}}
	public function estimateGas_for_{{{name}}}(
	{{#inputs.length}}params:{ {{#inputs}} {{{name}}}: {{{type}}}{{^last}},{{/last}} {{/inputs}} },{{/inputs.length}}
	option:CallInfo,
	callback:Error->Float
	->Void
	):Void{
		_instance.{{{name}}}.estimateGas(
			{{#inputs}} params.{{{name}}},{{/inputs}}
			option,
			function(err,gas : Float){
				if(err != null){
					callback(err, 0);
				}else{
					callback(null,gas);
				}
			}
		);
	}
	{{/probeFunctions}}


	static var factory : haxe.DynamicAccess<Dynamic>;
	static var code : String;

	static function setup(_web3 : web3.Web3){
		if(factory == null){
			#if web3_allow_deploy
			code = "0x" + "{{bytecode}}";
			#end
			factory = _web3.eth.contract(haxe.Json.parse('{{{abi}}}'));
		}
	}

	var _web3 : web3.Web3;
	var _instance : Dynamic;

	private function new(_web3 : web3.Web3,address : web3.Web3.Address) { 
		this._web3 = _web3;
		_instance = factory["at"](address);
		this.address = address;
	}
}
