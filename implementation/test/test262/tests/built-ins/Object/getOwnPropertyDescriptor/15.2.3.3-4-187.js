// Copyright (c) 2012 Ecma International.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
es5id: 15.2.3.3-4-187
description: >
    Object.getOwnPropertyDescriptor returns data desc for properties
    on built-ins (Function (instance).length)
---*/

var f = Function('return 42;');

var desc = Object.getOwnPropertyDescriptor(f, "length");

assert.sameValue(desc.writable, false, 'desc.writable');
assert.sameValue(desc.enumerable, false, 'desc.enumerable');
assert.sameValue(desc.configurable, true, 'desc.configurable');
assert.sameValue(desc.hasOwnProperty('get'), false, 'desc.hasOwnProperty("get")');
assert.sameValue(desc.hasOwnProperty('set'), false, 'desc.hasOwnProperty("set")');
