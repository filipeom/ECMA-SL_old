function MakeSymbolVal(Val){
	class SymbolVal extends Val{
	  constructor(value) {
	  	super();
	    this.value = value;
	  }

	  toJS(){
      return {
        "type": "Literal",
        "value": this.value,
        "raw": ""+this.value
      }
    }
	}

	 SymbolVal.fromJSON = function(value) {
	 	return new SymbolVal(value);
	}
	return SymbolVal;
}
module.exports = MakeSymbolVal;