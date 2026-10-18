# Evaluation results

Everything below is a snapshot as of 2026-10-13, not a live measurement.
`before` is `main` at `32e7969` (2026-10-09); `after` is the branch merged as
pull request #16, recorded at `b1d1b85` with the change committed as `8130067`
on top (the run reads `HEAD`, so `after.json` says `b1d1b85`). The blind labels
and the holdout were taken on that branch the same day. hashira has changed
since: re-run the suites before quoting a number.

Both were run by the same suite, with the same cases and the same corpus
checkouts:

```sh
eval/run --hashira PATH --label before|after --corpus DIR   # all suites
eval/run --compare eval/results/before.json,eval/results/after.json
```

The corpus is pinned in `eval/corpus.yml`: rubocop v1.75.8 (`lib`), faraday
and rubygems.org at the recorded commits, each run as `hashira [args] --json`
under `eval/probe/peak.rb`, which reports wall time and peak RSS (VmHWM). The
smells and corpus suites pass `--config eval/probe/every.yml` (`checks: all`)
to a version that has opt-in kinds, so every kind is measured whatever its
default.

## When the suites run

CI's `eval` job runs the fixed-answer suites on every push to `main` and every
pull request. They need no corpus and no network, take about ten seconds, and
any failed check fails the build:

```sh
eval/run --hashira . --suites complexity,coupling,duplication,smells,cli --label ci
```

The rest is a pre-release step, run by hand before a version is tagged, with
this README's numbers and snapshot date updated from it:

```sh
eval/run --hashira . --label after   # every suite; clones the corpus into eval/tmp/corpus
eval/run --compare eval/results/before.json,eval/results/after.json
eval/run --hashira . --suites corpus --seed SALT   # a fresh holdout in eval/tmp/holdout/SALT
eval/run --agree eval/results/human/human1         # human labels against the raters
```

The first run parks every sampled finding without a label in
`eval/tmp/pending/<kind>.yml`; label those into `labels/`. Copy a holdout to
`holdout/SALT/`, have two raters label it blind, each into a folder of their
own, and score them against each other with
`eval/run --agree RATER1 --raters RATER2`.

## What the suites check

- **complexity** — SonarSource conformance: 64 snippets with the score the
  specification assigns (nesting, `else`/`elsif`, boolean runs, `a && (b &&
  c)`, recursion, lambdas, `define_method`, rescue, ternaries), plus a
  configured threshold.
- **coupling** — six fixture projects with expected edges, cycles and cuts. The
  cheapest cut is checked against a brute-force minimum (every edge subset up
  to 18 edges, every ordering up to 16 packages), and so is every corpus cycle.
- **duplication** — clusters that must be found (renamed copies, identical
  bodies, a crowded bucket of more than sixty fragments) and non-clusters that
  must not (same shape saying different things, log and error-report lines,
  inverse pairs, relays, schemas).
