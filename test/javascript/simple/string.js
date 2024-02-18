/**
 * * javascript/simple/string.js
 * 
 * Simple consecutive string operations applied to string variables. 
 * @return true
*/

function getEvenChars(text) {
	let evenChars = "";
	for (let i = 0; i < text.length; i++) {
		if (i % 2 == 0) {
			evenChars += text[i];
		}
	}
	return evenChars;
}

function checkStart(text, start) {
	if (text.startsWith(start)) {
		return text + "-good";
	} else {
		return text;
	}
}

let x = "abc";
let y = getEvenChars(x + "def");
let z = checkStart(y, "ac");
let w = z + z.charCodeAt(0);

AssertEquals(w, "ace-good97");
