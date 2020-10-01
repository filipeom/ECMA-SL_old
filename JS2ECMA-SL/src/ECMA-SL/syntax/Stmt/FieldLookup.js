const Expr = require("../Expr/Expr");
const EmptyLab = require("../Labels/EmptyLab");

function MakeFieldLookup(Stmt){
  
  class FieldLookup extends Stmt {
    constructor(stringvar, expressionObject, expressionField) {
      super();
      this.expressionObject = expressionObject;
      this.expressionField = expressionField;
      this.stringvar = stringvar;
    }

    interpret(config){
      config.store.sto[this.stringvar] = config.heap.getField(this.expressionObject.interpret(config.store).value, this.expressionField.interpret(config.store).value);
      config.cont=config.cont.slice(1);
     return {config : config, seclabel: new EmptyLab()};
    }

   
  }
  FieldLookup.fromJSON = function(obj) {
  	var expr_obj = Expr.fromJSON(obj.obj);
  	var expr_field = Expr.fromJSON(obj.field);
  	var stringvar = obj.lhs;
  	return new FieldLookup(stringvar,expr_obj,expr_field);

  }
  return FieldLookup;
}

module.exports = MakeFieldLookup;
