const Store = require("../../Store");
const Heap = require("../Heap");
const Val =require("../Val/Val");
const LocationVal = require("../Val/LocationVal")(Val);
const AssignNewObjLab = require("../Labels/AssignNewObjLab");

function MakeAssignNewObj(Stmt){
	class AssignNewObj extends Stmt {
	  constructor(stringvar) {
	    super();
	    this.stringvar = stringvar;
	  }

	  interpret(config){
	  	var obj_name = config.heap.createObject();
	  	config.store.sto[this.stringvar] = new LocationVal(obj_name);
	  	config.cont=config.cont.slice(1);
	  	return {config : config, seclabel: new AssignNewObjLab(this.stringvar, obj_name)};
	  }
	}

	AssignNewObj.fromJSON = function(obj) {
		stringvar = obj.lhs;
		
		return new AssignNewObj(stringvar);

	}

	return AssignNewObj;
}

module.exports = MakeAssignNewObj;
