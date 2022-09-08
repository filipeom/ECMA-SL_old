const mapper = require("./mapper");

module.exports = {
  processTailCalls: ProcessTailCalls,
};


function ProcessTailCalls (obj) {


    function callback (obj) {
      switch (obj.type) {
        case "ReturnStatement": 
            if (obj.argument.type === "CallExpression") {
                obj.argument.is_tail_call = true;
            }

            return {
                obj, 
                recurse: false
            }

         default:
          return {
            obj,
            recurse: true
          }
      }
    }
  
    return mapper(callback, obj)
  }

