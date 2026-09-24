(* RTS-1 tests. Run with:  dune test
   To run one group:        dune exec test/test_rts1.exe -- test queries *)

open Alcotest
open Rtsarena
open Queries

(* ------------------------------------------------------------------ *)
(* Building positions by hand                                         *)
(* ------------------------------------------------------------------ *)

let blank = make_game ()

(** A game on the default map holding exactly [ents]. *)
let game_with ents = { blank with entities = ents }

let e id kind player x y = make_entity id kind player x y

let ids l = List.map (fun (x : entity) -> x.id) l

(* my base at (1,1), theirs at (14,14) *)
let my_base = e 1 (B Base) 0 1 1
let their_base = e 4 (B Base) 1 14 14

(* ------------------------------------------------------------------ *)
(* Part A — queries                                                   *)
(* ------------------------------------------------------------------ *)

let kind_t = testable (fun ppf k -> Fmt.string ppf (string_of_kind k)) ( = )

let test_count_by_kind () =
  (check (list (pair kind_t int))) "starting position"
    [ (U Worker, 2); (B Base, 1) ]
    (count_by_kind (view blank 0));
  let g = game_with [ my_base; e 2 (U Heavy) 0 3 3; e 3 (U Light) 0 4 4;
                      e 5 (U Heavy) 0 5 5; their_base; e 6 (U Heavy) 1 9 9 ] in
  (check (list (pair kind_t int))) "only my side, sorted by kind"
    [ (U Light, 1); (U Heavy, 2); (B Base, 1) ]
    (count_by_kind (view g 0));
  (check (list (pair kind_t int))) "nothing at all" []
    (count_by_kind (view (game_with [ their_base ]) 0))

let test_army_value () =
  (check int) "start: no army" 0 (army_value (view blank 0));
  let g = game_with [ my_base; e 2 (U Worker) 0 2 1; e 3 (U Light) 0 3 3;
                      e 5 (U Heavy) 0 4 4; e 7 (U Ranged) 0 5 5;
                      e 8 (B Barracks) 0 2 2; their_base; e 6 (U Heavy) 1 9 9 ] in
  (check int) "light 2 + heavy 3 + ranged 2" 7 (army_value (view g 0));
  (check int) "their side" 3 (army_value (view g 1))

let test_nearest_enemy () =
  let me = e 2 (U Light) 0 5 5 in
  let g = game_with [ my_base; me; their_base; e 6 (U Heavy) 1 9 9;
                      e 7 (U Worker) 1 5 8 ] in
  (check (option int)) "the worker at distance 3"
    (Some 7) (Option.map (fun x -> x.id) (nearest_enemy (view g 0) me));
  let tie = game_with [ my_base; me; their_base; e 9 (U Heavy) 1 5 7;
                        e 8 (U Light) 1 7 5 ] in
  (check (option int)) "tie at distance 2 goes to the smaller id"
    (Some 8) (Option.map (fun x -> x.id) (nearest_enemy (view tie 0) me));
  (check (option int)) "no enemies" None
    (Option.map (fun x -> x.id) (nearest_enemy (view (game_with [ my_base; me ]) 0) me))

let test_threats_near () =
  let g = game_with [ my_base; their_base;
                      e 6 (U Heavy) 1 4 4;     (* distance 6 *)
                      e 7 (U Light) 1 1 4;     (* distance 3 *)
                      e 8 (U Worker) 1 2 2;    (* a worker: not a threat *)
                      e 9 (U Ranged) 1 3 2;    (* distance 3, larger id *)
                      e 10 (U Light) 1 9 9 ]   (* too far *)
  in
  (check (list int)) "radius 6, nearest first, ties by id"
    [ 7; 9; 6 ] (ids (threats_near (view g 0) ~radius:6));
  (check (list int)) "radius is inclusive"
    [ 7; 9 ] (ids (threats_near (view g 0) ~radius:3));
  (check (list int)) "no base, no threats" []
    (ids (threats_near (view (game_with [ their_base; e 7 (U Light) 1 1 4 ]) 0) ~radius:6))

let test_idle_workers () =
  (check (list int)) "at the start both workers are idle"
    [ 2; 3 ] (ids (idle_workers (view blank 0)));
  let g = apply_orders blank 0 [ Harvest_with 1 ] in
  (check (list int)) "after assigning one to harvest"
    [ 3 ] (ids (idle_workers (view g 0)))

let test_income () =
  let evs = [ Deposited { player = 0; amount = 1 };
              Harvested { player = 0; x = 2; y = 2 };
              Deposited { player = 1; amount = 1 };
              Deposited { player = 0; amount = 2 } ] in
  (check int) "player 0" 3 (income evs ~player:0);
  (check int) "player 1" 1 (income evs ~player:1);
  (check int) "no events" 0 (income [] ~player:0)

