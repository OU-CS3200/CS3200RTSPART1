(************************************************************************
   RTS-3, Part A2 — The search bot (30 pts)

   At each consultation:
     1. fork the game you are shown;
     2. for every plan in [Policies.candidates], roll the fork forward
        [ticks] ticks, you playing that plan and the opponent playing
        [model] (your guess at what they will do);
     3. score each result with your RTS-1 [Eval.eval], from YOUR side;
     4. return the orders the best plan gives NOW.

   This is only safe because of RTS-2: a fork is the real game, shared, and
   nothing any rollout does can reach back into it.

   Two things to get right:
   - Which player are you? A view does not say directly. Your own units do.
   - [rollout] takes player 0's bot first. When you are player 1, the plan
     goes second.

   With [~cache:true], use [Memo.rollout_chunks] with one Hashtbl per bot
   (create it in [make], before [fun v ->]), so the cache lives across
   consultations. With [~cache:false], use the engine's [rollout].
 ************************************************************************)

open Rtsarena
[@@@warning "-26-27-32"]

(** Which player the view belongs to. Given. *)
let me_of (v : view) : int = match v.my_units with e :: _ -> e.player | [] -> 0

let make ?(ticks : int = 100) ?(model : bot = Bot.my_bot) ?(cache : bool = true) () : bot =
  fun (v : view) -> Bot.my_bot v

(** Your tournament entry, and what [my-search] plays in the runner. Change
    its arguments if you want different settings. *)
let bot : bot = make ()
