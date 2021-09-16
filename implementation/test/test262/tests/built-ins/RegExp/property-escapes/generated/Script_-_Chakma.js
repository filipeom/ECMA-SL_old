// Copyright 2020 Mathias Bynens. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
author: Mathias Bynens
description: >
  Unicode property escapes for `Script=Chakma`
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
    [0x011100, 0x011134],
    [0x011136, 0x011147]
  ]
});
testPropertyEscapes(
  /^\p{Script=Chakma}+$/u,
  matchSymbols,
  "\\p{Script=Chakma}"
);
testPropertyEscapes(
  /^\p{Script=Cakm}+$/u,
  matchSymbols,
  "\\p{Script=Cakm}"
);
testPropertyEscapes(
  /^\p{sc=Chakma}+$/u,
  matchSymbols,
  "\\p{sc=Chakma}"
);
testPropertyEscapes(
  /^\p{sc=Cakm}+$/u,
  matchSymbols,
  "\\p{sc=Cakm}"
);

const nonMatchSymbols = buildString({
  loneCodePoints: [
    0x011135
  ],
  ranges: [
    [0x00DC00, 0x00DFFF],
    [0x000000, 0x00DBFF],
    [0x00E000, 0x0110FF],
    [0x011148, 0x10FFFF]
  ]
});
testPropertyEscapes(
  /^\P{Script=Chakma}+$/u,
  nonMatchSymbols,
  "\\P{Script=Chakma}"
);
testPropertyEscapes(
  /^\P{Script=Cakm}+$/u,
  nonMatchSymbols,
  "\\P{Script=Cakm}"
);
testPropertyEscapes(
  /^\P{sc=Chakma}+$/u,
  nonMatchSymbols,
  "\\P{sc=Chakma}"
);
testPropertyEscapes(
  /^\P{sc=Cakm}+$/u,
  nonMatchSymbols,
  "\\P{sc=Cakm}"
);
