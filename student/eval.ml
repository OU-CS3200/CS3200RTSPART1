(************************************************************************
   RTS-1, Part B — An evaluation function (20 pts)

   [eval v] answers "how well am I doing?" as one number: positive means
   winning, negative means losing, 0.0 means even. RTS-3 will call it
   thousands of times to compare futures, so it has to mean something.

   Same rules as queries.ml: no rec, no List.length (comments are skipped).

   Build it in three steps:
     1. [side] measures ONE side: a record of plain numbers.
     2. [features] is my side minus their side, field by field.
     3. [eval] is the weighted sum of those differences.

   Built that way, eval is antisymmetric for free: whatever the position,
   what player 0 sees is exactly the negative of what player 1 sees. The
   tests check that on positions from real games.
 ************************************************************************)

open Rtsarena
open Util

(** What we measure about one side. Keep these fields; you may add more,
    but then add a matching weight below. *)
type side = {
  army : float;       (** total cost of combat units *)
  economy : float;    (** resources in the stockpile, plus what workers carry *)
  workers : float;    (** number of workers *)
  hp : float;         (** total hit points of everything *)
  base : float;       (** 1.0 if the base is standing, 0.0 if not *)
  barracks : float;   (** 1.0 if at least one barracks is standing *)
}

(** One weight per field of [side]. *)
type weights = {
  w_army : float;
  w_economy : float;
  w_workers : float;
  w_hp : float;
  w_base : float;
  w_barracks : float;
}

(** 1. (6 pts) [side units resources] measures one side, given all of its
    entities and its stockpile. Use [Queries.is_combat]. *)
let side (units : entity list) (resources : int) : side =
  todo (units, resources)

(** 2. (6 pts) [features v] is (my side) minus (their side), field by field.
    Your units are [v.my_units] with [v.my_resources]; theirs are
    [v.enemy_units] with [v.enemy_resources]. *)
let features (v : view) : side =
  todo v

(** 3. (4 pts) Your weights. The ones given here are a starting point that
    predicts some games; tune them. Say in README.md what you changed and
    why. *)
let weights : weights =
  { w_army = 1.0; w_economy = 1.0; w_workers = 1.0; w_hp = 1.0;
    w_base = 1.0; w_barracks = 1.0 }

(** 4. (4 pts) [eval_with w v] is the weighted sum of [features v]. *)
let eval_with (w : weights) (v : view) : float =
  todo (w, v)

(** Given. *)
let eval (v : view) : float = eval_with weights v
