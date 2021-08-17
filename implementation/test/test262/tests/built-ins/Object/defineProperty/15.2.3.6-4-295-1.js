// Copyright (c) 2012 Ecma International.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
es5id: 15.2.3.6-4-295-1
description: >
    Object.defineProperty - 'O' is an Arguments object of a function
    that has formal parameters, 'name' is own data property of 'O'
    which is also defined in [[ParameterMap]] of 'O', test TypeError
    is thrown when updating the [[Enumerable]] attribute value of
    'name' which is defined as non-configurable (10.6
    [[DefineOwnProperty]] step 4 and step 5b)
includes: [propertyHelper.js]
flags: [noStrict]
---*/


(function(a, b, c) {
  Object.defineProperty(arguments, "0", {
    value: 10,
    writable: false,
    enumerable: true,
    configurable: false
  });
  try {
    Object.defineProperty(arguments, "0", {
      enumerable: false
    });
    $ERROR("Expected an exception.");
  } catch (e) {
    if (!(e instanceof TypeError)) {
      $ERROR("Expected TypeError, got " + e);
    }

    verifyEqualTo(arguments, "0", 10);

    verifyNotWritable(arguments, "0");

    verifyEnumerable(arguments, "0");

    verifyNotConfigurable(arguments, "0");

    if (a !== 10) {
      $ERROR('Expected "a === 10", actually ' + a);
    }
  }
}(0, 1, 2));
