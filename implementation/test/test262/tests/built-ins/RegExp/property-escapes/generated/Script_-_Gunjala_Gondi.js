// Copyright 2020 Mathias Bynens. All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
author: Mathias Bynens
description: >
  Unicode property escapes for `Script=Gunjala_Gondi`
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
    [0x011D60, 0x011D65],
    [0x011D67, 0x011D68],
    [0x011D6A, 0x011D8E],
    [0x011D90, 0x011D91],
    [0x011D93, 0x011D98],
    [0x011DA0, 0x011DA9]
  ]
});
testPropertyEscapes(
  /^\p{Script=Gunjala_Gondi}+$/u,
  matchSymbols,
  "\\p{Script=Gunjala_Gondi}"
);
testPropertyEscapes(
  /^\p{Script=Gong}+$/u,
  matchSymbols,
  "\\p{Script=Gong}"
);
testPropertyEscapes(
  /^\p{sc=Gunjala_Gondi}+$/u,
  matchSymbols,
  "\\p{sc=Gunjala_Gondi}"
);
testPropertyEscapes(
  /^\p{sc=Gong}+$/u,
  matchSymbols,
  "\\p{sc=Gong}"
);

const nonMatchSymbols = buildString({
  loneCodePoints: [
    0x011D66,
    0x011D69,
    0x011D8F,
    0x011D92
  ],
  ranges: [
    [0x00DC00, 0x00DFFF],
    [0x000000, 0x00DBFF],
    [0x00E000, 0x011D5F],
    [0x011D99, 0x011D9F],
    [0x011DAA, 0x10FFFF]
  ]
});
testPropertyEscapes(
  /^\P{Script=Gunjala_Gondi}+$/u,
  nonMatchSymbols,
  "\\P{Script=Gunjala_Gondi}"
);
testPropertyEscapes(
  /^\P{Script=Gong}+$/u,
  nonMatchSymbols,
  "\\P{Script=Gong}"
);
testPropertyEscapes(
  /^\P{sc=Gunjala_Gondi}+$/u,
  nonMatchSymbols,
  "\\P{sc=Gunjala_Gondi}"
);
testPropertyEscapes(
  /^\P{sc=Gong}+$/u,
  nonMatchSymbols,
  "\\P{sc=Gong}"
);
