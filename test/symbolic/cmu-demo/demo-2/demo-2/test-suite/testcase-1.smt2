; 
(set-info :status true)
(declare-fun cond1___instr_symb_num_0 () Real)
(assert
 (let ((?x9 (* cond1___instr_symb_num_0 10.0)))
 (let (($x37 (= ?x9 0.0)))
 (= $x37 false))))
(assert
 (let ((?x9 (* cond1___instr_symb_num_0 10.0)))
 (let (($x37 (= ?x9 0.0)))
 (= $x37 false))))
(assert
 (let ((?x9 (* cond1___instr_symb_num_0 10.0)))
 (let (($x11 (= ?x9 100.0)))
 (not $x11))))
(assert
 (let ((?x9 (* cond1___instr_symb_num_0 10.0)))
 (< ?x9 100.0)))
(check-sat)
