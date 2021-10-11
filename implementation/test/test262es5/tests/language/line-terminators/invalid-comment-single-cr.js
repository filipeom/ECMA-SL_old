// Copyright 2009 the Sputnik authors.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
info: Single line comments can not contain CARRIAGE RETURN (U+000D) inside
es5id: 7.3_A3.2_T2
esid: sec-line-terminators
description: Insert CARRIAGE RETURN (\u000D) into begin of single line comment
negative:
  phase: parse
  type: SyntaxError
---*/

$DONOTEVALUATE();

// this text is not included in the single-line comment that precedes it