(* ------------------------------------------------------------------ *)
(* Style: the rules of Parts A and B                                  *)
(* ------------------------------------------------------------------ *)

(** The source with comments and string literals blanked out. *)
let code_of path =
  let s = In_channel.with_open_text path In_channel.input_all in
  let b = Buffer.create (String.length s) in
  let n = String.length s in
  let rec go i depth in_str =
    if i >= n then ()
    else if in_str then
      if s.[i] = '\\' then (Buffer.add_string b "  "; go (i + 2) depth true)
      else if s.[i] = '"' then (Buffer.add_char b ' '; go (i + 1) depth false)
      else (Buffer.add_char b ' '; go (i + 1) depth true)
    else if i + 1 < n && s.[i] = '(' && s.[i + 1] = '*' then
      (Buffer.add_string b "  "; go (i + 2) (depth + 1) false)
    else if depth > 0 && i + 1 < n && s.[i] = '*' && s.[i + 1] = ')' then
      (Buffer.add_string b "  "; go (i + 2) (depth - 1) false)
    else if depth > 0 then (Buffer.add_char b ' '; go (i + 1) depth false)
    else if s.[i] = '"' then (Buffer.add_char b ' '; go (i + 1) depth true)
    else (Buffer.add_char b s.[i]; go (i + 1) depth false)
  in
  go 0 0 false;
  Buffer.contents b

let has_word code w =
  let is_id c = c = '_' || c = '\'' || c = '.'
                || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') in
  let n = String.length code and k = String.length w in
  let rec at i =
    i + k <= n
    && ((String.sub code i k = w
         && (i = 0 || not (is_id code.[i - 1]))
         && (i + k = n || not (is_id code.[i + k])))
        || at (i + 1))
  in
  at 0

let test_style file banned () =
  let code = code_of ("../student/" ^ file) in
  List.iter
    (fun w -> (check bool) (Printf.sprintf "%s does not use %s" file w) false (has_word code w))
    banned

(* ------------------------------------------------------------------ *)
(* Part B — eval                                                      *)
(* ------------------------------------------------------------------ *)

let fresh name = if name = "random" then random_bot 42 else Option.get (bot_named name)

(** Positions from real games: every 25 ticks of every built-in pairing. *)
let sample_positions =
  lazy
    (List.concat_map
       (fun a ->
          List.concat_map
            (fun b ->
               let acc = ref [] in
               ignore (play ~on_tick:(fun g _ -> if g.turn mod 25 = 0 then acc := g :: !acc)
                         (fresh a) (fresh b));
               !acc)
            [ "light-rush"; "turtle"; "economy-boom" ])
       [ "heavy-rush"; "balanced"; "worker-rush" ])

let test_eval_start () =
  (check (float 1e-9)) "an even start is 0.0" 0.0 (Eval.eval (view blank 0))

let test_eval_antisymmetric () =
  List.iter
    (fun g ->
       let a = Eval.eval (view g 0) and b = Eval.eval (view g 1) in
       if Float.abs (a +. b) > 1e-6 then
         failf "turn %d: player 0 sees %g, player 1 sees %g (should be negatives)"
           g.turn a b)
    (Lazy.force sample_positions)

let test_eval_monotone () =
  let base = Eval.eval (view blank 0) in
  let more = game_with (e 50 (U Heavy) 0 5 5 :: blank.entities) in
  (check bool) "an extra heavy of mine helps me" true (Eval.eval (view more 0) > base);
  let theirs = game_with (e 50 (U Heavy) 1 10 10 :: blank.entities) in
  (check bool) "an extra heavy of theirs hurts me" true (Eval.eval (view theirs 0) < base);
  let no_base = game_with (List.filter (fun x -> x.id <> 1) blank.entities) in
  (check bool) "losing my base hurts me" true (Eval.eval (view no_base 0) < base)

(* Does the sign of eval at turn [at] predict who wins? Over every decisive
   game of the built-in round robin. *)
let prediction_rate ~at =
  let names = bot_names () in
  let right = ref 0 and total = ref 0 in
  List.iter
    (fun a ->
       List.iter
         (fun b ->
            if a <> b then begin
              let snap = ref None in
              let r = play ~on_tick:(fun g _ -> if g.turn = at then snap := Some g)
                        (fresh a) (fresh b) in
              match !snap with
              | Some g when r.winner >= 0 ->
                incr total;
                let s = Eval.eval (view g 0) in
                if (s > 0.0 && r.winner = 0) || (s < 0.0 && r.winner = 1) then incr right
              | _ -> ()
            end)
         names)
    names;
  (!right, !total)

(** The bar: eval must call the winner of at least this share of the
    decisive games that reach turn 100. The starting weights get 77%. *)
let prediction_bar = 0.80

