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

(** Your tournament entry, and what [my-search] plays in the runner. Change
    its arguments if you want different settings. *)
(* guess the enemy's style from the army we can see *)
let guess_model (v : view) : bot =
  let n (u : unit_type) : int =
    List.length (List.filter (fun (e : entity) -> e.kind = U u) v.enemy_units) in
  let l = n Light and h = n Heavy and r = n Ranged in
  if l + h + r = 0 then Bot.my_bot
  else if l >= h && l >= r then Policies.light_flood
  else if h >= r then Policies.heavy_turtle
  else Policies.ranged_line

let make_pro ?(ticks : int = 100) ?(budget : float = 0.4) ?(margin : float = 1.0) () : bot =
  let tbl : (string, game) Hashtbl.t = Hashtbl.create 8192 in
  let last : string ref = ref "my-bot" in
  let basic = make ~ticks () in
  fun (v : view) ->
    try
      if Hashtbl.length tbl > 20000 then Hashtbl.reset tbl;
      let t0 = Sys.time () in
      let me = me_of v in
      let g = fork v in
      let guess = guess_model v in
      let models = if guess == Bot.my_bot then [ Bot.my_bot ] else [ guess; Bot.my_bot ] in
      let score_vs (model : bot) (plan : bot) : float =
        let p0, p1 = if me = 0 then (plan, model) else (model, plan) in
        let f = Memo.rollout_chunks ~cache:tbl ~interval:20 g p0 p1 ~ticks in
        if is_over f then
          (if winner f = me then 1e6 -. float_of_int (turn f) else -1e6)
        else Eval.eval (view f me) in
      let score ((name, plan) : string * bot) : float =
        let s = List.fold_left (fun acc m -> Float.min acc (score_vs m plan)) infinity models in
        if name = !last then s +. margin else s in
      let best : (float * string * bot) option ref = ref None in
      List.iter
        (fun ((name, plan) : string * bot) ->
          let first = (match !best with None -> true | Some _ -> false) in
          if first || Sys.time () -. t0 < budget then begin
            let s = score (name, plan) in
            match !best with
            | Some (bs, _, _) when bs >= s -> ()
            | _ -> best := Some (s, name, plan)
          end)
        Policies.pro_candidates;
      (match !best with
       | Some (_, name, plan) -> last := name; plan v
       | None -> Bot.my_bot v)
    with _ -> basic v

let bot : bot = make_pro ()