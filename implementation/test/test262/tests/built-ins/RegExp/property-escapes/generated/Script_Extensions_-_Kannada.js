// Copyright 2020 Mathias Bynens. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
author: Mathias Bynens
description: >
  Unicode property escapes for `Script_Extensions=Kannada`
info: |
  Generated by https://github.com/mathiasbynens/unicode-property-escapes-tests
  Unicode v13.0.0
esid: sec-static-semantics-unicodematchproperty-p
features: [regexp-unicode-property-escapes]
includes: [regExpUtils.js]
---*/

const matchSymbols = buildString({
  loneCodePoints: [
    0x000CDE,
    0x001CD0,
    0x001CD2,
    0x001CDA,
    0x001CF2,
    0x001CF4
  ],
  ranges: [
    [0x000951, 0x000952],
    [0x000964, 0x000965],
    [0x000C80, 0x000C8C],
    [0x000C8E, 0x000C90],
    [0x000C92, 0x000CA8],
    [0x000CAA, 0x000CB3],
    [0x000CB5, 0x000CB9],
    [0x000CBC, 0x000CC4],
    [0x000CC6, 0x000CC8],
    [0x000CCA, 0x000CCD],
    [0x000CD5, 0x000CD6],
    [0x000CE0, 0x000CE3],
    [0x000CE6, 0x000CEF],
    [0x000CF1, 0x000CF2],
    [0x00A830, 0x00A835]
  ]
});
testPropertyEscapes(
  /^\p{Script_Extensions=Kannada}+$/u,
  matchSymbols,
  "\\p{Script_Extensions=Kannada}"
);
testPropertyEscapes(
  /^\p{Script_Extensions=Knda}+$/u,
  matchSymbols,
  "\\p{Script_Extensions=Knda}"
);
testPropertyEscapes(
  /^\p{scx=Kannada}+$/u,
  matchSymbols,
  "\\p{scx=Kannada}"
);
testPropertyEscapes(
  /^\p{scx=Knda}+$/u,
  matchSymbols,
  "\\p{scx=Knda}"
);

const nonMatchSymbols = buildString({
  loneCodePoints: [
    0x000C8D,
    0x000C91,
    0x000CA9,
    0x000CB4,
    0x000CC5,
    0x000CC9,
    0x000CDF,
    0x000CF0,
    0x001CD1,
    0x001CF3
  ],
  ranges: [
    [0x00DC00, 0x00DFFF],
    [0x000000, 0x000950],
    [0x000953, 0x000963],
    [0x000966, 0x000C7F],
    [0x000CBA, 0x000CBB],
    [0x000CCE, 0x000CD4],
    [0x000CD7, 0x000CDD],
    [0x000CE4, 0x000CE5],
    [0x000CF3, 0x001CCF],
    [0x001CD3, 0x001CD9],
    [0x001CDB, 0x001CF1],
    [0x001CF5, 0x00A82F],
    [0x00A836, 0x00DBFF],
    [0x00E000, 0x10FFFF]
  ]
});
testPropertyEscapes(
  /^\P{Script_Extensions=Kannada}+$/u,
  nonMatchSymbols,
  "\\P{Script_Extensions=Kannada}"
);
testPropertyEscapes(
  /^\P{Script_Extensions=Knda}+$/u,
  nonMatchSymbols,
  "\\P{Script_Extensions=Knda}"
);
testPropertyEscapes(
  /^\P{scx=Kannada}+$/u,
  nonMatchSymbols,
  "\\P{scx=Kannada}"
);
testPropertyEscapes(
  /^\P{scx=Knda}+$/u,
  nonMatchSymbols,
  "\\P{scx=Knda}"
);
