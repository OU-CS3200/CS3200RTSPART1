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

Use the `template` remote you added for RTS-2, over SSH. Check with
`git remote -v`: if `template` or `origin` starts with `https://`, switch it
first (RTS2.md shows how; the organization's two-factor requirement means
HTTPS cannot push). If you never added `template`:

```
git remote add template git@github.com:OU-CS3200/ou-cs3200-fall-2026-rts.git
```

Then:

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

**If you hit conflicts you cannot resolve easily, do not fight them.** Run
`git merge --abort`, make a fresh clone of *your* repository into a new folder
(`git clone git@github.com:OU-CS3200/YOUR-REPO.git rts3-fresh`), and repeat the
steps above there. Everything you committed and pushed is in the fresh clone;
anything you did not push is not, so push first.

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

| ticks | cache | ms / consultation | hit rate | wins |
| ---: | :--- | ---: | ---: | ---: |
|  20 | off   |     10.4 |     — | 2 / 8 |
|  20 | on    |      8.4 |   28.5% | 2 / 8 |
|  50 | off   |     11.9 |     — | 7 / 8 |
|  50 | on    |     11.2 |   10.2% | 7 / 8 |
| 100 | off   |     23.3 |     — | 7 / 8 |
| 100 | on    |     20.7 |   18.3% | 7 / 8 |

**Explain (5):** then *break* your key on purpose — make a copy that leaves out the turn — and answer:

1. What happened to the hit rate?

   The hit rate barely changed. 28.5% stayed the same, 10.2% changed to 10.4%, and 18.3% to 18.8% and the wins stayed the same. The broken key was fine and had no crashing happening.

2. Were the games the cache handed back wrong? *How* were they wrong? (Compare a cached chunk with a freshly computed one: the units, the stockpiles, the turn.) Why does it matter for a rollout, even when the units come out right?

   In a test two games with the same units but a different turn (0 and 50) and 7 extra gold in one of them. They got the same broken key. One chunk had ended up at turn 20 and the other was at 70, and my gold was 5 versus the other 12. So a cache hit would hand back the wrong turn and the wrong stockpile even if the units come out right. For a rollout that matters because it stops turn count and the bots read from the turn and gold numbers, thus a wrong turn or wrong gold changes the bots next moves.

3. Your bot keeps a `Hashtbl` that changes every time it is called — exactly the kind of hidden state RTS-1 Part D and RTS-2 fix 3 took away from `random_bot`. Why is your hidden state acceptable, and `random_bot`'s was not? What test in `test/test_rts3.ml` checks your answer?

   The Hashtbl only stored what the engine would give. The key would always give the same game, so the cache never changes what the bot decided it could only make it faster. The random_bot hidden state changed its answers so making the same view give different orders each call, so a game could not be replayed. Memo 1 test, the cache never changes a result, checks this and, the search 1 the cache never changes a decision. 

### Part C — Tournament (20 pts + bonus)

Your entry is `bin/rts_bot.exe`, which now plays `Search_bot.bot`. We run every
entry against every other, both sides, on the default and corridors maps, on
the reference engine, through the JSON protocol.

- **20 pts** for an entry that finishes the whole round robin with no faults.
  A fault is a crash, output we cannot read, or a reply slower than 1 second;
  three faults in one game forfeit it.
- **Bonus:** +100 / +50 / +30 for first, second and third place.
- **Unique contributions: +50 to +200.** Anything else you did that no one
  else did. Describe it, with the evidence, under *Unique contributions* at
  the end of this file.

Try it yourself before you submit:

```
dune build ./bin/rts_bot.exe
echo '{"gameOver":true}' | ./_build/default/bin/rts_bot.exe    # should exit cleanly
```

The protocol sends more than the JavaScript arena does: what each unit is doing,
what each building is making, the order the engine keeps entities in, and the id
the next unit will get. `bin/rts_bot.ml` already reads all of it. Question 3
below asks why each one is there.

