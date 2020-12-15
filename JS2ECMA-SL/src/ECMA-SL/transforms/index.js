const Program = require("./program");
const Switch = require("./switch");
const PropertyAccessors = require("./propertyAccessors");
const Assignment = require("./assignment");
const FunctionLiteral = require("./functionLiteral");
const FunctionCall = require("./functionCall");
const Literal = require("./literal");
const EarlySyntaxError = require("./earlySyntaxError");

module.exports = {
  transformObject: function (obj) {
    if (obj.type === "Program") {
      return Program.transform(obj);
    }
    if (obj.type === "EarlySyntaxError") {
      return EarlySyntaxError.transform(obj);
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
    if (obj.type === "Literal") {
      return Literal.transform(obj);
    }
    return obj;
  },
};
