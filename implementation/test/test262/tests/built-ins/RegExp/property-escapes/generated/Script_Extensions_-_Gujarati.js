// Copyright 2020 Mathias Bynens. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
author: Mathias Bynens
description: >
  Unicode property escapes for `Script_Extensions=Gujarati`
info: |
  Generated by https://github.com/mathiasbynens/unicode-property-escapes-tests
  Unicode v13.0.0
esid: sec-static-semantics-unicodematchproperty-p
features: [regexp-unicode-property-escapes]
includes: [regExpUtils.js]
---*/

const matchSymbols = buildString({
  loneCodePoints: [
    0x000AD0
  ],
  ranges: [
    [0x000951, 0x000952],
    [0x000964, 0x000965],
    [0x000A81, 0x000A83],
    [0x000A85, 0x000A8D],
    [0x000A8F, 0x000A91],
    [0x000A93, 0x000AA8],
    [0x000AAA, 0x000AB0],
    [0x000AB2, 0x000AB3],
    [0x000AB5, 0x000AB9],
    [0x000ABC, 0x000AC5],
    [0x000AC7, 0x000AC9],
    [0x000ACB, 0x000ACD],
    [0x000AE0, 0x000AE3],
    [0x000AE6, 0x000AF1],
    [0x000AF9, 0x000AFF],
    [0x00A830, 0x00A839]
  ]
});
testPropertyEscapes(
  /^\p{Script_Extensions=Gujarati}+$/u,
  matchSymbols,
  "\\p{Script_Extensions=Gujarati}"
);
testPropertyEscapes(
  /^\p{Script_Extensions=Gujr}+$/u,
  matchSymbols,
  "\\p{Script_Extensions=Gujr}"
);
testPropertyEscapes(
  /^\p{scx=Gujarati}+$/u,
  matchSymbols,
  "\\p{scx=Gujarati}"
);
testPropertyEscapes(
  /^\p{scx=Gujr}+$/u,
  matchSymbols,
  "\\p{scx=Gujr}"
);

const nonMatchSymbols = buildString({
  loneCodePoints: [
    0x000A84,
    0x000A8E,
    0x000A92,
    0x000AA9,
    0x000AB1,
    0x000AB4,
    0x000AC6,
    0x000ACA
  ],
  ranges: [
    [0x00DC00, 0x00DFFF],
    [0x000000, 0x000950],
    [0x000953, 0x000963],
    [0x000966, 0x000A80],
    [0x000ABA, 0x000ABB],
    [0x000ACE, 0x000ACF],
    [0x000AD1, 0x000ADF],
    [0x000AE4, 0x000AE5],
    [0x000AF2, 0x000AF8],
    [0x000B00, 0x00A82F],
    [0x00A83A, 0x00DBFF],
    [0x00E000, 0x10FFFF]
  ]
});
testPropertyEscapes(
  /^\P{Script_Extensions=Gujarati}+$/u,
  nonMatchSymbols,
  "\\P{Script_Extensions=Gujarati}"
);
testPropertyEscapes(
  /^\P{Script_Extensions=Gujr}+$/u,
  nonMatchSymbols,
  "\\P{Script_Extensions=Gujr}"
);
testPropertyEscapes(
  /^\P{scx=Gujarati}+$/u,
  nonMatchSymbols,
  "\\P{scx=Gujarati}"
);
testPropertyEscapes(
  /^\P{scx=Gujr}+$/u,
  nonMatchSymbols,
  "\\P{scx=Gujr}"
);
