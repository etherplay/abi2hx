package {{packagePath}};

import web3.Web3;

// abstract {{className}}PromiseEvent(PromiEvent<{{className}}>) from(PromiEvent<{{className}}>){
// 	function onceTransactionHash(callback : TransactionHash -> Void): {{className}}PromiseEvent{
// 		return this.once(Hash,callback);
// 	}
// 	function onceReceipt(callback : TransactionReceipt -> Void): {{className}}PromiseEvent{
// 		return this.once(Receipt,callback);
// 	}
// 	function onConfirmation(callback: Float -> TransactionReceipt -> Void) : {{className}}PromiseEvent{
// 		return this.on(Confirmation,callback);
// 	}
// 	function onError(callback: Error -> TransactionReceipt -> Void) : {{className}}PromiseEvent{
// 		return this.on(Error,callback);
// 	}
// }

typedef ExtendedTransactionInfo = {
	> TransactionInfo
	,privateKey : String
}

class {{className}}{

	public var address(get,null) : Address;

	function get_address() : Address{
		return _instance.options.address;
	}

	public static function at(web3 : Web3, address : Address) : {{className}}{
		setup(web3);
		var instance : web3.eth.Contract = factory.clone();
		instance.options.address = address;
		return new {{className}}(web3,instance);
	}

	#if web3_allow_deploy
	public static function deploy(web3 : Web3, option:TransactionInfo, callback : Error -> TransactionHash -> Void, mineCallback : Error -> {{className}} -> Void) : Void{ //TODO arguments + type of callback
		var mining = false;
		setup(web3);
		factory
		.deploy({
			data:code,
			//TODO arguments:
		})
		.send({
			from: option.from,
			gas : option.gas, 
			value : option.value,
			gasPrice : option.gasPrice
		})
		.onceTransactionHash(function(txHash){
			mining = true;
			callback(null,txHash);
		})
		// .onError(function(error,receipt){
		// 	if(mining){
		// 		mineCallback(error,null);
		// 	}else{
		// 		callback(error,null);
		// 	}
		// })
		// .onceReceipt(function(receipt){
		// 	//TODO ?
		// })
		// .onConfirmation(function(){
		// 	//dontcare
		// })
		.then(function(instance){
			mineCallback(null,new {{className}}(web3,instance));
		})
		.catchError(function(error){
			if(mining){
				mineCallback(error,null);
			}else{
				callback(error,null);
			}
			
		});
	}
	#end

	#if web3_allow_privateKey
	public function sendRawData(data : String, option : {from : Address, privateKey : Dynamic, nonce:UInt, gasPrice : web3.Web3.Wei, gas : UInt, value : web3.Web3.Wei},
	callback:Error->TransactionHash->UInt->Void,
	?mineCallback:Error->String->TransactionReceipt->Void,
	?timeout : UInt){
		var rawTx = {
			from : option.from,
			nonce: "0x"+StringTools.hex(option.nonce),
			gasPrice: option.gasPrice == null ? "0x" + new bignumberjs.BigNumber("20000000000").toString(16) : "0x" + option.gasPrice.toString(16), 
			gasLimit: "0x" + StringTools.hex(option.gas),
			to: this.address, 
			value: option.value == null ? "0x0" :"0x" + option.value.toString(16), 
			data: data
		};
		var signedTx = ethjs.EthSigner.sign(rawTx,option.privateKey);
		_web3.eth.sendSignedTransaction(signedTx, function(err, txHash) {
			callback(err,txHash,option.nonce);
			if(err == null && mineCallback != null){
				if(timeout != null){
					web3.Web3Util.waitForTransactionReceipt(_web3,txHash,mineCallback, timeout);
				}else{
					web3.Web3Util.waitForTransactionReceipt(_web3,txHash,mineCallback);
				}
			}
		});
	}
	#end

	{{#commitFunctions}}
	public function commit_to_{{{name}}}(
	{{#inputs.length}}params:{ {{#inputs}} {{{name}}}: {{{type}}}{{^last}},{{/last}} {{/inputs}} },{{/inputs.length}}
	option:ExtendedTransactionInfo,
	callback:Error->TransactionHash->UInt->Void,
	?mineCallback:Error->String->TransactionReceipt->Void,
	?timeout : UInt
	):Void{

		#if web3_allow_privateKey
		if(option.privateKey != null){
			var data = this.get_data_for_{{{name}}}(params);
			if(option.nonce != null){
				sendRawData(data,{
					from:option.from,
					privateKey : option.privateKey,
					nonce : option.nonce,
					gasPrice : option.gasPrice,
					gas : option.gas,
					value: option.value
				},callback,mineCallback,timeout);
			}else{
				_web3.eth.getTransactionCount(option.from, function(err, nonce){
					if(err != null){
						callback(err,null,null);
					}else{
						sendRawData(data,{
							from:option.from,
							privateKey : option.privateKey,
							nonce : nonce,
							gasPrice : option.gasPrice,
							gas : option.gas,
							value: option.value
						},callback,mineCallback,timeout);
					}
					
				});
			}
		}else{
		#end
			// untyped __js__("
			_instance.methods.{{{name}}}({{#inputs}} params.{{{name}}}{{^last}},{{/last}}{{/inputs}})
			.send(
				{
					from:option.from,
					gas:option.gas,
					value:option.value,
					gasPrice:option.gasPrice
				},
				function(err,txHash){
					callback(err,txHash,null);
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
		#if web3_allow_privateKey
		}
		#end

	}
	{{/commitFunctions}}

	{{#commitFunctions}}
	public function get_data_for_{{{name}}}(
	{{#inputs.length}}params:{ {{#inputs}} {{{name}}}: {{{type}}}{{^last}},{{/last}} {{/inputs}} }{{/inputs.length}}
	):String{

		// untyped __js__("
		return _instance.methods.{{{name}}}({{#inputs}}params.{{{name}}}{{^last}},{{/last}}{{/inputs}}).encodeABI();
		
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
		_instance.methods.{{{name}}}({{#inputs}} params.{{{name}}}{{^last}},{{/last}}{{/inputs}})
		.call(
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


	{{#probeFunctions}}
	public function estimateGas_for_{{{name}}}(
	{{#inputs.length}}params:{ {{#inputs}} {{{name}}}: {{{type}}}{{^last}},{{/last}} {{/inputs}} },{{/inputs.length}}
	option:CallInfo,
	callback:Error->Float
	->Void
	):Void{
		_instance.methods.{{{name}}}({{#inputs}} params.{{{name}}}{{^last}},{{/last}}{{/inputs}})
		.estimateGas(
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


	{{#events}}
	public function gather_{{{name}}}_events(
		options :{
			?fromBlock:Float,
			?toBlock:Float,
			?filter:Dynamic //TODO
		}, callback : Error -> Array<web3.Web3.Log> -> Void
	) : Void{
		_instance.getPastEvents("{{name}}", options, callback);
	}
	{{/events}}

	static var factory : web3.eth.Contract;
	static var code : String;
	public static var abi : ABI = haxe.Json.parse('{{{abi}}}');

	static function setup(_web3 : web3.Web3){
		if(factory == null){
			#if web3_allow_deploy
			code = "0x" + "{{bytecode}}";
			#end
			factory = _web3.eth.newContract(abi);
		}
	}

	var _web3 : web3.Web3;
	var _instance  : web3.eth.Contract;

	private function new(_web3 : web3.Web3,instance : web3.eth.Contract ) { 
		this._web3 = _web3;
		_instance = instance;
	}
}
