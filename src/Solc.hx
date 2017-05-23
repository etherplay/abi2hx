@:jsRequire("solc")
extern class Solc {
    static function compile(input:{sources:haxe.DynamicAccess<String>}, optimization:Int):{contracts:Dynamic};
}