**The RTSArena League: your entry is your ticket.** After grading, every entry
also plays in the class league: a nightly ladder with Elo ratings and browser
replays, badges for beating each built-in bot, and a finals watch party in class
for the top 8. The league never changes your RTS-3 grade, which comes only from
the round robin above. You may push a `league` tag to keep improving your bot
during the ladder. The leaderboard shows a handle, never your name: to pick
one, add `bin/league.json` with `{"handle": "...", "color": "#rrggbb"}`.
Submitting counts as entering. To opt out, put this line at the top of this
file:

```
League: out
```

## Part D — answer here (10 pts)

1. **(4 pts) A loss.** Find a game your search bot lost to a bot it should beat (another map, a different opponent model, a shorter rollout — look for one). Was the opponent model wrong, the eval wrong, or the horizon too short? Show the evidence: what the bot predicted, and what happened.

   My search lost as P0 on default and rich to my-bot, and won the other games. I logged each consultation predicting score and chosen plan versus what the real eval was 100 ticks later. The prediction were right. Predicted -11.8 at t=40 and the real eval at t=140 was -11.8; predicted 24.3 at t=100 and real 24.3 at t=200; predicted -26.7 at t=160 and real -26.7 at t=260; predicted -65.0 at t=200 and real -65.0 at t=300. So my-bot and the eval were not the problem. The bot chose my-bot at 16 of 17 consultations, so no other plan in my menu scored higher. I think the limit is my menu and the 100-tick horizon, once it saw the deficit (t=160, -26.7) none of the six plans would be able to fix it.

2. **(3 pts) The horizon.** Run `bench` and look at the `wins` column for 20-tick and 100-tick rollouts. Why would a *shorter* lookahead lose games that a longer one wins, when the shorter one has more consultations' worth of time to spare?

   At 20 ticks the bot won 2/8, and at 50 or 100 ticks 7/8.
   A barracks takes 10 ticks and units take 4 to 6, so I think a 20-tick rollout mostly sees plans spending money, not the army they build. A short lookahead picks plans that look good now and lose later. More consultations don't help, because each one is just as short-sighted.


3. **(3 pts) The protocol.** Before the tournament sent the entity order and the next id, a search bot rebuilt from the wire lost to the plain RTS-1 bot it beats in-process — with every unit, stockpile and cell exactly right. Explain how that can be. What does it say about `fork`, and about what a `view` shows you?

   The engine keeps hidden things a view does not show: the
   order of the entities and the next id. They decide who acts first and which unit wins a tie. A game rebuilt from the wire had every unit, stockpile and cell right, but its future was different, so its rollouts predicted wrongly. A fork of the real game carries all of that hidden state. A view only shows part of the game, so a game rebuilt from a view is a guess.

## Unique contributions

I built make_pro as my tournament entry. It does:
   - Opponent guessing: it looks at the enemy's visible army and picks a matching oppent model
   - Safe scoring: each plan is scored against the guess and against my RTS-1 bot
   - Bigger menu 3 extra plans
   - A 0,4s time guard and fallback
   - Plan stickiness and faster wins scoring higher
   - Plan sequemces: it also tests plan A then plan B after 40 ticks and plays A now. 
   - Speed: basic make () about 21 ms per move. The tournament entry
  (make_pro with 5 opponent models and plan sequences) averaged 193 ms
  and at worst 322 ms per move over 283 moves (limit 1000 ms), kept
  down by a 0.3 s time guard.
Evidence
 - basic 9/24, pro (100 ticks) 17/24. pro beat basic 6 of 8.
 - Looking further ahead was worse: 150 ticks 11/24, 200 ticks 11/24.
 - Extra features: base 9/24, seq 13/24, multi (two horizons) 13/24,
  both 12/24. seq beat base 5 of 8 and beat multi 5 of 8.
 - Against all built-in bots (4 maps, both sides), basic and pro both won 64/64, so those bots could not tell them apart.
 - Speed: basic about 21 ms per move, pro about 47 ms (limit 1000 ms).

## Collaboration and AI

As before: who you talked to, and which AI tools you used for what, under the
heading below.

## README (collaboration / AI use)

Did not talk to anyone and used claude to organize and explain what needs to be done and show code and explain what could help. 

## Submitting

```
git tag rts3 && git push origin rts3
```

Upload the zip on Canvas. For the tournament we build `bin/rts_bot.exe` from
the commit you tagged.
