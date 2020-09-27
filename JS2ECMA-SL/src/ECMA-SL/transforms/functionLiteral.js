const {
  getVarDeclarations,
  getFunctionDeclarations,
} = require("../utils/getDeclarations");

module.exports = {
  transform: function (obj) {
    if (!["FunctionExpression", "FunctionDeclaration"].includes(obj.type)) {
      throw Error(
        'Unexpected object type; Expecting "FunctionExpression" or "FunctionDeclaration"'
      );
    }

    obj.params = obj.params.map((param) => param.name);

    obj.localVars = getVarDeclarations(obj.body).reduce(
      // remove repeated variables
      (acc, localVar) => (acc.includes(localVar) ? acc : acc.concat(localVar)),
      []
    );
    obj.localFuncs = getFunctionDeclarations(obj.body).reduce(
      // remove repeated functions
      (acc, localVar) => (acc.includes(localVar) ? acc : acc.concat(localVar)),
      []
    );

    return obj;
  },
};
