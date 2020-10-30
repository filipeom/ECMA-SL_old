// Copyright 2009 the Sputnik authors.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
info: The toLocaleString property of Array has the attribute DontEnum
es5id: 15.4.4.3_A4.5
description: Checking use propertyIsEnumerable, for-in
---*/

//CHECK#1
if (Array.propertyIsEnumerable('toLocaleString') !== false) {
  $ERROR('#1: Array.propertyIsEnumerable(\'toLocaleString\') === false. Actual: ' + (Array.propertyIsEnumerable('toLocaleString')));
}

//CHECK#2
var result = true;
for (var p in Array){
  if (p === "toLocaleString") {
    result = false;
  }  
}

if (result !== true) {
  $ERROR('#2: result = true; for (p in Array) { if (p === "toLocaleString") result = false; }  result === true;');
}
