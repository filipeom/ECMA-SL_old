
const Val = require("./Val/Val");
const PrimitiveVal = require("./Val/PrimitiveVal")(Val);
const ListVal = require("./Val/ListVal")(Val);
const TupleVal = require("./Val/TupleVal")(Val);

var binary_dictionary = {
    "Plus": "+", 
    "Minus": "-",
    "Times": "*",
    "Div": "/",
    "Equal": "==",
    "Gt": ">",
    "Lt": "<",
    "Egt": ">=",
    "Elt": "<=",
    "FloatToString": "+"};
  var logical_dictionary = {
    "Log_And": "&&",
    "Log_Or": "||"
  };
  var function_dictionary = {
    "InObj": "hasOwnProperty",
    "Lconcat": "concat",
    "Ladd": "push",
    "InList": "includes",
    "Tail": "slice",
    "IntToFloat": "toFixed"
  }; 

class Oper{
  constructor(operator, type) {
    this.operator = operator;
    this.type = type;
  }

  interpret(val1,val2){
    console.log("==== "+ this.operator);
  	switch(this.operator){
  		//BinOpt
  		case "Plus":  return new PrimitiveVal(val1.value + val2.value);
  		case "Minus": return new PrimitiveVal(val1.value + val2.value);
  		case "Times": return new PrimitiveVal(val1.value * val2.value);
  		case "Div": return new PrimitiveVal(val1.value - val2.value);
  		case "Equal": return new PrimitiveVal(val1.value === val2.value); //Check
  		case "Gt": return new PrimitiveVal(val1.value > val2.value); //Check
  		case "Lt": return new PrimitiveVal(val1.value < val2.value); //Check
  		case "Egt": return new PrimitiveVal(val1.value >= val2.value); //Check
  		case "Elt": return new PrimitiveVal(val1.value <= val2.value); //Check
  		case "Log_And": return new PrimitiveVal(val1.value && val2.value); //Check
  		case "Log_Or": return new PrimitiveVal(val1.value || val2.value); //Check
  		case "InObj": return new PrimitiveVal(true); //TODO //Extended ECMA-SL
  		case "InList": return new PrimitiveVal(val1.value.includes(val2.value));
  		case "Lnth": return val1.list[val2.value];//TODO
  		case "Tnth":return new PrimitiveVal(true);//TODO
  		case "Ladd":return new PrimitiveVal(true);//TODO
  		case "Lconcat": return new ListVal(val1.value.concat(val2.value))
  		//UnOpt
  		case "Neg": return new PrimitiveVal(-val1.value);
  		case "Not": return new PrimitiveVal(!(val1.value));
  		case "Typeof": return new PrimitiveVal(typeof val1.value);
  		case "ListLen": return new PrimitiveVal(val1.list.length);
  		case "TupleLen": return new PrimitiveVal(val1.value.length); // JS does not have tuples
  		case "Head": return val1.getMember(0);
  		case "Tail": return val1.getTail();
  		case "First": return new Val(val1.value[0]); //JS does not have tuples
  		case "Second": return new Val(val1.value.slice(1)); // JS does not have tuples
  		case "IntToFloat": return new PrimitiveVal(0.0 + val1.value);
  		case "FloatToString": return new PrimitiveVal(String.valueOf(val1.value));
  		case "ObjToList": return new ListVal([]);//TODO
  		//NOpt
  		case "ListExpr":  return new ListVal(val1);
  		case "TupleExpr": return new TupleVal(val1);
  		case "NAry_And":  var reducer = (accumulator, value) => accumulator && value;
  						          return new PrimitiveVal(val1.reduce(reducer, true));
  		case "NAry_Or": var reducer = (accumulator, value) => accumulator || value; 
  						        return new PrimitiveVal(val1.reduce(reducer, false));
      case "Sconcat": var reducer = (accumulator, value) => accumulator + value.value;
                      return new PrimitiveVal(val1.list.reduce(reducer,""));
  		default: throw new Error("Unsupported Argument"+ this.operator)
  	}

  }

  
  memberExpression(e1,e2){
    return {
          "type": "MemberExpression",
          "computed": true,
          "object": e1,
          "property": e2
        };
  }

  callExpression(e1,e2){
    return {
      "type": "CallExpression",
      "callee": {
        "type": "MemberExpression",
        "computed": false,
        "object": e1,
        "property": {
          "type": "Identifier",
          "name": function_dictionary[this.operator]
        }
      },
      "arguments": [
        e2
      ]
    };
  }

  binaryExpression(e1,e2){
    return {
      "type": "BinaryExpression",
      "operator": binary_dictionary[this.operator],
      "left": e1,
      "right": e2
    };
  }

  toJS(e1, e2){    
    switch(this.operator){
      //BinOpt
      case "Plus":  
      case "Minus": 
      case "Times": 
      case "Div":
      case "Equal": 
      case "Gt": 
      case "Lt": 
      case "Egt": 
      case "Elt": 
        return this.binaryExpression(e1,e2);
      //LOGICAL OPERATIONS (NOT A BINARY EXPRESSION)
      case "Log_And":
      case "Log_Or": 
        return {
          "type": "LogicalExpression",
          "operator": logical_dictionary[this.operator],
          "left": e1,
          "right": e2
        }; 

      //FUNCTIONS
      case "Tail":
        e2 ={
              "type": "Literal",
              "value": 1,
              "raw": "1"
            };
        return callExpression(e1,e2);
      case "IntToFloat":
        e2 = {
              "type": "Literal",
              "value": 2,
              "raw": "2"
            };
        return callExpression(e1,e2);
      case "InObj": 
      case "Lconcat": 
      case "Ladd":
      case "InList":
        return callExpression(e1,e2);

      case "Lnth": 
      case "Tnth":
        return memberExpression(e1,e2);
      //UnOpt
      case "Neg": return "-";
      case "Not": return "!";
      case "Typeof": return "typeof";
      case "ListLen":
      case "TupleLen": 
        return {
          "type": "MemberExpression",
          "computed": false,
          "object": e1,
          "property": {
            "type": "Identifier",
            "name": "length"
          }
        }; 
      case "First":
      case "Head": 
        e2 = {
          "type": "Literal",
          "value": 0,
          "raw": "0"
        };
        return memberExpression(e1,e2); //JS does not have tuples
      case "Second": 
        e2 = {
          "type": "Literal",
          "value": 0,
          "raw": "0"
        };
        return memberExpression(e1,e2);// JS does not have tuples
      case "FloatToString": 
        e2 = {
            "type": "Literal",
            "value": "",
            "raw": "\"\""
          };
        return binaryExpression(e2,e1);
      case "ObjToList": return "PROBLEM";//TODO
      //NOpt
      case "ListExpr":  return "DONT KNOW";
      case "TupleExpr": return "DONT KNOW";


      case "NAry_And": "&&";
      case "NAry_Or": "||";
      case "Sconcat": "+";
      default: throw new Error("Unsupported Argument"+ this.operator)
    }
  }
}

Oper.fromJSON = function(obj){
  return new Oper(obj.value, obj.type);
}


module.exports = Oper;