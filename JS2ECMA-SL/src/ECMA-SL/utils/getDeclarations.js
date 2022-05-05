const traverse = require("./traverse");
const mapper = require("./mapper");

module.exports = {
  getVarDeclarations: getVarDeclrs,
  getFunctionDeclarations: getFuncDeclrs,
  replaceFuncDeclarations: replaceFuncDeclarations,
  getLetDeclarations: getLetDeclrs
};



function getVarDeclrs(obj) {
  function callback(obj) {
    if (!obj) {
      return {
        stop: true,
        data: [],
      };
    }

    switch (obj.type) {
      case "FunctionDeclaration":
      case "FunctionExpression":
      case "ArrowFunctionExpression":
        return {
          stop: true,
          data: [],
        };

      case "VariableDeclaration":
        
        if (obj.kind == "var") {
          const vars = obj.declarations.reduce(
            (acc, declr) => acc.concat(declr.id.name),
            []
          );

          return {
            stop: true,
            data: vars,
          };
        } else {
          return {
            stop: true,
            data: [],
          };
        }

      default:
        return {
          stop: false,
          data: [],
        };
    }
  }

  return traverse(callback, obj).data;
}




function getLetDeclrs(obj) {
  function callback(obj) {
    if (!obj) {
      return {
        stop: true,
        data: [],
      };
    }

    switch (obj.type) {
      case "FunctionDeclaration":
      case "FunctionExpression":
      case "ArrowFunctionExpression":
        return {
          stop: true,
          data: [],
        };

      case "VariableDeclaration":
        
        if (obj.kind == "let") {
          const vars = obj.declarations.reduce(
            (acc, declr) => acc.concat(declr.id.name),
            []
          );

          return {
            stop: true,
            data: vars,
          };
        } else {
          return {
            stop: true,
            data: [],
          };
        }

      default:
        return {
          stop: false,
          data: [],
        };
    }
  }

  return traverse(callback, obj).data;
}



function getFuncDeclrs(obj) {
  function callback(obj) {
    if (!obj) {
      return {
        stop: true,
        data: [],
      };
    }

    switch (obj.type) {
      case "FunctionDeclaration":
        return {
          stop: true,
          data: [obj],
        };

      case "FunctionExpression":
        return {
          stop: true,
          data: [],
        };

      case "ArrowFunctionExpression":
        return {
          stop: true,
          data: [],
        };

      default:
        return {
          stop: false,
          data: [],
        };
    }
  }
  return traverse(callback, obj).data;
}

function replaceFuncDeclarations(obj) {
  function callback(obj) {
    if (!obj)
      return {
        obj,
        recurse: false,
      };

    switch (obj.type) {
      case "FunctionDeclaration":
        return {
          obj: newExpressionStatement(obj.id),
          recurse: false,
        };

      case "FunctionExpression":
        return {
          obj,
          recurse: false,
        };

      default:
        return {
          obj,
          recurse: true,
        };
    }
  }

  return mapper(callback, obj);
}

function newExpressionStatement(expression) {
  return {
    type: "ExpressionStatement",
    expression,
  };
}
