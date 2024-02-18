function Assert(cond) { if (cond !== true) { throw new Error("Assertion failed!"); } } function AssertUnreachable() { throw new Error("Assertion failed!"); } function AssertEquals(val, exp) { return Assert(val === exp); } function AssertArray(arr, exp) { return Assert(arr.length === exp.length && arr.every((element, index) => element === exp[index])); } function AssertObject(obj, exp) { return Assert(Object.keys(obj).length === Object.keys(exp).length && Object.keys(obj).every((fld, _) => obj[fld] === exp[fld])) }
/**
 * * javascript/regex/regex_48.js
 * 
 * Simple regex test: no description
*/

let regex = /\w+\W+/;

let ret = regex.exec("0azAZ_.,-");
AssertEquals(ret[0], "0azAZ_.,-");

ret = regex.exec("0azAZ");
AssertEquals(ret, null);