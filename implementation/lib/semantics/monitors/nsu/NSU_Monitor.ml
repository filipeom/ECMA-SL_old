(*Each monitor is independent of the other ones*)
exception Except of string

type monitor_state_t =  SecCallStack.t * SecHeap.t * SecStore.t * SecLevel.t list

type monitor_return = | MReturn of monitor_state_t
                      | MFail of ( monitor_state_t * string)


let print_pc (pc : SecLevel.t list) =
  print_string "[ M - STACK ]";
  let aux= List.rev pc in
  print_string ((String.concat ":: " (List.map SecLevel.str aux))^"\n")

let add_pc (pc : SecLevel.t list) (lvl : SecLevel.t) : SecLevel.t list=
  let aux= List.rev pc in
  let pc'=  [lvl] @ aux in
  List.rev pc'

let pop_pc (pc : SecLevel.t list) : SecLevel.t list =
  let pc'= List.rev pc in
  match pc' with
  |[] -> raise(Except "PC list is empty!")
  |l::ls'-> List.rev ls'

let check_pc (pc : SecLevel.t list) : SecLevel.t =
  let pc'= List.rev pc in
  match pc' with
  | s::ss'-> s
  | _ -> raise(Except "PC list is empty!")

let rec expr_lvl (ssto:SecStore.t) (exp:Expr.t) : SecLevel.t =
  (*Criar lub entre lista de variaveis*)
  let vars = Expr.vars exp in
  List.fold_left  (SecLevel.lub) SecLevel.Low  (List.map (SecStore.get ssto) vars)