- **smells** — true positives and true negatives built from real patterns
  (timers, library nodes, owned types, evidence, sprawl weights, indirection,
  fragmentation, inheritance, cohesion, chains, data classes, forwarding,
  declared layers, dead code in a library and in a Rails app, and change
  coupling replayed from a fixture's own git `history:`). A case's
  `config:` is merged into `checks: all`.
- **cli** — baseline and config resolution from another directory,
  suppressions (reason required, listed, unused), per-kind switches and
  thresholds, old baselines and kind renames, a kind the baseline predates.
- **corpus** — each project exits 0 and every cycle's cut is minimum.

## Precision

Each kind's sample is the 25 (or 15, or 20 for indirection) findings with the
smallest SHA-256 of their key, so the sample is stable across runs and a
finding that survives a change keeps its label. `--seed SALT` salts the hash
and leaves out every key any dev label file holds or any earlier draw in
`holdout/` or `human/` handed out, which draws a fresh sample disjoint from
everything labelled so far. `--samples kind=N,...` replaces the sizes in
`eval/corpus.yml`. The interval is a 95% Wilson interval.

Rubric: a finding is **tp** when its claim is true, its remedy applies to code
the project owns, and a strict reviewer on a team aiming for clean code would
ask for the change. It is **fp** otherwise: library contracts (a parser node's
optional child, a source map's missing field), boundary input (a public
argument, a payload), optional style (a plain one-hop reader read twice),
coincidental shape, or a remedy with no owned destination.

Label files, one per kind, each entry with a key, a verdict and a one-line
reason:

- `labels/` — the author's own labels. The same agent wrote the rules and these
  labels, in that order, so they are an upper estimate, not a measurement.
- `blind/` and `blind2/` — two independent raters who labelled a mixed sample of
  `main` and branch findings without knowing which version reported which. They
  agree on 298 of 324 (92%, Cohen's κ 0.65). The raters are independent AI
  reviewers: separate model instances that saw only the shuffled, version-blind
  items and the corpus source, not hashira's code or labels. No human has
  relabelled them yet; the same two raters labelled the holdout.
- `holdout/<salt>/` — a fresh sample drawn after the rules were changed, as it
  was handed to the raters, with no labels.
- `blind/sample.json` and `blind/holdout1.json` — both raters' raw labels for
  the sample and for `holdout1`, side by side.
- `human/<salt>/` — a seeded sample of the default kinds for a person to
  label, with the verdicts left blank ([human/README.md](human/README.md)).
  `eval/run --agree DIR` prints its precision and its agreement with the two
  raters.

### Blind precision

On the branch as it was when the sample was drawn (`main` is lower for every
kind):

| kind | rater 1 | rater 2 | pooled |
| --- | --- | --- | --- |
| duplication | 11/25 | 9/25 | 40% |
| manual_dispatch | 4/11 | 4/11 | 36% |
| feature_envy | 3/10 | 4/10 | 35% |
| control_parameter | 0/4 | 2/4 | 25% |
| repeated_conditional | 1/12 | 4/12 | 21% |
| repeated_call | 6/25 | 4/25 | 20% |
| state_sprawl | 1/11 | 2/11 | 14% |
| utility_function | 1/15 | 2/15 | 10% |
| nil_check | 1/25 | 1/25 | 4% |
| data_clump | 0/2 | 1/2 | — |
| indirection | 0/20 | 0/20 | 0% |

Overall: rater 1 found 19 of 200 `main` findings and 28 of 160 branch findings
true; rater 2 found 23 of 200 and 33 of 160.

### Defaults follow the blind numbers

A heuristic kind is shown and gated by default only when its pooled blind
precision clears one in three. The first decision used the sample alone and
kept duplication, manual_dispatch and feature_envy on, two of them narrowly.
The holdout (below) failed both: feature_envy 0 of 14, manual_dispatch 0 of 4.
Over the sample and the holdout together:

| kind | sample (rater 1, rater 2) | holdout (rater 1, rater 2) | pooled | default |
| --- | --- | --- | --- | --- |
| duplication | 11/25, 9/25 | 11/25, 11/25 | 42/100 (42%) | on |
| manual_dispatch | 4/11, 4/11 | 0/2, 0/2 | 8/26 (31%) | opt-in |
| data_clump | 0/2, 1/2 | 2/5, 1/5 | 4/14 (29%) | opt-in |
| repeated_call | 6/25, 4/25 | 8/25, 9/25 | 27/100 (27%) | opt-in |
| control_parameter | 0/4, 2/4 | — | 2/8 (25%) | opt-in |
| feature_envy | 3/10, 4/10 | 0/7, 0/7 | 7/34 (21%) | opt-in |
| utility_function | 1/15, 2/15 | 2/15, 6/15 | 11/60 (18%) | opt-in |
| repeated_conditional | 1/12, 4/12 | 0/2, 0/2 | 5/28 (18%) | opt-in |
| state_sprawl | 1/11, 2/11 | 1/9, 0/9 | 4/40 (10%) | opt-in |
| nil_check | 1/25, 1/25 | 5/25, 1/25 | 8/100 (8%) | opt-in |
| indirection (hollow hops) | — | 2/2, 0/2 | 2/4 | opt-in |

So duplication is the one heuristic on by default, beside the measurement kinds
(complexity, cycle, sdp_violation, mixed_audience, wide_edge, roll_call) and
`fragmentation`, which a separate readability study measured
([fragmentation/](fragmentation/README.md)). Every other kind is opt-in,
through `checks: all`, a per-kind `checks:` setting, `--kind` or `--fail-on`.

### What the reasons changed, and the dev set since

The raters' reasons named rule-level causes, and the rules changed accordingly
(no individual finding was tuned): utility_function judges classes only (most
false positives were view helpers and concerns); data_clump needs three
parameters; control_parameter skips private and protected helpers;
state_sprawl weighs a field taken straight from a constructor argument
(component props, job arguments) at nothing; repeated_conditional counts
comparisons with a fixed value, type tests and `case` subjects, not plain
truth tests or presence guards; nil_check no longer treats a nil-defaulted
parameter as the codebase's own nil, and leaves a check whose branch raises
and a one-line predicate that answers a nil test.

Re-scored on the blind labels whose findings the branch still reports (a dev
set: the rules were changed after reading these reasons, so it is not a
measurement):

| kind | rater 1 | rater 2 | pooled | corpus findings before → now |
| --- | --- | --- | --- | --- |
| duplication | 12/35 | 14/35 | 37% | 444 → 444 |
| manual_dispatch | 5/16 | 5/16 | 31% | 29 → 29 |
| feature_envy | 3/14 | 4/14 | 25% | 34 → 34 |
| control_parameter | 0/1 | 1/1 | — | 21 → 4 |
| repeated_conditional | 1/5 | 1/5 | 20% | 33 → 7 |
| repeated_call | 7/30 | 5/30 | 20% | 371 → 371 |
| state_sprawl | 1/11 | 2/11 | 14% | 36 → 21 |
| utility_function | 2/11 | 0/11 | 9% | 70 → 36 |
| nil_check | 1/16 | 1/16 | 6% | 111 → 75 |
| data_clump | 0/3 | 1/3 | — | 54 → 8 |
| indirection | 0/0 | 0/0 | — | 327 → 2 |

The fixes cut the weak kinds' volume by a third to six sevenths without
lifting their dev precision much, and the holdout confirmed it: none of them
clears the bar. The dev rows also hold `main`-only findings the branch now reports,
which is why feature_envy and manual_dispatch read lower here than on the
branch sample above.

### Holdout

`eval/run --hashira . --suites corpus --seed holdout1` drew `holdout/holdout1/`:
117 findings across ten kinds, none of them in any dev label file (fewer than
the sample size where the dev labels had already taken most of a kind's
population). The two raters labelled it blind and agree on 102 of 117 (87%,
κ 0.66); their labels are in `blind/holdout1.json`.

## Indirection: hollow hops

Every one of the 20 blind-labelled indirection findings was false: the old rule
priced a method by its single-use helpers read in place, and well-named
helpers that decide, loop or name a step are the decomposition a reader wants.
indirection now counts hollow hops: a helper that is private, called exactly
once from its own class, and whose body is one call with no decision and no
block, wrapping at most one more call. hashira follows each entry's single-use
helpers and reports the path with the most hollow ones once it holds two;
meaningful helpers on the path cost nothing.

| codebase | findings |
| --- | --- |
| hashira (`lib`) | 0 |
| kimera (`lib`) | 0 |
| rubocop-kata (`lib`) | 0 |
| rubocop (`lib`) | 2 |
| faraday | 0 |
| rubygems.org | 0 |

None of the 20 dev findings is reported any more. kimera's
`weave→dispatch→guard→branch` does not meet the definition: `weave` recurses
(so it is called twice), `dispatch` lives in a mixin and decides, `guard` runs
a block and is called from two places, and `branch` holds three statements.
Only the two rubocop config lookups (`unless_else_cop_enabled? →
unless_else_config`) are pure forwarders two deep. In the holdout one rater
judged both true and the other both false.

The readability study behind `fragmentation` shows what readers of the house
style actually object to: many small same-class helpers, not hollow hops (0
findings on kimera and hashira). indirection stays, opt-in: fragmentation does
not cover its two findings, and while it is off it costs nothing.

## Class-level kinds

Six kinds judge how classes are built: `concrete_inheritance`,
`refused_bequest`, `low_cohesion` (LCOM4), `message_chain` (the Law of Demeter
on one chain), `data_class` and `middle_man`. Their rules were fixed, the
corpus run with `checks: all`, and the precision sample drawn the usual way
(the 25 findings per kind with the smallest SHA-256 of their key, which here is
every finding of every kind but `message_chain`). One independent rater
labelled the shuffled sample (and, in a second request, the two
`low_cohesion` findings a fix to constructor linking added after the draw) with the rubric above: a separate model instance
that saw only the findings and the corpus source (rubocop and rubygems.org at
the pinned commits), not hashira's code or the reasoning behind the rules. No
second rater and no human has labelled them yet. The labels are in
`blind/<kind>.yml`, and `blind/class_smells.json` holds the items as the rater
saw them beside its verdicts.

| kind | rubocop | faraday | rubygems.org | true (rater) | default |
| --- | --- | --- | --- | --- | --- |
| message_chain | 19 | 0 | 62 | 2/25 (8%) | opt-in |
| concrete_inheritance | 3 | 0 | 2 | 1/5 | opt-in |
| low_cohesion | 2 | 0 | 1 | 0/3 | opt-in |
| refused_bequest | 1 | 0 | 0 | 0/1 | opt-in |
| data_class | 1 | 0 | 0 | 0/1 | opt-in |
| middle_man | 0 | 0 | 0 | — | opt-in |

None clears one in three, so all six ship opt-in, and four of them are too
rare in this corpus to measure at all. What the rater's reasons say:

- **message_chain**: 23 of the 25 were Rails association reads
  (`version.rubygem.name`, `@api_key.user.rubygems`) or walks of a model meant
  to be walked (rubocop's `variable.scope.node`). The two true ones did work
  through the chain: a presence check and a call through
  `rubygem.organization`, and a job that set up and updated another model's
  association through two hops. Typing every link and requiring the class to
  declare each message keeps library objects out, but not the idiom.
- **concrete_inheritance**: the true one is a subclass that exists to swap one
  constant of a class built on its own; the false ones are a default
  implementation a factory specializes, a runner meant to be extended, and an
  empty Pundit policy subclass that exists for lookup by name.
- **refused_bequest**: Vim magic comments return nil for settings Vim cannot
  express, which the rater read as the parent's own "not specified" contract.
- **low_cohesion**: rubocop's `Offense` and `VariableForce::Assignment`
  and rubygems.org's `ApplicationPolicy` split along a status or error field
  that reviewers read as part of one concept.
- **data_class**: a `:nodoc:` parameter holder in rubocop, where `Data` is not
  available on every Ruby rubocop supports.

`message_chain` is separate from `repeated_call`, which reports any chain read
twice in one method whatever its types; the two can be turned on apart.

## Layers, dead code and change coupling

Three whole-codebase kinds, measured on the same corpus. `graph.json` and
`graph.md` are the branch's board (every suite passes: smells 45/45 with the
new cases, cli 35/35, coupling 25/25, corpus 6/6). The corpus declares a
plausible layering for each project in `corpus.yml` (`config:`), so
layer_violation is measured too.

### Findings on the corpus

| kind | rubocop | faraday | rubygems.org |
| --- | --- | --- | --- |
| layer_violation (declared layers) | 2 | 2 | 3 |
| dead_code | 10 | 1 | 2 |
| change_coupling | 0 | 0 | 3 |

rubocop is one folder package, so no pair of its files crosses a package
boundary and change_coupling cannot fire there. faraday and rubocop are
libraries, so dead_code judges only their private methods and private
constants; rubygems.org is a Rails app, judged outside its entry points.

### Cost

Wall time and peak RSS, the least of three runs each, on a shared machine
(load around 9 on 4 cores, so a single run varies by a few seconds). The
coupling-only rows (`--skip complexity,duplication,smells`) isolate the kinds'
own cost; "base" is this branch with all three off, "main" is `origin/main`.

| run | rubocop | faraday | rubygems.org |
| --- | --- | --- | --- |
| main, coupling only | 3.34 s, 87.8 MB | 0.41 s, 27.7 MB | 2.11 s, 79.7 MB |
| base, coupling only | 3.44 s, 92.2 MB | 0.40 s, 28.0 MB | 2.19 s, 82.9 MB |
| + dead_code | 6.07 s, 96.7 MB | 0.45 s, 28.4 MB | 3.47 s, 91.4 MB |
| + change_coupling | 3.31 s, 90.6 MB | 0.46 s, 28.0 MB | 2.53 s, 79.9 MB |
| + layers | 4.29 s, 96.4 MB | 0.46 s, 27.7 MB | 2.67 s, 69.7 MB |
| main, every analyzer | 29.8 s, 449 MB | 1.24 s, 38.8 MB | 11.1 s, 162 MB |
| base, every analyzer | 30.7 s, 466 MB | 1.22 s, 40.0 MB | 11.8 s, 172 MB |
| + dead_code, every analyzer | 33.1 s, 458 MB | 1.44 s, 40.7 MB | 11.6 s, 169 MB |

Timed in process: the reference walk dead_code and layers share takes 0.7 s on
rubocop and 0.5 s on rubygems.org; dead_code's own work 1.6 s and 0.7 s (most
of it the name index and reading the project's other files: specs, views,
configuration); layer_violation 0.14 s and 0.04 s; change_coupling under 0.1 s
on top of the git log the hotspots already read. Peak memory moves by less
than the run-to-run spread, about 10 MB at most.

### Blind precision

Two raters labelled every dead_code finding the corpus reports (13), and a
looser change_coupling sample (degree 30% and over, 17 findings, which holds
the 3 at the default limits), blind as before: separate model instances that
saw only the shuffled findings, the shared commits and the corpus source,
cloned at the pinned commits, not hashira's code or these notes. Their labels
are in `blind/` and `blind2/`, side by side in `blind/graph.json`.

| kind | rater 1 | rater 2 | pooled | agreement | default |
| --- | --- | --- | --- | --- | --- |
| dead_code | 13/13 | 13/13 | 26/26 (100%) | 13/13 | on |
| change_coupling, default limits | 1/3 | 2/3 | 3/6 | 2/3 | opt-in |
| change_coupling, degree ≥ 30% | 2/17 | 3/17 | 5/34 (15%) | 16/17 | — |

dead_code clears the bar with room to spare (each rater's 95% Wilson interval
is 0.77 to 1.0), so it is on by default. Every finding was a private helper,
an error class or a constant nothing reaches; both raters checked by searching
each repository for the name, node patterns and specs included.
change_coupling has three findings at its limits, too few to measure, and the
looser sample is weak, so it stays opt-in like the other kinds too rare to
measure. The raters' reasons name two causes: pairs that only ever changed
together in RuboCop lint sweeps (6 of faraday's 7), which a commit-size cap
of 30 files does not catch in a 32-file library, and feature work that
naturally touches a model and its controller or two associated models. The
true ones were duplicated knowledge: two upload jobs copying one S3 routine,
a policy repeating its parent's role rule, and (for one rater) a field list
written out in a query and in a struct.

layer_violation is not rated: a finding is a reference that points outward
from a layering the user declared, true by construction once the declaration
is taken as intent. Its corpus layerings are mine, there to price the check.

### hashira on itself

hashira declares its own layers in `.hashira.yml` (cli; ci and diagram;
pipeline and report; the analyzers; analysis and config) and reports no
layer_violation and no dead_code. `.hashira.yml` turns change_coupling off for
hashira's own gate: CI checks out one commit, so a history-based finding would
be present locally and resolved there. Run locally on this branch it reports
none.

## Known limits

- nil_check is the least precise kind on both raters' labels: most nil checks
  the raters saw were legitimate absence (a signed-out user, a missing lookup,
  an optional field read from data), which the provenance rule cannot tell from
  a designable one.
- feature_envy and manual_dispatch still name a class from a variable's name; a
  name that collides with an owned class (`loc` and a `Loc` struct) can mislead
  them.
- Recall fell with precision: envy toward an ActiveRecord model through columns
  its class does not declare, nil checks on public arguments, flags no caller
  passes, flags in private helpers, pairs of parameters and plain truth tests
  are no longer reported.
- Hollow-hop indirection is nearly silent on these corpora; with two findings
  its precision cannot be measured on them.
- Duplication and dead_code are the heuristics that clear the bar: the
  default report is mostly measurements.
- dead_code matches methods by name, so a dead method that shares its name
  with any call, symbol or word in the project is missed; and the corpus
  gives it only 13 findings, all private or internal, so its precision on a
  Rails app's public methods rests on two.
- change_coupling sees only pairs across package boundaries, so a project
  hashira reads as one package (rubocop) shows none, and lint sweeps under
  the commit-size cap still pair files.

## Before and after

`before` is `main`, run with this branch's suite (every kind on, since `main`
has no opt-in kinds).

### Suites

| suite | before | after |
| --- | --- | --- |
| complexity | 55/66 (83.3%) | 66/66 (100.0%) |
| coupling | 17/25 (68.0%) | 25/25 (100.0%) |
| duplication | 6/10 (60.0%) | 10/10 (100.0%) |
| smells | 11/19 (57.9%) | 23/23 (100.0%) |
| cli | 11/35 (31.4%) | 35/35 (100.0%) |
| corpus | 5/6 (83.3%) | 6/6 (100.0%) |

### Corpus

#### rubocop

|  | before | after |
| --- | --- | --- |
| files | 880 | 880 |
| kloc | 82.9 | 82.9 |
| seconds | 34.36 | 33.92 |
| megabytes | 463.2 | 492.8 |
| assumed_state | 1 (0.01/kLOC) | 1 (0.01/kLOC) |
| complexity | 38 (0.46/kLOC) | 39 (0.47/kLOC) |
| control_parameter | 88 (1.06/kLOC) | 3 (0.04/kLOC) |
| cycle | 1 (0.01/kLOC) | 1 (0.01/kLOC) |
| data_clump | 52 (0.63/kLOC) | 7 (0.08/kLOC) |
| duplication | 251 (3.03/kLOC) | 282 (3.4/kLOC) |
| feature_envy | 202 (2.44/kLOC) | 24 (0.29/kLOC) |
| fragmentation | 0 | 1 (0.01/kLOC) |
| indirection | 0 | 2 (0.02/kLOC) |
| manual_dispatch | 123 (1.48/kLOC) | 18 (0.22/kLOC) |
| module_initialize | 1 (0.01/kLOC) | 1 (0.01/kLOC) |
| nil_check | 156 (1.88/kLOC) | 41 (0.49/kLOC) |
| repeated_call | 791 (9.54/kLOC) | 263 (3.17/kLOC) |
| repeated_conditional | 21 (0.25/kLOC) | 6 (0.07/kLOC) |
| state_sprawl | 25 (0.3/kLOC) | 14 (0.17/kLOC) |
| utility_function | 41 (0.49/kLOC) | 25 (0.3/kLOC) |

#### faraday

|  | before | after |
| --- | --- | --- |
| files | 32 | 32 |
| kloc | 3.17 | 3.17 |
| seconds | 1.35 | 1.1 |
| megabytes | 50.5 | 38.8 |
| complexity | 4 (1.26/kLOC) | 5 (1.58/kLOC) |
| control_parameter | 1 (0.32/kLOC) | 0 |
| cycle | 1 (0.32/kLOC) | 1 (0.32/kLOC) |
| data_clump | 2 (0.63/kLOC) | 1 (0.32/kLOC) |
| duplication | 14 (4.42/kLOC) | 15 (4.73/kLOC) |
| feature_envy | 4 (1.26/kLOC) | 0 |
| manual_dispatch | 11 (3.47/kLOC) | 4 (1.26/kLOC) |
| mixed_audience | 1 (0.32/kLOC) | 1 (0.32/kLOC) |
| nil_check | 29 (9.15/kLOC) | 9 (2.84/kLOC) |
| repeated_call | 25 (7.89/kLOC) | 13 (4.1/kLOC) |
| repeated_conditional | 3 (0.95/kLOC) | 1 (0.32/kLOC) |
| state_sprawl | 1 (0.32/kLOC) | 1 (0.32/kLOC) |
| utility_function | 5 (1.58/kLOC) | 5 (1.58/kLOC) |
| wide_edge | 1 (0.32/kLOC) | 1 (0.32/kLOC) |

#### rubygems.org

|  | before | after |
| --- | --- | --- |
| files | 558 | 558 |
| kloc | 20.73 | 20.73 |
| seconds | 12.25 | 11.38 |
| megabytes | 200.0 | 180.6 |
| complexity | 18 (0.87/kLOC) | 18 (0.87/kLOC) |
| control_parameter | 16 (0.77/kLOC) | 1 (0.05/kLOC) |
| cycle | 2 (0.1/kLOC) | 2 (0.1/kLOC) |
| duplication | 136 (6.56/kLOC) | 147 (7.09/kLOC) |
| feature_envy | 20 (0.96/kLOC) | 10 (0.48/kLOC) |
| manual_dispatch | 13 (0.63/kLOC) | 7 (0.34/kLOC) |
| nil_check | 90 (4.34/kLOC) | 25 (1.21/kLOC) |
| repeated_call | 165 (7.96/kLOC) | 95 (4.58/kLOC) |
| repeated_conditional | 9 (0.43/kLOC) | 0 |
| roll_call | 3 (0.14/kLOC) | 3 (0.14/kLOC) |
| sdp_violation | 1 (0.05/kLOC) | 1 (0.05/kLOC) |
| state_sprawl | 20 (0.96/kLOC) | 6 (0.29/kLOC) |
| utility_function | 24 (1.16/kLOC) | 6 (0.29/kLOC) |
| wide_edge | 2 (0.1/kLOC) | 2 (0.1/kLOC) |

### Precision (the author's own labels)

| kind | before | after |
| --- | --- | --- |
| repeated_call | 9/25 = 0.36 [0.202, 0.555] of 981 | 25/25 = 1.0 [0.867, 1.0] of 371 |
| feature_envy | 3/25 = 0.12 [0.042, 0.3] of 226 | 11/25 = 0.44 [0.267, 0.629] of 34 |
| nil_check | 4/25 = 0.16 [0.064, 0.347] of 275 | 2/17 = 0.118 [0.033, 0.343] of 75 |
| manual_dispatch | 5/25 = 0.2 [0.089, 0.391] of 147 | 9/25 = 0.36 [0.202, 0.555] of 29 |
| duplication | 16/25 = 0.64 [0.445, 0.798] of 401 | 17/25 = 0.68 [0.484, 0.828] of 444 |
| control_parameter | 5/15 = 0.333 [0.152, 0.583] of 105 | 4/4 = 1.0 [0.51, 1.0] of 4 |
| utility_function | 15/15 = 1.0 [0.796, 1.0] of 70 | 8/8 = 1.0 [0.676, 1.0] of 36 |
| data_clump | 12/15 = 0.8 [0.548, 0.93] of 54 | 2/2 = 1.0 [0.342, 1.0] of 8 |
| state_sprawl | 8/15 = 0.533 [0.301, 0.752] of 46 | 7/9 = 0.778 [0.453, 0.937] of 21 |
| repeated_conditional | 12/15 = 0.8 [0.548, 0.93] of 33 | 4/4 = 1.0 [0.51, 1.0] of 7 |
| indirection | — | — |
