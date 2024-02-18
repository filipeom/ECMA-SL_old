function Assert(cond) { if (cond !== true) { throw new Error("Assertion failed!"); } } function AssertUnreachable() { throw new Error("Assertion failed!"); } function AssertEquals(val, exp) { return Assert(val === exp); } function AssertArray(arr, exp) { return Assert(arr.length === exp.length && arr.every((element, index) => element === exp[index])); } function AssertObject(obj, exp) { return Assert(Object.keys(obj).length === Object.keys(exp).length && Object.keys(obj).every((fld, _) => obj[fld] === exp[fld])) }
/**
 * * javascript/regex/regex_39.js
 * 
 * Simple regex test: no description
*/

let regex = /.+/;
let ret = regex.exec("ccabcc");

AssertEquals(regex.lastIndex, 0);
AssertEquals(ret.length, 1);
AssertEquals(ret[0], "ccabcc");
AssertEquals(ret.index, 0);
AssertEquals(ret.input, "ccabcc");
