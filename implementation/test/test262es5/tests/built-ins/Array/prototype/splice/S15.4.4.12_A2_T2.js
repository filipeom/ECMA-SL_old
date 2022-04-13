// Copyright 2009 the Sputnik authors.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
info: >
    The splice function is intentionally generic.
    It does not require that its this value be an Array object
es5id: 15.4.4.12_A2_T2
description: >
    If start is negative, use max(start + length, 0).  If deleteCount
    is negative, use 0
---*/

var obj = {0:0,1:1};
obj.length = 2;
obj.splice = Array.prototype.splice;
var arr = obj.splice(-2,-1,2,3);

//CHECK#0
arr.getClass = Object.prototype.toString;
if (arr.getClass() !== "[object " + "Array" + "]") {
  $ERROR('#0: var obj = {0:0,1:1}; obj.length = 2; obj.splice = Array.prototype.splice; var arr = obj.splice(-2,-1,2,3); arr is Array object. Actual: ' + (arr.getClass()));
}

//CHECK#1
if (arr.length !== 0) {
  $ERROR('#1: var obj = {0:0,1:1}; obj.length = 2; obj.splice = Array.prototype.splice; var arr = obj.splice(-2,-1,2,3); arr.length === 0. Actual: ' + (arr.length));
}   

//CHECK#2
if (obj.length !== 4) {
  $ERROR('#2: var obj = {0:0,1:1}; obj.length = 2; obj.splice = Array.prototype.splice; var arr = obj.splice(-2,-1,2,3); obj.length === 4. Actual: ' + (obj.length));
}      

//CHECK#3
if (obj[0] !== 2) {
  $ERROR('#3: var obj = {0:0,1:1}; obj.length = 2; obj.splice = Array.prototype.splice; var arr = obj.splice(-2,-1,2,3); obj[0] === 2. Actual: ' + (obj[0]));
}

//CHECK#4
if (obj[1] !== 3) {
  $ERROR('#4: var obj = {0:0,1:1}; obj.length = 2; obj.splice = Array.prototype.splice; var arr = obj.splice(-2,-1,2,3); obj[1] === 3. Actual: ' + (obj[1]));
}

//CHECK#5
if (obj[2] !== 0) {
  $ERROR('#5: var obj = {0:0,1:1}; obj.length = 2; obj.splice = Array.prototype.splice; var arr = obj.splice(-2,-1,2,3); obj[2] === 0. Actual: ' + (obj[2]));
}

//CHECK#6
if (obj[3] !== 1) {
  $ERROR('#6: var obj = {0:0,1:1}; obj.length = 2; obj.splice = Array.prototype.splice; var arr = obj.splice(-2,-1,2,3); obj[3] === 1. Actual: ' + (obj[3]));
}

//CHECK#7
if (obj[4] !== undefined) {
  $ERROR('#7: var obj = {0:0,1:1}; obj.length = 2; obj.splice = Array.prototype.splice; var arr = obj.splice(-2,-1,2,3); obj[4] === undefined. Actual: ' + (obj[4]));
}
