(************************************************************************
   RTS-1, Part C1 — Rule combinators (15 pts)

   A bot is a function [view -> order list]. Writing one as a long chain of
   if/else gets unreadable fast, so instead we build bots out of small
   pieces called rules, and functions that combine rules.

   A [rule] looks at the board and either has an opinion (Some orders) or
   says "not my situation" (None).

   These are higher-order functions: most of them take functions and return
   a function. Keep each one short. Recursion IS allowed in this file, but
   none of them needs it.
 ************************************************************************)

open Rtsarena

type rule = view -> order list option

(** The orders [to_bot] falls back on when no rule fires. Given. *)
let default_orders : order list = [ Harvest_with 2; Defend ]

(** 1. (2 pts) [always orders] is a rule that always fires with [orders]. *)
let always (orders : order list) : rule =
  fun _ -> Some orders (*no matter the board always orders*)

(** 2. (2 pts) [when_ p orders] fires with [orders] when [p v] holds, and is
    [None] otherwise. *)
let when_ (p : view -> bool) (orders : order list) : rule =
  fun v -> if p v then Some orders else None (*yes give the orders if some, if no order do nothing*)

(** 3. (2 pts) [guard p r] is [r] when [p v] holds, and [None] otherwise.
    [when_] is for fixed orders; [guard] is for orders that depend on the
    board, like where to attack. *)
let guard (p : view -> bool) (r : rule) : rule = (*r only if p is true*)
  fun v -> if p v then r v else None (*if yes then r if no then nothing*)

(** 4. (3 pts) [first_of rules] tries the rules in order and gives the first
    answer that is not [None]. [first_of []] never fires.
    Hint: List.find_map. *)
let first_of (rules : rule list) : rule = (*ask rules in order*)
  fun v -> List.find_map (fun r -> r v) rules (*find map stops at the first rule that has Some*)

(** 5. (3 pts) [all_of rules] runs EVERY rule and concatenates the orders of
    those that fire, in order. It fires if at least one of them did, and is
    [None] if none did. This is how you run an economy rule and an army
    rule side by side. *)
let all_of (rules : rule list) : rule = (*ask all the rules and combine the list*)
  fun v -> let fired = List.filter_map(fun r -> r v) rules in (*ask rules keep only the Some's*)
  match fired with (*look at collected list*)
  | [] -> None 
  | _ -> Some (List.concat fired) (*put their orders in a list together in order*)

(** 6. (3 pts) [to_bot r] is a bot: the orders of [r] when it fires,
    [default_orders] when it does not. *)
let to_bot (r : rule) : bot =
  fun v -> match r v with
  | Some orders -> orders (*use the orders given*)
  | None -> default_orders (* use hard coded back orders when nothing*)
