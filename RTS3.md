# RTS-3 · Look ahead

CS 3200, Fall 2026 · Chapters 8 (correctness) and 9 (memoization). The last of
three assignments on RTSArena, in **the same repository** as RTS-1 and RTS-2.

Your RTS-1 bot follows rules. This one thinks ahead. At every consultation it
tries each of a handful of plans *in simulation* — a hundred ticks into the
future, against a guess at what the opponent will do — scores where each plan
ends up with your RTS-1 `eval`, and plays the best one.

That only works because of RTS-2. A search bot forks the real game hundreds of
times a second; if a fork could write into the real game, every simulation
would corrupt the match being played. Once a game is a sealed, immutable value,
a fork is just the game — no copy at all.

## Getting RTS-3 into your repository

```
git fetch template
git merge template/rts3
```

This time **git will report conflicts** in `engine/` and `bin/`: you edited
those in RTS-2, and RTS-3 replaces them with the reference engine (so that every
bot in the tournament plays on the same one). Take the template's version of
both, and keep everything else:

```
git checkout --theirs engine bin
git add engine bin
git commit
```

Your `student/`, `props/` and `fixes/` code is untouched. Keep your RTS-2
engine on your `rts2` tag if you want it — `git show rts2:engine/rtsarena.ml`.

## What to do

All of your code goes in `search/`. Each file says what it wants at the top.

| Part | Where | Points | What |
| :--- | :--- | ---: | :--- |
| A1 | `search/policies.ml` | 10 | A menu of at least 6 candidate plans |
| A2 | `search/search_bot.ml` | 30 | The search bot |
| B | `search/memo.ml`, this file | 30 | Memoize the rollouts, measure it, explain the key |
| C | `bin/rts_bot.exe` | 20 + bonus | A tournament entry that runs without faults |
| D | this file | 10 | The questions at the end |

`dune test` runs everything; `dune exec test/test_rts3.exe -- test search` runs
one group. Try your bot in the runner as `my-search`:

```
dune exec bin/main.exe -- play my-search my-bot --show
```

### Part A — Search (40 pts)

**A1 (10):** the menu. At least six plans, built from your RTS-1 combinators,
with your RTS-1 bot among them under the name `"my-bot"`. Small and different
beats big and similar: every plan costs a rollout at every consultation.

**A2 (30):** the search, in `make`. The comment at the top of the file walks
through it. Graded by winning and by time, on the default settings
(`make ()`: 100-tick rollouts, your RTS-1 bot as the opponent model, cache on):

| Points | Requirement |
| ---: | :--- |
| 15 | Beat **your own RTS-1 bot** in at least 6 of 8 games (4 maps × both sides) |
| 10 | Beat light-rush, heavy-rush and ranged-rush on both sides |
| 5 | Mean time per consultation, over those games, at most **100 ms** |

The tests also check that the cache never changes a decision: the same view
must get the same orders from a warm bot, a cold bot, and a bot without a cache.

### Part B — Memoize (30 pts)

**Code (20):** `key` and `rollout_chunks` in `search/memo.ml`. The tests check
that a chunked rollout equals the engine's `rollout` exactly, with and without
the cache, and that the key tells apart what it must.

**Measure (5):** run the bench and paste its table here:

```
dune exec bin/bench.exe
```

**Explain (5):** then *break* your key on purpose — make a copy that leaves out
the turn — and answer:

1. What happened to the hit rate?
2. Were the games the cache handed back wrong? *How* were they wrong? (Compare
   a cached chunk with a freshly computed one: the units, the stockpiles, the
   turn.) Why does it matter for a rollout, even when the units come out right?
3. Your bot keeps a `Hashtbl` that changes every time it is called — exactly the
   kind of hidden state RTS-1 Part D and RTS-2 fix 3 took away from
   `random_bot`. Why is your hidden state acceptable, and `random_bot`'s was
   not? What test in `test/test_rts3.ml` checks your answer?

### Part C — Tournament (20 pts + bonus)

Your entry is `bin/rts_bot.exe`, which now plays `Search_bot.bot`. We run every
entry against every other, both sides, on the default and corridors maps, on
the reference engine, through the JSON protocol.

- **20 pts** for an entry that finishes the whole round robin with no faults.
  A fault is a crash, output we cannot read, or a reply slower than 1 second;
  three faults in one game forfeit it.
- **Bonus:** +5 / +3 / +2 for first, second and third place.

Try it yourself before you submit:

```
dune build ./bin/rts_bot.exe
echo '{"gameOver":true}' | ./_build/default/bin/rts_bot.exe    # should exit cleanly
```

The protocol sends more than the JavaScript arena does: what each unit is doing,
what each building is making, the order the engine keeps entities in, and the id
the next unit will get. `bin/rts_bot.ml` already reads all of it. Question 3
below asks why each one is there.

## Part D — answer here (10 pts)

1. **(4 pts) A loss.** Find a game your search bot lost to a bot it should
   beat (another map, a different opponent model, a shorter rollout — look
   for one). Was the opponent model wrong, the eval wrong, or the horizon too
   short? Show the evidence: what the bot predicted, and what happened.

2. **(3 pts) The horizon.** Run `bench` and look at the `wins` column for
   20-tick and 100-tick rollouts. Why would a *shorter* lookahead lose games
   that a longer one wins, when the shorter one has more consultations'
   worth of time to spare?

3. **(3 pts) The protocol.** Before the tournament sent the entity order and
   the next id, a search bot rebuilt from the wire lost to the plain RTS-1 bot
   it beats in-process — with every unit, stockpile and cell exactly right.
   Explain how that can be. What does it say about `fork`, and about what a
   `view` shows you?

## Collaboration and AI

As before: who you talked to, and which AI tools you used for what, under the
heading below.

## README (collaboration / AI use)

*Who you talked to, and what AI tools you used for what.*

## Submitting

```
git tag rts3 && git push origin rts3
```

Upload the zip on Canvas. For the tournament we build `bin/rts_bot.exe` from
the commit you tagged.
