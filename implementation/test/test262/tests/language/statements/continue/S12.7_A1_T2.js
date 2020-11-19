// Copyright 2009 the Sputnik authors.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
info: Appearing of continue without an IterationStatement leads to syntax error
es5id: 12.7_A1_T2
description: >
    Checking if single "continue" with Label but without any
    IterationStatement fails
negative: SyntaxError
---*/

LABEL : x=3.14;

//////////////////////////////////////////////////////////////////////////////
//CHECK#1
var x=1;
continue LABEL;
var y=2;
//
//////////////////////////////////////////////////////////////////////////////
