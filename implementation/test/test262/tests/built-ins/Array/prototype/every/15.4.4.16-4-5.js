// Copyright (c) 2012 Ecma International.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
es5id: 15.4.4.16-4-5
description: Array.prototype.every throws TypeError if callbackfn is number
---*/

  var arr = new Array(10);
assert.throws(TypeError, function() {
    arr.every(5);
});
