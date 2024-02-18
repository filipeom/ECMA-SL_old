/**
 * * javascript/simple/harness.js
 * 
 * Harness for the simple javascript tests.
*/

function Assert(cond) {
	if (cond !== true) {
		throw new Error("Assertion failed!");
	}
}

function AssertUnreachable() {
	throw new Error("Assertion failed!");
}

function AssertEquals(val, exp) {
	return Assert(val === exp);
}

function AssertArray(arr, exp) {
	return Assert(arr.length === exp.length
		&& arr.every((element, index) => element === exp[index]));
}

function AssertObject(obj, exp) {
	return Assert(Object.keys(obj).length === Object.keys(exp).length
		&& Object.keys(obj).every((fld, _) => obj[fld] === exp[fld]))
}
