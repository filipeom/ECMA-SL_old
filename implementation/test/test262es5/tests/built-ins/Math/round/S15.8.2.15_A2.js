// Copyright 2009 the Sputnik authors.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
info: If x is +0, Math.round(x) is +0
es5id: 15.8.2.15_A2
description: Checking if Math.round(x) equals to +0, where x is +0
---*/

// CHECK#1
var x = +0;
if (Math.round(x) !== +0)
{
	$ERROR("#1: 'var x=+0; Math.round(x) !== +0'");
}
