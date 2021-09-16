// Copyright 2020 Mathias Bynens. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
author: Mathias Bynens
description: >
  Unicode property escapes for `Script=Bamum`
info: |
  Generated by https://github.com/mathiasbynens/unicode-property-escapes-tests
  Unicode v13.0.0
esid: sec-static-semantics-unicodematchproperty-p
features: [regexp-unicode-property-escapes]
includes: [regExpUtils.js]
---*/

const matchSymbols = buildString({
  loneCodePoints: [],
  ranges: [
    [0x00A6A0, 0x00A6F7],
    [0x016800, 0x016A38]
  ]
});
testPropertyEscapes(
  /^\p{Script=Bamum}+$/u,
  matchSymbols,
  "\\p{Script=Bamum}"
);
testPropertyEscapes(
  /^\p{Script=Bamu}+$/u,
  matchSymbols,
  "\\p{Script=Bamu}"
);
testPropertyEscapes(
  /^\p{sc=Bamum}+$/u,
  matchSymbols,
  "\\p{sc=Bamum}"
);
testPropertyEscapes(
  /^\p{sc=Bamu}+$/u,
  matchSymbols,
  "\\p{sc=Bamu}"
);

const nonMatchSymbols = buildString({
  loneCodePoints: [],
  ranges: [
    [0x00DC00, 0x00DFFF],
    [0x000000, 0x00A69F],
    [0x00A6F8, 0x00DBFF],
    [0x00E000, 0x0167FF],
    [0x016A39, 0x10FFFF]
  ]
});
testPropertyEscapes(
  /^\P{Script=Bamum}+$/u,
  nonMatchSymbols,
  "\\P{Script=Bamum}"
);
testPropertyEscapes(
  /^\P{Script=Bamu}+$/u,
  nonMatchSymbols,
  "\\P{Script=Bamu}"
);
testPropertyEscapes(
  /^\P{sc=Bamum}+$/u,
  nonMatchSymbols,
  "\\P{sc=Bamum}"
);
testPropertyEscapes(
  /^\P{sc=Bamu}+$/u,
  nonMatchSymbols,
  "\\P{sc=Bamu}"
);
