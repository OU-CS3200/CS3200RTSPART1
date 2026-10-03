(** Testing voodoo. Feel free to ignore. *)

let todo (type t) (x : t) : 'a =
  let module M = struct exception Todo of t end in
  raise @@ M.Todo x
