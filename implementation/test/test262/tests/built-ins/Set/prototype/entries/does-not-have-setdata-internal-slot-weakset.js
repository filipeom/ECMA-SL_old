// Copyright (C) 2015 the V8 project authors. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.
/*---
es6id: 23.2.3.5
description: >
    Set.prototype.entries ( )

    ...
    2. Return CreateSetIterator(S, "key+value").


    23.2.5.1 CreateSetIterator Abstract Operation

    ...
    2. If S does not have a [[SetData]] internal slot, throw a TypeError exception.
    ...
features: [WeakSet]
---*/

assert.throws(TypeError, function() {
  Set.prototype.entries.call(new WeakSet());
});

assert.throws(TypeError, function() {
  var s = new Set();
  s.entries.call(new WeakSet());
});
