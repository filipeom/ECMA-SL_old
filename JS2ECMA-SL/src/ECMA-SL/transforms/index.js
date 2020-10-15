const Program = require("./program");
const Switch = require("./switch");
const PropertyAccessors = require("./propertyAccessors");
const Assignment = require("./assignment");
const FunctionLiteral = require("./functionLiteral");
const FunctionCall = require("./functionCall");
const Identifier = require("./identifier");
const Literal = require("./literal");

module.exports = {
  transformObject: function (obj) {
    if (obj.type === "Program") {
      return Program.transform(obj);
    }
    if (obj.type === "SwitchStatement") {
      return Switch.transform(obj);
    }
    if (obj.type === "MemberExpression") {
      return PropertyAccessors.transform(obj);
    }
    if (obj.type === "AssignmentExpression") {
      return Assignment.transform(obj);
    }
    if (
      obj.type === "FunctionExpression" ||
      obj.type === "FunctionDeclaration"
    ) {
      return FunctionLiteral.transform(obj);
    }
    if (obj.type === "CallExpression") {
      return FunctionCall.transform(obj);
    }
    if (obj.type === "Identifier") {
      return Identifier.transform(obj)
    }
    if (obj.type === "Literal") {
      return Literal.transform(obj);
    }
    return obj;
  },
};
