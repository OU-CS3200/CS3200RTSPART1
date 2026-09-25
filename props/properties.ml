(************************************************************************
   RTS-2, Part C — Properties (20 pts)

   Five QCheck properties of the engine. Each one takes a [Gen.recipe],
   builds the game with [Gen.game_of], and returns [true] when the engine
   behaves. Compare positions with [Gen.snapshot].

   How this is graded: we run YOUR properties against three engines, each
   with a different bug planted in it. A property suite that is any good
   fails on a buggy engine. You get the points if your suite catches at
   least two of the three (and passes on a correct engine). You do not get
   to see the buggy engines — that is the point. Think about what could go
   wrong, and check for it.

   Run:  dune test props
 ************************************************************************)

[@@@warning "-26-27-32-33"]
open Rtsarena

let count = 200

(** 1. (4 pts) Determinism: stepping the same game twice gives the same
    position and the same events. *)
let deterministic =
  QCheck.Test.make ~count ~name:"step is deterministic" Gen.recipe (fun r ->
      let g = Gen.game_of r in
      failwith "todo")

(** 2. (4 pts) Purity: stepping a game, or simulating a fork of it, does not
    change it. Take a snapshot before and after. *)
let pure =
  QCheck.Test.make ~count ~name:"step and rollout leave their argument alone" Gen.recipe
    (fun r ->
       let g = Gen.game_of r in
       failwith "todo")

(** 3. (4 pts) Conservation, over one tick. Resources are never created or
    destroyed, only moved:
      - what left the map this tick is what workers picked up
        ([Harvested] events, one each);
      - on a tick where no worker died, what workers picked up either went
        into a stockpile ([Deposited]) or is still being carried (a worker
        that dies still acts first, so on those ticks you cannot see what it
        was carrying when it went — skip this check then);
      - each stockpile grew by exactly what was deposited for that player
        (spending happens in [apply_orders], never inside [step]).
    Hint: [resource_left]; and a worker of [g] missing from [g'] died. *)
let conserved =
  QCheck.Test.make ~count ~name:"resources are conserved" Gen.recipe (fun r ->
      let g = Gen.game_of r in
      failwith "todo")

(** 4. (4 pts) Legal positions: every entity is on the board, no unit
    stands on a wall, and no two entities share a cell. Check the game the
    recipe gives you and the one after it. *)
let legal =
  QCheck.Test.make ~count ~name:"every position is legal" Gen.recipe (fun r ->
      let g = Gen.game_of r in
      failwith "todo")

(** 5. (4 pts) One of your own. Name it, say in RTS2.md what it catches that
    the four above do not, and make it pass. *)
let mine =
  QCheck.Test.make ~count
    ~name:
      "TODO: name your property"
    Gen.recipe (fun r ->
      let g = Gen.game_of r in
      failwith "todo")

let all = [ deterministic; pure; conserved; legal; mine ]
