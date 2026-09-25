(** Random games, for property testing. Given — read it, do not change it.

    A random game is built by playing: a random map, two random built-in
    bots, and a random number of ticks. So every game it produces is one
    the engine could really reach, which is what a property should be
    checked on. *)

open Rtsarena

let presets = [ "default"; "rich"; "sparse"; "corridors" ]

(** Everything needed to rebuild the game, so a failure can be replayed. *)
type recipe = { preset : string; p0 : string; p1 : string; seed : int; ticks : int }

let bot_of name seed = if name = "random" then random_bot seed else Option.get (bot_named name)

let game_of r =
  rollout (make_game ~preset:r.preset ()) (bot_of r.p0 r.seed) (bot_of r.p1 (r.seed + 1))
    ~ticks:r.ticks

let print_recipe r =
  Printf.sprintf "{preset=%s; p0=%s; p1=%s; seed=%d; ticks=%d}" r.preset r.p0 r.p1 r.seed r.ticks

let recipe_gen : recipe QCheck.Gen.t =
  let open QCheck.Gen in
  let* preset = oneofl presets in
  let* p0 = oneofl (bot_names ()) in
  let* p1 = oneofl (bot_names ()) in
  let* seed = int_bound 10_000 in
  let* ticks = int_range 0 300 in
  return { preset; p0; p1; seed; ticks }

(** Use this in [QCheck.Test.make]: each value is a recipe; call [game_of]
    on it to get the game. Failures print the recipe, so you can replay the
    exact game in utop. *)
let recipe : recipe QCheck.arbitrary = QCheck.make ~print:print_recipe recipe_gen

(** A position you can compare: every entity (sorted by id), the stockpiles,
    the turn, and the board. Two games with the same [snapshot] are the same
    game as far as anyone outside the engine can tell. *)
let snapshot g =
  ( List.sort compare (entities g),
    (resources_of g 0, resources_of g 1),
    turn g,
    to_ascii g 0 )
