/**
 * * javascript/simple/events.js
 * 
 * Object with three recursive mathematical operations stored as events.  
 * @return true
*/

let math = {
	sum: function sum(x) {
		if (x < 1) {
			return 0;
		} else {
			return this.sum(x - 1) + x;
		}
	},
	
	fib: function fib(x) {
		if (x < 3) {
			return 1;
		} else {
			return this.fib(x - 1) + this.fib(x - 2);
		}
	},

	fact: function fact(x) {
		if (x < 1) {
			return 1;
		} else {
			return this.fact(x - 1) * x;
		}
	}
};

let total = 0;
total += math["sum"](4);
total += math["fib"](4);
total += math["fact"](4);

AssertEquals(total, 37);
