(lang dune 3.1)

(name rts)

(generate_opam_files true)

(source
 (github OU-CS3200/ou-cs3200-fall-2026-rts))

(authors "Ohio University CS 3200")

(maintainers "Ohio University CS 3200")

(package
 (name rts)
 (synopsis "CS 3200 RTS-1: Read the board")
 (description
  "Programming assignment series for CS 3200 at Ohio University, built on the OCaml RTSArena engine. RTS-1: queries, an evaluation function, and a rule-based bot.")
 (depends
  ocaml
  dune
  alcotest
  qcheck
  qcheck-alcotest)
 (allow_empty)
 (tags
  ("ocaml" "education" "cs3200")))
