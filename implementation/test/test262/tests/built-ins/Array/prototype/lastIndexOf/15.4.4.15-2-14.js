// Copyright (c) 2012 Ecma International.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
es5id: 15.4.4.15-2-14
description: >
    Array.prototype.lastIndexOf - 'length' is undefined property on an
    Array-like object
---*/

        var obj = { 0: null, 1: undefined };

assert.sameValue(Array.prototype.lastIndexOf.call(obj, null), -1, 'Array.prototype.lastIndexOf.call(obj, null)');
