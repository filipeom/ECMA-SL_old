(declare-fun obj____conds____cond1___instr_symb_num_0 real)
(assert (bool.not (real.eq (real.mul obj____conds____cond1___instr_symb_num_0 10.) 100.)))
(assert (real.lt (real.mul obj____conds____cond1___instr_symb_num_0 10.) 100.))
(assert (bool.eq (real.eq (real.mul obj____conds____cond1___instr_symb_num_0 10.) 0.) false))
(check-sat)