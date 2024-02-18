function Assert(cond) { if (cond !== true) { throw new Error("Assertion failed!"); } } function AssertUnreachable() { throw new Error("Assertion failed!"); } function AssertEquals(val, exp) { return Assert(val === exp); } function AssertArray(arr, exp) { return Assert(arr.length === exp.length && arr.every((element, index) => element === exp[index])); } function AssertObject(obj, exp) { return Assert(Object.keys(obj).length === Object.keys(exp).length && Object.keys(obj).every((fld, _) => obj[fld] === exp[fld])) }
/**
 * * javascript/regex/regex_49.js
 * 
 * Simple regex test: no description
*/

let regex = /[^a-c]+/;

let ret = regex.exec("abcdef");
AssertEquals(ret[0], "def");

ret = regex.exec("abcabc");
AssertEquals(ret, null);