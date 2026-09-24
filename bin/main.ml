(** Command-line runner for the OCaml RTSArena engine, with your bot entered
    as [my-bot].

    {v
      rtsarena list                       show the built-in bots
      rtsarena play A B [options]         one match
      rtsarena tournament [options]       round robin, every bot vs every bot
    v}

    Options: [--size N] [--turns N] [--preset default|rich|sparse|corridors]
             [--interval N] [--show] [--quiet] *)

open Rtsarena

(* Your bot joins the built-ins. [random] is rebuilt for every match so that
   every match starts from the same seed. *)
let bot_named name =
  match name with
  | "my-bot" -> Some Bot.my_bot
  | "random" -> Some (random_bot 42)
  | _ -> Rtsarena.bot_named name

let bot_names () = "my-bot" :: Rtsarena.bot_names ()

let arg_value name default argv =
  let rec go = function
    | a :: v :: _ when a = "--" ^ name -> v
    | _ :: rest -> go rest
    | [] -> default
  in
  go argv

let has_flag name argv = List.mem ("--" ^ name) argv

let side_name = function 0 -> "P0" | 1 -> "P1" | _ -> "draw"

let usage () =
  print_string
    "RTSArena (OCaml)\n\n\
     Usage:\n\
    \  rtsarena list\n\
    \  rtsarena play <bot-a> <bot-b> [options]\n\
    \  rtsarena tournament [options]\n\n\
     Options:\n\
    \  --size N        map size (8, 16, 32)          default 16\n\
    \  --turns N       turn limit                    default 500\n\
    \  --preset NAME   default | rich | sparse | corridors\n\
    \  --interval N    ticks between consultations   default 20\n\
    \  --show          print the board every 50 ticks\n\
    \  --quiet         print only the result line\n\n";
  print_endline ("Bots: " ^ String.concat ", " (bot_names ()))

let common argv =
  let i s d = int_of_string_opt (arg_value s (string_of_int d) argv) |> Option.value ~default:d in
  (i "size" 16, i "turns" 500, arg_value "preset" "default" argv, i "interval" 20)

let cmd_play argv =
  match argv with
  | a :: b :: rest ->
    (match bot_named a, bot_named b with
     | None, _ -> Printf.eprintf "unknown bot: %s\n" a; exit 1
     | _, None -> Printf.eprintf "unknown bot: %s\n" b; exit 1
     | Some pa, Some pb ->
       let size, turns, preset, interval = common rest in
       let show = has_flag "show" rest and quiet = has_flag "quiet" rest in
       let on_tick g _ =
         if show && g.turn mod 50 = 0 then begin
           Printf.printf "\n-- turn %d --  resources %d / %d\n" g.turn
             (resources_of g 0) (resources_of g 1);
           print_string (to_ascii g 0)
         end
       in
       if not quiet then
         Printf.printf "%s (P0) vs %s (P1) on %dx%d %s, %d turns\n\n"
           a b size size preset turns;
       let r = play ~size ~max_turns:turns ~preset ~interval ~on_tick pa pb in
       let win = match r.winner with 0 -> a | 1 -> b | _ -> "draw" in
       Printf.printf "%s after %d turns (%s) — winner: %s\n"
         (side_name r.winner) r.turns r.final_reason win)
  | _ -> usage (); exit 1

let cmd_tournament argv =
  let size, turns, preset, interval = common argv in
  let names = bot_names () in
  let n = List.length names in
  let score = Hashtbl.create n in
  List.iter (fun b -> Hashtbl.replace score b 0) names;
  let add b v = Hashtbl.replace score b (Hashtbl.find score b + v) in
  Printf.printf "round robin — %d bots, both sides, %dx%d %s, %d turns\n\n"
    n size size preset turns;
  List.iter
    (fun a ->
       List.iter
         (fun b ->
            if a <> b then begin
              let pa = Option.get (bot_named a) and pb = Option.get (bot_named b) in
              let r = play ~size ~max_turns:turns ~preset ~interval pa pb in
              (match r.winner with
               | 0 -> add a 3
               | 1 -> add b 3
               | _ -> add a 1; add b 1);
              Printf.printf "  %-13s vs %-13s  %-5s  %3d turns  (%s)\n" a b
                (match r.winner with 0 -> a | 1 -> b | _ -> "draw")
                r.turns r.final_reason
            end)
         names)
    names;
  let table =
    List.sort (fun (_, x) (_, y) -> compare y x)
      (List.map (fun b -> (b, Hashtbl.find score b)) names)
  in
  print_endline "\nstandings (3 for a win, 1 for a draw)";
  List.iteri (fun i (b, p) -> Printf.printf "  %d. %-14s %3d\n" (i + 1) b p) table

let () =
  match Array.to_list Sys.argv with
  | _ :: "list" :: _ ->
    print_endline "built-in bots:";
    List.iter (fun n -> Printf.printf "  %s\n" n) (bot_names ())
  | _ :: "play" :: rest -> cmd_play rest
  | _ :: "tournament" :: rest -> cmd_tournament rest
  | _ -> usage ()
