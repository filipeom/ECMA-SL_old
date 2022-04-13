// Copyright (c) 2012 Ecma International.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
es5id: 15.4.4.20-9-c-iii-9
description: >
    Array.prototype.filter - return value of callbackfn is a number
    (value is positive number)
---*/

        function callbackfn(val, idx, obj) {
            return 5;
        }

        var newArr = [11].filter(callbackfn);

assert.sameValue(newArr.length, 1, 'newArr.length');
assert.sameValue(newArr[0], 11, 'newArr[0]');
