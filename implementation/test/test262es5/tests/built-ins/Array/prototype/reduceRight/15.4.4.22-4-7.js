// Copyright (c) 2012 Ecma International.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
es5id: 15.4.4.22-4-7
description: >
    Array.prototype.reduceRight throws TypeError if callbackfn is
    Object without [[Call]] internal method
---*/

  var arr = new Array(10);
assert.throws(TypeError, function() {
    arr.reduceRight(new Object());
});
