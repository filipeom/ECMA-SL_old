const Func = require("./Func");

class Prog {
  constructor(funcs) {
    this.funcs = funcs;
  }

  toString(){
  	var funcs_str = this.funcs.map(f => f.toString());
  	return funcs_str.join("\n");
  }

  getFunc(name){
    return this.funcs.find(func => func.name === name);   
  }
}

Prog.fromJSON = function (obj) {
  var funcs = obj.funcs.map(func => Func.fromJSON(func));
  return new Prog(funcs); 
}

module.exports = Prog;
