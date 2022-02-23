// Copyright (C) 2016 the V8 project authors. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
esid: sec-dataview.prototype.setuint8
description: >
  Set values and return undefined
info: |
  24.2.4.18 DataView.prototype.setUint8 ( byteOffset, value )

  1. Let v be the this value.
  2. Return ? SetViewValue(v, byteOffset, true, "Uint8", value).

  24.2.1.2 SetViewValue ( view, requestIndex, isLittleEndian, type, value )

  ...
  15. Let bufferIndex be getIndex + viewOffset.
  16. Return SetValueInBuffer(buffer, bufferIndex, type, numberValue, isLittleEndian).

  24.1.1.6 SetValueInBuffer ( arrayBuffer, byteIndex, type, value [ , isLittleEndian ] )

  ...
  11. Store the individual bytes of rawBytes into block, in order, starting at
  block[byteIndex].
  12. Return NormalCompletion(undefined).
features: [Uint8Array]
includes: [byteConversionValues.js]
---*/

var buffer = new ArrayBuffer(1);
var sample = new DataView(buffer, 0);
//var typedArray = new Uint8Array(buffer, 0);

var values = byteConversionValues.values;
var expectedValues = byteConversionValues.expected.Uint8;

values.forEach(function(value, i) {
  var expected = expectedValues[i];
  console.log("iteração " + i)
  var result = sample.setUint8(0, value);

  //sample.getUint8(0);
  console.log("value: " + value + "; expected: " + expected + "; result: " + result)
  assert.sameValue(
    //typedArray[0],
    sample.getUint8(0),
    expected,
    "value: " + value
  );
  assert.sameValue(
    result,
    undefined,
    "return is undefined, value: " + value
  );
});