let test_eval_predicts () =
  let right, total = prediction_rate ~at:100 in
  let rate = float_of_int right /. float_of_int (max 1 total) in
  if rate < prediction_bar then
    failf "eval at turn 100 called %d of %d decisive games (%.0f%%); the bar is %.0f%%"
      right total (100.0 *. rate) (100.0 *. prediction_bar)

(* ------------------------------------------------------------------ *)
(* Part C — combinators                                               *)
(* ------------------------------------------------------------------ *)

let order_t = testable (fun ppf o -> Fmt.string ppf (string_of_order o)) ( = )
let v0 = view blank 0
let yes _ = true
let no _ = false

let test_combinators () =
  let open Rules in
  (check (option (list order_t))) "always" (Some [ Defend ]) (always [ Defend ] v0);
  (check (option (list order_t))) "when_ true" (Some [ Retreat ]) (when_ yes [ Retreat ] v0);
  (check (option (list order_t))) "when_ false" None (when_ no [ Retreat ] v0);
  (check (option (list order_t))) "guard true" (Some [ Defend ]) (guard yes (always [ Defend ]) v0);
  (check (option (list order_t))) "guard false" None (guard no (always [ Defend ]) v0);
  (check (option (list order_t))) "guard passes None through" None
    (guard yes (when_ no [ Defend ]) v0);
  (check (option (list order_t))) "first_of skips None"
    (Some [ Defend ])
    (first_of [ when_ no [ Retreat ]; always [ Defend ]; always [ Build_barracks ] ] v0);
  (check (option (list order_t))) "first_of []" None (first_of [] v0);
  (check (option (list order_t))) "all_of concatenates what fires, in order"
    (Some [ Harvest_with 3; Build_barracks ])
    (all_of [ always [ Harvest_with 3 ]; when_ no [ Retreat ]; always [ Build_barracks ] ] v0);
  (check (option (list order_t))) "all_of with nothing firing" None
    (all_of [ when_ no [ Retreat ] ] v0);
  (check (list order_t)) "to_bot falls back" default_orders (to_bot (when_ no [ Retreat ]) v0);
  (check (list order_t)) "to_bot uses the rule" [ Retreat ] (to_bot (always [ Retreat ]) v0)

(* ------------------------------------------------------------------ *)
(* Part C — the bot                                                   *)
(* ------------------------------------------------------------------ *)

(** Win on BOTH sides, 16x16 default map, 500 turns. A draw is not a win. *)
let beats name =
  let a = play Bot.my_bot (fresh name) in
  let b = play (fresh name) Bot.my_bot in
  (a.winner = 0, b.winner = 1)

let test_beats names () =
  List.iter
    (fun n ->
       let as0, as1 = beats n in
       if not (as0 && as1) then
         failf "against %s: %s as player 0, %s as player 1" n
           (if as0 then "won" else "did not win") (if as1 then "won" else "did not win"))
    names

let test_beats_two_rushes () =
  let won = List.filter (fun n -> beats n = (true, true))
      [ "light-rush"; "heavy-rush"; "ranged-rush" ] in
  if List.compare_length_with won 2 < 0 then
    failf "beat %d of the three rushes on both sides (%s); need 2"
      (List.length won) (String.concat ", " won)

let () =
  Printf.printf "\n----- NAME: %s   ID: %s -----\n%!" Bot.name Bot.id;
  run "RTS-1"
    [ ( "queries",
        [ test_case "count_by_kind" `Quick test_count_by_kind;
          test_case "army_value" `Quick test_army_value;
          test_case "nearest_enemy" `Quick test_nearest_enemy;
          test_case "threats_near" `Quick test_threats_near;
          test_case "idle_workers" `Quick test_idle_workers;
          test_case "income" `Quick test_income ] );
      ( "style",
        [ test_case "queries.ml: no rec, no List.length" `Quick
            (test_style "queries.ml" [ "rec"; "List.length" ]);
          test_case "eval.ml: no rec, no List.length" `Quick
            (test_style "eval.ml" [ "rec"; "List.length" ]);
          test_case "bot.ml: no if, no match" `Quick
            (test_style "bot.ml" [ "if"; "match" ]) ] );
      ( "eval",
        [ test_case "zero at an even start" `Quick test_eval_start;
          test_case "antisymmetric on real positions" `Quick test_eval_antisymmetric;
          test_case "more of mine is better" `Quick test_eval_monotone;
          test_case "predicts the winner from turn 100" `Slow test_eval_predicts ] );
      ( "combinators", [ test_case "all six" `Quick test_combinators ] );
      ( "bot",
        [ test_case "tier 1: worker-rush, random, turtle" `Slow
            (test_beats [ "worker-rush"; "random"; "turtle" ]);
          test_case "tier 2: economy-boom, balanced" `Slow
            (test_beats [ "economy-boom"; "balanced" ]);
          test_case "tier 3: two of the three rushes" `Slow test_beats_two_rushes ] ) ]
