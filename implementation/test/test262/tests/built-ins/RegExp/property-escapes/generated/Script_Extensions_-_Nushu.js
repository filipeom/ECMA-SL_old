// Copyright 2020 Mathias Bynens. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
author: Mathias Bynens
description: >
  Unicode property escapes for `Script_Extensions=Nushu`
info: |
  Generated by https://github.com/mathiasbynens/unicode-property-escapes-tests
  Unicode v13.0.0
esid: sec-static-semantics-unicodematchproperty-p
features: [regexp-unicode-property-escapes]
includes: [regExpUtils.js]
---*/

const matchSymbols = buildString({
  loneCodePoints: [
    0x016FE1
  ],
  ranges: [
    [0x01B170, 0x01B2FB]
  ]
});
testPropertyEscapes(
  /^\p{Script_Extensions=Nushu}+$/u,
  matchSymbols,
  "\\p{Script_Extensions=Nushu}"
);
testPropertyEscapes(
  /^\p{Script_Extensions=Nshu}+$/u,
  matchSymbols,
  "\\p{Script_Extensions=Nshu}"
);
testPropertyEscapes(
  /^\p{scx=Nushu}+$/u,
  matchSymbols,
  "\\p{scx=Nushu}"
);
testPropertyEscapes(
  /^\p{scx=Nshu}+$/u,
  matchSymbols,
  "\\p{scx=Nshu}"
);

const nonMatchSymbols = buildString({
  loneCodePoints: [],
  ranges: [
    [0x00DC00, 0x00DFFF],
    [0x000000, 0x00DBFF],
    [0x00E000, 0x016FE0],
    [0x016FE2, 0x01B16F],
    [0x01B2FC, 0x10FFFF]
  ]
});
testPropertyEscapes(
  /^\P{Script_Extensions=Nushu}+$/u,
  nonMatchSymbols,
  "\\P{Script_Extensions=Nushu}"
);
testPropertyEscapes(
  /^\P{Script_Extensions=Nshu}+$/u,
  nonMatchSymbols,
  "\\P{Script_Extensions=Nshu}"
);
testPropertyEscapes(
  /^\P{scx=Nushu}+$/u,
  nonMatchSymbols,
  "\\P{scx=Nushu}"
);
testPropertyEscapes(
  /^\P{scx=Nshu}+$/u,
  nonMatchSymbols,
  "\\P{scx=Nshu}"
);