let rec eval_small_step (m_state: monitor_state_t) (tl:SecLabel.t) : monitor_return =

  let (scs, sheap, ssto, pc)= m_state in

             (*
            No-Sensitive-Upgrade
            *)

  match tl with
  | EmptyLab ->
    MReturn (scs,sheap,ssto,pc)

  | MergeLab ->
    let pc' = pop_pc pc in
    MReturn (scs,sheap, ssto,pc')

  | ReturnLab e ->
    print_string "[M]returnLab\n";
    let lvl = expr_lvl ssto e in
    Printf.printf "[M]Level e: %s\n" (SecLevel.str lvl) ;
    let lvl_f = SecLevel.lub lvl (check_pc pc) in
    let (frame, scs') = SecCallStack.pop scs in
    print_string "[M]Pop\n";
    (match frame with
     | Intermediate (pc',ssto', x) ->  eval_small_step (scs', sheap, ssto', pc') (SecLabel.UpgVarLab (x,lvl_f))
     | Toplevel -> MReturn (scs', sheap, ssto, pc))

  | UpgVarLab (x,lev)->
    print_string "[M]VarLab\n";
    let pc_lvl= check_pc pc in
    print_string "[M]VarLab1\n";
    (match SecStore.get_safe ssto x with
     | Some x_lvl ->
       print_string "[M]VarLab2\n";
       if (SecLevel.leq x_lvl pc_lvl) then (
         SecStore.set ssto x (SecLevel.lub lev pc_lvl);
         MReturn (scs, sheap, ssto, pc)
       ) else MFail ((scs, sheap, ssto, pc), ("NSU Violation - UpgVarLab: " ^ x ^ " " ^ (SecLevel.str lev)))
     | None ->
       SecStore.set ssto x pc_lvl;
       MReturn (scs, sheap, ssto, pc))

  | AssignLab (var, exp)->
    let lvl=expr_lvl ssto exp in
    let pc_lvl= check_pc pc in
    (try (let var_lvl = Hashtbl.find ssto var in
          if (SecLevel.leq var_lvl pc_lvl) then(
            print_string (SecLevel.str lvl);
            SecStore.set ssto var (SecLevel.lub lvl  pc_lvl);
            MReturn (scs, sheap, ssto, pc))

          else (raise(Except "MONITOR BLOCK - Invalid Assignment "))
         )
     with Not_found -> 	SecStore.set ssto var (SecLevel.lub lvl  pc_lvl);
       eval_small_step (scs, sheap, ssto, pc) (SecLabel.AssignLab (var,exp))
    )

  (*| OutLab (lev,exp) ->
    let lvl_pc= check_pc pc in
    let lvl_exp = expr_lvl ssto exp in
    if (Level.leq (Level.lub lvl_exp lvl_pc) lev) then
    MReturn (scs, sheap, ssto, pc)
    else
    MFail (scs, sheap, ssto, pc, ("NSU Violation - OutLab: " ^ (SecLevel.str lev) ^ " " ^ (Expr.str exp)))
  *)
  | BranchLab (exp,st) ->
    let lev= expr_lvl ssto exp in
    let pc_lvl = check_pc pc in
    let pc' = add_pc pc (SecLevel.lub lev pc_lvl) in
    MReturn (scs, sheap, ssto, pc')

  | AssignCallLab (params, exp,x,f)->
    let scs'=SecCallStack.push scs (SecCallStack.Intermediate (pc,ssto,x)) in
    let lvls = List.map (expr_lvl ssto) exp in
    let pvs = List.combine params lvls in
    let ssto_aux = SecStore.create pvs in
    MReturn (scs', sheap, ssto_aux, [check_pc pc])

  | UpgStructValLab (loc, e_o, lvl) -> (*UpgObjLab <- mudar*)
    (*Need to add NSU conditions*)
    let lev_o = expr_lvl ssto e_o in
    let lev_ctx = SecLevel.lubn [lev_o;(check_pc pc)] in
    (match SecHeap.get_val sheap loc with
     | Some lev ->
       if SecLevel.leq lev_ctx lev then (
         SecHeap.upg_struct_val sheap loc (SecLevel.lub lvl lev_ctx);
         MReturn (scs, sheap, ssto, pc))
       else
         MFail((scs,sheap,ssto,pc), "Illegal P_Val Upgrade")
     | None -> raise (Except "Internal Error"))


  | UpgStructExistsLab (loc, e_o, lvl) ->
    (*Need to add NSU conditions*)
    let lev_o = expr_lvl ssto e_o in
    let lev_ctx = SecLevel.lubn [lev_o;(check_pc pc)] in
    (match SecHeap.get_struct sheap loc with
     | Some lev ->
       if SecLevel.leq lev_ctx lev then (
         SecHeap.upg_struct_exists sheap loc (SecLevel.lub lvl lev_ctx);
         MReturn (scs, sheap, ssto, pc))
       else
         MFail((scs,sheap,ssto,pc), "Illegal P_Val Upgrade")
     | None -> raise (Except "Internal Error"))



  | UpgPropValLab (loc, field, e_o, e_f,  lvl) ->
    let lev_o = expr_lvl ssto e_o in
    let lev_f = expr_lvl ssto e_f in
    let lev_ctx = SecLevel.lubn [lev_o ;lev_f;(check_pc pc)] in
    (match SecHeap.get_field sheap loc field with
     | Some (_, lev_val) ->
       if SecLevel.leq lev_ctx lev_val then (
         SecHeap.upg_prop_val sheap loc field (SecLevel.lub lvl lev_ctx);
         MReturn (scs, sheap, ssto, pc))
       else MFail((scs,sheap,ssto,pc), "Illegal P_Val Upgrade")
     | None -> raise (Except "Internal Error"))


  | UpgPropExistsLab (loc,field, e_o, e_f, lvl) ->
    let lev_o = expr_lvl ssto e_o in
    let lev_f = expr_lvl ssto e_f in
    let lev_ctx = SecLevel.lubn [lev_o ;lev_f;(check_pc pc)] in
    (match SecHeap.get_field sheap loc field with
       Some (lev_exists, _) ->
       if SecLevel.leq lev_ctx lev_exists then (
         SecHeap.upg_prop_exists sheap loc field (SecLevel.lub lvl lev_ctx);
         MReturn (scs, sheap, ssto, pc))
       else MFail((scs,sheap,ssto,pc), "Illegal P_Existis Upgrade")
     |None -> raise (Except "Internal Error"))

  | FieldLookupLab (x,loc,field, e_o, e_f) ->
    let lev_o = expr_lvl ssto e_o in
    let lev_f = expr_lvl ssto e_f in
    let lev_ctx = SecLevel.lubn [lev_o ;lev_f;(check_pc pc)] in
    let lev_x = SecStore.get ssto x in
    if (SecLevel.leq lev_ctx lev_x) then (
      match  SecHeap.get_field sheap loc field with
      | Some (_, lev_fv) ->
        let lub = SecLevel.lub lev_ctx lev_fv  in
        SecStore.set ssto x lub;
        MReturn (scs,sheap,ssto,pc)
      | None -> raise (Except "Internal Error"))
    else
      MFail((scs,sheap,ssto,pc), "Illegal Field Lookup")

  | FieldDeleteLab (loc, field, e_o, e_f) ->
    let lev_o = expr_lvl ssto e_o in
    let lev_f = expr_lvl ssto e_f in
    let lev_ctx = SecLevel.lubn [lev_o ;lev_f;(check_pc pc)] in
    (match SecHeap.get_field sheap loc field with
     | Some (lev_ef , _) ->
       if (SecLevel.leq lev_ctx lev_ef) then (
         if SecHeap.delete_field sheap loc field then
           MReturn (scs,sheap,ssto,pc)
         else raise (Except "Internal Error"))
       else MFail((scs,sheap,ssto,pc), "Illegal Field Delete")
     | None -> raise (Except "Internal Error"))

  | FieldAssignLab ( loc, field, e_o, e_f, exp) ->
    let lev_o = expr_lvl ssto e_o in
    let lev_f = expr_lvl ssto e_f in
    let lev_ctx = SecLevel.lubn [lev_o; lev_f; (check_pc pc)] in
    let lev_exp = expr_lvl ssto exp in
    (match SecHeap.get_field sheap loc field with
     | Some (lev_ef,lev_fv) ->
       if (SecLevel.leq lev_ctx lev_fv) then (
         SecHeap.upg_prop_val sheap loc field (SecLevel.lub lev_exp lev_ctx);
         MReturn (scs,sheap,ssto,pc))
       else MFail((scs,sheap,ssto,pc), "Illegal Field Assign")

     | None ->
       let lev_struct = SecHeap.get_struct sheap loc in
       (match lev_struct with
        | Some lev_struct ->
          if (SecLevel.leq lev_ctx lev_struct) then (
            if SecHeap.new_sec_prop sheap loc field lev_ctx (SecLevel.lub lev_exp lev_ctx) then
              MReturn (scs, sheap, ssto, pc)
            else raise (Except "Internal Error"))
          else MFail((scs,sheap,ssto,pc), "Illegal Field Creation")
        | None -> raise (Except "Internal Error")))

let initial_monitor_state (): monitor_state_t =
  let sheap = SecHeap.create () in
  let ssto = SecStore.create [] in
  let scs = SecCallStack.create () in
  (scs, sheap, ssto, [SecLevel.Low])
