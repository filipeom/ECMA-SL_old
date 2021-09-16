// Copyright 2020 Mathias Bynens. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
author: Mathias Bynens
description: >
  Unicode property escapes for `Script_Extensions=Nandinagari`
info: |
  Generated by https://github.com/mathiasbynens/unicode-property-escapes-tests
  Unicode v13.0.0
esid: sec-static-semantics-unicodematchproperty-p
features: [regexp-unicode-property-escapes]
includes: [regExpUtils.js]
---*/

const matchSymbols = buildString({
  loneCodePoints: [
    0x001CE9,
    0x001CF2,
    0x001CFA
  ],
  ranges: [
    [0x000964, 0x000965],
    [0x000CE6, 0x000CEF],
    [0x00A830, 0x00A835],
    [0x0119A0, 0x0119A7],
    [0x0119AA, 0x0119D7],
    [0x0119DA, 0x0119E4]
  ]
});
testPropertyEscapes(
  /^\p{Script_Extensions=Nandinagari}+$/u,
  matchSymbols,
  "\\p{Script_Extensions=Nandinagari}"
);
testPropertyEscapes(
  /^\p{Script_Extensions=Nand}+$/u,
  matchSymbols,
  "\\p{Script_Extensions=Nand}"
);
testPropertyEscapes(
  /^\p{scx=Nandinagari}+$/u,
  matchSymbols,
  "\\p{scx=Nandinagari}"
);
testPropertyEscapes(
  /^\p{scx=Nand}+$/u,
  matchSymbols,
  "\\p{scx=Nand}"
);

const nonMatchSymbols = buildString({
  loneCodePoints: [],
  ranges: [
    [0x00DC00, 0x00DFFF],
    [0x000000, 0x000963],
    [0x000966, 0x000CE5],
    [0x000CF0, 0x001CE8],
    [0x001CEA, 0x001CF1],
    [0x001CF3, 0x001CF9],
    [0x001CFB, 0x00A82F],
    [0x00A836, 0x00DBFF],
    [0x00E000, 0x01199F],
    [0x0119A8, 0x0119A9],
    [0x0119D8, 0x0119D9],
    [0x0119E5, 0x10FFFF]
  ]
});
testPropertyEscapes(
  /^\P{Script_Extensions=Nandinagari}+$/u,
  nonMatchSymbols,
  "\\P{Script_Extensions=Nandinagari}"
);
testPropertyEscapes(
  /^\P{Script_Extensions=Nand}+$/u,
  nonMatchSymbols,
  "\\P{Script_Extensions=Nand}"
);
testPropertyEscapes(
  /^\P{scx=Nandinagari}+$/u,
  nonMatchSymbols,
  "\\P{scx=Nandinagari}"
);
testPropertyEscapes(
  /^\P{scx=Nand}+$/u,
  nonMatchSymbols,
  "\\P{scx=Nand}"
);
