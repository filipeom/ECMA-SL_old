// Copyright 2020 Mathias Bynens. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
author: Mathias Bynens
description: >
  Unicode property escapes for `Script=Kaithi`
info: |
  Generated by https://github.com/mathiasbynens/unicode-property-escapes-tests
  Unicode v13.0.0
esid: sec-static-semantics-unicodematchproperty-p
features: [regexp-unicode-property-escapes]
includes: [regExpUtils.js]
---*/

const matchSymbols = buildString({
  loneCodePoints: [
    0x0110CD
  ],
  ranges: [
    [0x011080, 0x0110C1]
  ]
});
testPropertyEscapes(
  /^\p{Script=Kaithi}+$/u,
  matchSymbols,
  "\\p{Script=Kaithi}"
);
testPropertyEscapes(
  /^\p{Script=Kthi}+$/u,
  matchSymbols,
  "\\p{Script=Kthi}"
);
testPropertyEscapes(
  /^\p{sc=Kaithi}+$/u,
  matchSymbols,
  "\\p{sc=Kaithi}"
);
testPropertyEscapes(
  /^\p{sc=Kthi}+$/u,
  matchSymbols,
  "\\p{sc=Kthi}"
);

const nonMatchSymbols = buildString({
  loneCodePoints: [],
  ranges: [
    [0x00DC00, 0x00DFFF],
    [0x000000, 0x00DBFF],
    [0x00E000, 0x01107F],
    [0x0110C2, 0x0110CC],
    [0x0110CE, 0x10FFFF]
  ]
});
testPropertyEscapes(
  /^\P{Script=Kaithi}+$/u,
  nonMatchSymbols,
  "\\P{Script=Kaithi}"
);
testPropertyEscapes(
  /^\P{Script=Kthi}+$/u,
  nonMatchSymbols,
  "\\P{Script=Kthi}"
);
testPropertyEscapes(
  /^\P{sc=Kaithi}+$/u,
  nonMatchSymbols,
  "\\P{sc=Kaithi}"
);
testPropertyEscapes(
  /^\P{sc=Kthi}+$/u,
  nonMatchSymbols,
  "\\P{sc=Kthi}"
);
