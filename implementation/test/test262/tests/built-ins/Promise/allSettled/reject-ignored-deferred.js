// Copyright (C) 2019 Leo Balter. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
description: >
  Resolved promises ignore rejections through deferred invocation of the
    provided resolving function
esid: sec-promise.allsettled
info: |
  6. Let result be PerformPromiseAllSettled(iteratorRecord, C, promiseCapability).

  Runtime Semantics: PerformPromiseAllSettled
  
  6. Repeat
    ...
    z. Perform ? Invoke(nextPromise, "then", « resolveElement, rejectElement »).
flags: [async]
features: [Promise.allSettled]
---*/

var simulation = {};

var fulfiller = {
  then(resolve) {
    new Promise(function(resolve) {
        resolve();
      })
      .then(function() {
        resolve(42);
      });
  }
};
var rejector = {
  then(resolve, reject) {
    new Promise(function(resolve) {
        resolve();
      })
      .then(function() {
        resolve(simulation);
        reject();
      });
  }
};

Promise.allSettled([fulfiller, rejector])
  .then(function (settleds) /* TODO: => */ {
    assert.sameValue(settleds.length, 2);
    assert.sameValue(settleds[0].status, 'fulfilled');
    assert.sameValue(settleds[0].value, 42);
    assert.sameValue(settleds[1].status, 'fulfilled');
    assert.sameValue(settleds[1].value, simulation);
  }).then($DONE, $DONE);
