Require Import util list_util.
Require Import geometry.
Require Import monotonic_flow.
Require Import hs_solver.
Require decreasing_exponential_flow.
Require abstract abstraction square_abstraction abstract_as_graph.
Require EquivDec.

Require Import thermostat.conc.
Module conc_thermo := thermostat.conc.

Set Implicit Arguments.

Open Local Scope CR_scope.

Definition half_pos: CRpos ('(1#2)) := Qpos_CRpos (1#2).
Definition two_pos: CRpos ('2) := positive_CRpos 2.

Definition above (c: CR): OpenRange := exist OCRle (Some c, None) I.
Definition below (c: CR): OpenRange := exist OCRle (None, Some c) I.

(* Flow inverses *)

Definition clock_flow_inv (l: Location) (a b: OpenRange): OpenRange :=
  square_flow_conditions.one_axis.flow_range
    _ flow.positive_linear.inv_correct flow.positive_linear.mono a b.

Definition temp_flow_inv (l: Location): OpenRange -> OpenRange -> OpenRange :=
  match l with
  | Heat => flow.scale.inv two_pos (square_flow_conditions.one_axis.flow_range
    _ flow.positive_linear.inv_correct flow.positive_linear.mono)
  | Cool => dec_exp_flow.inv milli
  | Check => flow.scale.inv half_pos (dec_exp_flow.inv milli)
  end.

Lemma clock_rfis l: range_flow_inv_spec (clock_flow l) (clock_flow_inv l).
Proof with auto.
  intro.
  unfold range_flow_inv_spec. intros.
  apply square_flow_conditions.one_axis.flow_range_covers with p...
Qed.

Lemma temp_rfis l: range_flow_inv_spec (temp_flow l) (temp_flow_inv l).
Proof with auto.
  destruct l; simpl temp_flow.
      unfold temp_flow_inv.
      apply flow.scale.inv_correct.
      unfold range_flow_inv_spec. intros.
      apply square_flow_conditions.one_axis.flow_range_covers with p...
    apply dec_exp_flow.inv_correct.
  apply flow.scale.inv_correct, dec_exp_flow.inv_correct.
Qed.

(* Abstract regions: *)

Inductive ClockInterval: Set := CI0_C | CIC_12 | CI12_1 | CI1_2 | CI2_3 | CI3_.
Inductive TempInterval: Set := TI_5 | TI5_6 | TI6_8 | TI8_9 | TI9_10 | TI10_.

Program Definition ClockInterval_qbounds (i: ClockInterval): OpenQRange :=
  (match i with
  | CI0_C => (0, centi): QRange
  | CIC_12 => (centi, 1#2): QRange
  | CI12_1 => (1#2, 1+centi): QRange
  | CI1_2 => (1+centi, 2-centi): QRange
  | CI2_3 => (2-centi, 3): QRange
  | CI3_ => (Some 3, None)
  end)%Q.

Definition ClockInterval_bounds (i: ClockInterval): OpenRange := ClockInterval_qbounds i.

Program Definition TempInterval_qbounds (i: TempInterval): OpenQRange :=
  (match i with
  | TI_5 => (None, Some (5-centi))
  | TI5_6 => (5-centi, 6): QRange
  | TI6_8 => (6, 8): QRange
  | TI8_9 => (8, 9-deci): QRange
  | TI9_10 => (9-deci, 10): QRange
  | TI10_ => (Some 10, None)
  end)%Q.

Definition TempInterval_bounds (i: TempInterval): OpenRange :=
  TempInterval_qbounds i.

Instance clock_intervals: ExhaustiveList ClockInterval
  := { exhaustive_list := CI0_C :: CIC_12 :: CI12_1 :: CI1_2 :: CI2_3 :: CI3_ :: nil }.
Proof. hs_solver. Defined.

Instance temp_intervals: ExhaustiveList TempInterval
  := { exhaustive_list := TI_5 :: TI5_6 :: TI6_8 :: TI8_9 :: TI9_10 :: TI10_ :: nil }.
Proof. hs_solver. Defined.

Program Definition s_absClockInterval (r: CR):
    { i | '0 <= r -> in_orange (ClockInterval_bounds i) r } :=
  if CR_le_le_dec r ('centi) then CI0_C else
  if CR_le_le_dec r ('(1#2)) then CIC_12 else
  if CR_le_le_dec r ('(1+centi)) then CI12_1 else
  if CR_le_le_dec r ('(2-centi)) then CI1_2 else
  if CR_le_le_dec r ('3) then CI2_3 else CI3_.

Program Definition s_absTempInterval (r: CR):
    { i | in_orange (TempInterval_bounds i) r } :=
  if CR_le_le_dec r ('(5-centi)) then TI_5 else
  if CR_le_le_dec r ('6) then TI5_6 else
  if CR_le_le_dec r ('8) then TI6_8 else
  if CR_le_le_dec r ('(9-deci)) then TI8_9 else
  if CR_le_le_dec r ('10) then TI9_10 else TI10_.

Program Definition absClockInterval (r: CR): ClockInterval := s_absClockInterval r.
Program Definition absTempInterval (r: CR): TempInterval := s_absTempInterval r.

Lemma absClockInterval_wd (r r': CR): st_eq r r' -> absClockInterval r = absClockInterval r'.
Proof.
  unfold absClockInterval, s_absClockInterval. hs_solver.
Qed.

Lemma absTempInterval_wd (r r': CR): st_eq r r' -> absTempInterval r = absTempInterval r'.
Proof.
  unfold absTempInterval, s_absTempInterval. hs_solver.
Qed.

Instance ClockInterval_eq_dec: EquivDec.EqDec ClockInterval eq.
Proof. hs_solver. Defined.

Instance TempInterval_eq_dec: EquivDec.EqDec TempInterval eq.
Proof. hs_solver. Defined.

Lemma NoDup_clock_intervals: NoDup clock_intervals.
Proof. hs_solver. Qed.

Lemma NoDup_temp_intervals: NoDup temp_intervals.
Proof. hs_solver. Qed.

Lemma regions_cover_invariants l p:
  invariant (l, p) ->
  square_abstraction.in_region ClockInterval_bounds TempInterval_bounds p
    (square_abstraction.absInterval absClockInterval absTempInterval p).
Proof with auto.
  destruct p.
  unfold invariant.
  unfold square_abstraction.in_region, square_abstraction.absInterval,
    absClockInterval, absTempInterval.
  simplify_hyps. simplify_proj. split...
Qed.

Definition Region: Set := prod ClockInterval TempInterval.

Let in_region := square_abstraction.in_region ClockInterval_bounds TempInterval_bounds.

Definition in_region_wd: forall (x x': concrete.Point conc_thermo.system),
  x[=]x' -> forall r, in_region x r -> in_region x' r
  := @square_abstraction.in_region_wd _ _ Location
    _ _ _ _ _ _ ClockInterval_bounds TempInterval_bounds.

(* Abstracted initial: *)

Program Definition initial_square: OpenSquare := (('0, '0), ('5, '10)): Square.
Definition initial_location := Heat.

Definition initial_dec eps: Location * Region -> bool :=
  square_abstraction.initial_dec (Location:=Location)
    ClockInterval_bounds TempInterval_bounds
    initial_location initial_square eps.

Lemma over_initial eps: initial_dec eps >=>
  abstraction.initial_condition conc_thermo.system
  (square_abstraction.in_region ClockInterval_bounds TempInterval_bounds).
Proof.
  apply square_abstraction.over_initial.
  intros [a b] [A [B [C D]]].
  unfold in_osquare, in_orange.
  simpl. rewrite D. auto.
Qed.

(* Abstracted invariant: *)

Program Definition invariant_squares (l: Location): OpenSquare :=
  match l with
  | Cool => (above ('0), above ('5))
  | Heat => (('0, '3): Range, below ('10))
  | Check => (('0, '1): Range, unbounded_range)
  end.

Lemma invariant_squares_correct (l : Location) (p : Point):
  invariant (l, p) -> in_osquare p (invariant_squares l).
Proof.
  unfold invariant. grind ltac:(destruct l).
Qed.

(* Abstracted guard: *)

Definition guard_square (l l': Location): option OpenSquare :=
  match l, l' with
  | Heat, Cool => Some (unbounded_range, above ('9))
  | Cool, Heat => Some (unbounded_range, below ('6))
  | Heat, Check => Some (above ('2), unbounded_range)
  | Check, Heat => Some (above ('(1#2)), unbounded_range)
  | _, _ => None
  end.

Lemma guard_squares_correct: forall s l',
  guard s l' <->
  match guard_square (loc s) l' with
  | None => False
  | Some v => in_osquare (point s) v
  end.
Proof.
  destruct s as [l [x y]].
  destruct l; destruct l'; repeat split; simpl; auto; intros [[A B] [C D]]; auto.
Qed.

Definition guard_dec eps (ls : Location * Region * Location) :=
  let (lr, l2) := ls in
  let (l1, r) := lr in
    match guard_square l1 l2 with
    | Some s => osquares_overlap_dec eps
      (s, square_abstraction.square ClockInterval_bounds TempInterval_bounds r)
    | None => false
    end.

Lemma over_guard eps :
  guard_dec eps >=> square_abstraction.abstract_guard ClockInterval_bounds TempInterval_bounds guard.
Proof with auto.
  intros eps [[l r] l'] gf [p [in_p g]].
  unfold guard_dec in gf.
  pose proof (fst (guard_squares_correct _ _) g).
  clear g. rename H into g. simpl in g.
  simpl @fst in *. simpl @snd in *.  
  destruct (guard_square l l'); try contradiction.
  apply (over_osquares_overlap eps gf).
  apply osquares_share_point with p...
Qed.

(* Hints: *)

Hint Immediate positive_CRpos.
Hint Resolve CRpos_nonNeg.


Definition he (f: Flow CRasCSetoid) (flow_inc: forall x, strongly_increasing (f x)) (t: Time) (x b: CR):
  b <= x -> f x t <= b -> t <= '0.
Proof with auto.
  intros.
  apply (@strongly_increasing_inv_mild (f x) (flow_inc x))...
  rewrite (flow_zero f).
  apply CRle_trans with b...
Qed.

Lemma heat_temp_flow_inc: (forall x : CRasCSetoid, strongly_increasing (temp_flow Heat x)).
  repeat intro.
  simpl.
  unfold scale.raw.
  unfold positive_linear.f.
  simpl.
  apply CRlt_wd with (' 2 * x0 + x) (' 2 * x' + x).
      apply (Radd_comm CR_ring_theory).
    apply (Radd_comm CR_ring_theory).
  apply t1.
  apply (CRmult_lt_pos_r H).
  apply (Qpos_CRpos (2#1)%Qpos).
Qed.

Lemma clock_flow_inc: forall l x, strongly_increasing (clock_flow l x).
Proof with auto.
  intros.
  unfold clock_flow.
  repeat intro.
  simpl.
  apply CRlt_wd with (x0 + x) (x' + x).
      apply (Radd_comm CR_ring_theory).
    apply (Radd_comm CR_ring_theory).
  apply t1.
  assumption.
Qed.

Definition clock_hints (l: Location) (r r': Region): r <> r' -> option
  (abstraction.AltHint conc_thermo.system in_region l r r').
Proof with auto.
  intros.
  unfold abstraction.AltHint, in_region, square_abstraction.in_region,
    square_abstraction.square, in_osquare.
  simpl.
  destruct r. destruct r'.
  unfold in_orange at 1 3.
  unfold ClockInterval_bounds.
  simpl.
  destruct (ClockInterval_qbounds c).
  destruct (ClockInterval_qbounds c0).
  destruct x. destruct x0.
  destruct o1. destruct o4.
      simpl.
      destruct (Qeq_dec q q0).
        constructor.
        intros.
        destruct H0. destruct H1. destruct H0. destruct H1.
        apply (@he (clock_flow l) ) with (fst p) ('q)...
          apply clock_flow_inc.
        simpl.
        rewrite q1...
      exact None.
    exact None.
  exact None.
Defined.

Definition temp_hints (l: Location) (r r': Region): r <> r' -> option
  (abstraction.AltHint conc_thermo.system in_region l r r').
Proof with auto.
  intros.
  destruct r. destruct r'.
  destruct l.
      unfold abstraction.AltHint, in_region, square_abstraction.in_region,
        square_abstraction.square, in_osquare.
      simpl.
      unfold in_orange at 2 4.
      unfold orange_right at 1. unfold orange_left at 2.
      unfold TempInterval_bounds.
      destruct (TempInterval_qbounds t).
      destruct (TempInterval_qbounds t0).
      destruct x.
      destruct x0.
      destruct o1.
        destruct o4.
          simpl.
          destruct (Qeq_dec q q0).
            constructor.
            intros.
            destruct H0. destruct H1.
            destruct H2. destruct H3.
            apply (@he (temp_flow Heat) heat_temp_flow_inc t1 (snd p) ('q) H2).
            rewrite q1...
          exact None.
        exact None.
      exact None.
    exact None.
  exact None.
Defined.

Definition hints (l: Location) (r r': Region) (E: r <> r') :=
  options (clock_hints l E) (temp_hints l E).

(* The abstract system: *)

Definition system (eps: Qpos): abstract.System conc_thermo.system.
Proof with auto.
  intro eps.
  eapply (@abstraction.abstract_system' _ _ _ conc_thermo.system in_region
   in_region_wd
   (square_abstraction.NoDup_squareIntervals NoDup_clock_intervals NoDup_temp_intervals) _
   (fun x => @regions_cover_invariants (fst x) (snd x))
    (@square_abstraction.do_cont_trans _ _ _ _ _ _ _ _ _
    ClockInterval_bounds TempInterval_bounds clock_flow temp_flow
    clock_flow_inv temp_flow_inv clock_rfis temp_rfis _ _ _ _ _ _ invariant_squares_correct _ _ eps)
    (mk_DO (over_initial eps)) (abstraction.dealt_hints in_region_wd hints) regions_cover_invariants).
    apply (square_abstraction.NoDup_disc_trans
      NoDup_clock_intervals NoDup_temp_intervals
      (square_abstraction.do_invariant ClockInterval_bounds TempInterval_bounds _ _ invariant_squares_correct eps)
      NoDup_locations
      clock_reset temp_reset (mk_DO (over_guard eps)) eps).
  apply (@square_abstraction.respects_disc _ _ _ _ _ _ _ _ _ ClockInterval_bounds TempInterval_bounds absClockInterval absTempInterval clock_flow temp_flow)...
    unfold absClockInterval. intros.
    destruct (s_absClockInterval (fst p))... destruct H...
  unfold absTempInterval. intros.
  destruct (s_absTempInterval (snd p))...
Defined.