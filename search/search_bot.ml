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

(** YOUR CODE GOES HERE: Part A2 is the body of [make].

    [make] builds a search bot from its settings and returns it:
    - [ticks]: how far each rollout runs;
    - [model]: the bot you assume the opponent plays;
    - [cache]: [true] uses [Memo.rollout_chunks], [false] the engine's [rollout].
    Use all three; do not hard-code them. The tests, [bin/bench.ml] and the
    runner call [make] with different settings, and Part A is graded on
    [make ()], the defaults.

    Anything before [fun (v : view) ->] runs once per bot (create the cache
    there); the function itself runs once per consultation (the search).
    The stub ignores its arguments and plays your RTS-1 bot. *)
let make ?(ticks : int = 100) ?(model : bot = Bot.my_bot) ?(cache : bool = true) () : bot =
  fun (v : view) -> Bot.my_bot v

(** Your tournament entry, and what [my-search] plays in the runner. Change
    its arguments if you want different settings. *)
let bot : bot = make ()
let make ?(ticks : int = 100) ?(model : bot = Bot.my_bot) ?(cache : bool = true) () : bot =
  let tbl : (string, game) Hashtbl.t = Hashtbl.create 4096 in
  fun (v : view) ->
    let me = me_of v in
    let g = fork v in
    let score (plan : bot) : float =
      let p0, p1 = if me = 0 then (plan, model) else (model, plan) in
      let final =
        if cache then Memo.rollout_chunks ~cache:tbl ~interval:20 g p0 p1 ~ticks
        else rollout g p0 p1 ~ticks in
      if is_over final then (if winner final = me then 1e6 else -1e6)
      else Eval.eval (view final me) in
    let best =
      Policies.candidates
      |> List.map (fun (_, plan) -> (score plan, plan))
      |> List.fold_left
           (fun acc (s, plan) ->
             match acc with
             | Some (bs, _) when bs >= s -> acc
             | _ -> Some (s, plan))
           None in
    match best with Some (_, plan) -> plan v | None -> Bot.my_bot v
