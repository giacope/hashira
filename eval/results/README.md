# Evaluation results

`before` is `main` at the commit recorded in `before.json`; `after` is this
branch at the commit in `after.json`. Both were run by the same suite, with the
same cases and the same corpus checkouts:

```sh
eval/run --hashira PATH --label before|after --corpus DIR   # all suites
eval/run --compare eval/results/before.json,eval/results/after.json
```

The corpus is pinned in `eval/corpus.yml`: rubocop v1.75.8 (`lib`), faraday
and rubygems.org at the recorded commits, each run as `hashira [args] --json`
under `eval/probe/peak.rb`, which reports wall time and peak RSS (VmHWM).

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
  (timers, library nodes, owned types, evidence, sprawl weights, indirection).
- **cli** — baseline and config resolution from another directory,
  suppressions (reason required, listed, unused), per-kind switches and
  thresholds, old baselines and kind renames, a kind the baseline predates.
- **corpus** — each project exits 0 and every cycle's cut is minimum.

## Precision

Each kind's sample is the 25 (or 15, or 20 for indirection) findings with the
smallest SHA-256 of their key, so the sample is stable across runs and a
finding that survives a change keeps its label. Labels live in `labels/`, one
file per kind, with the evidence and a one-line reason; `eval/run` lists
unlabelled sample members in `eval/tmp/pending/`. The interval is a 95% Wilson
interval.

Rubric: a finding is **tp** when its claim is true, its remedy applies to code
the project owns, and a strict reviewer on a team aiming for clean code would
ask for the change. It is **fp** otherwise: library contracts (a parser node's
optional child, a source map's missing field), boundary input (a public
argument, a payload), optional style (a plain one-hop reader read twice),
coincidental shape, or a remedy with no owned destination.

Caveat: the same agent wrote the rules and the labels, in that order, so the
after-precision is an upper estimate until the labels are blind-relabelled.

## Before and after

## Suites

| suite | before | after |
| --- | --- | --- |
| complexity | 55/66 (83.3%) | 66/66 (100.0%) |
| coupling | 17/25 (68.0%) | 25/25 (100.0%) |
| duplication | 6/10 (60.0%) | 10/10 (100.0%) |
| smells | 10/18 (55.6%) | 18/18 (100.0%) |
| cli | 7/29 (24.1%) | 29/29 (100.0%) |
| corpus | 5/6 (83.3%) | 6/6 (100.0%) |

## Corpus

### rubocop

|  | before | after |
| --- | --- | --- |
| files | 880 | 880 |
| kloc | 82.9 | 82.9 |
| seconds | 39.93 | 33.74 |
| megabytes | 461.4 | 482.6 |
| assumed_state | 1 (0.01/kLOC) | 1 (0.01/kLOC) |
| complexity | 38 (0.46/kLOC) | 39 (0.47/kLOC) |
| control_parameter | 88 (1.06/kLOC) | 17 (0.21/kLOC) |
| cycle | 1 (0.01/kLOC) | 1 (0.01/kLOC) |
| data_clump | 52 (0.63/kLOC) | 52 (0.63/kLOC) |
| duplication | 251 (3.03/kLOC) | 282 (3.4/kLOC) |
| feature_envy | 202 (2.44/kLOC) | 24 (0.29/kLOC) |
| indirection | 0 | 303 (3.66/kLOC) |
| manual_dispatch | 123 (1.48/kLOC) | 18 (0.22/kLOC) |
| module_initialize | 1 (0.01/kLOC) | 1 (0.01/kLOC) |
| nil_check | 156 (1.88/kLOC) | 61 (0.74/kLOC) |
| repeated_call | 791 (9.54/kLOC) | 263 (3.17/kLOC) |
| repeated_conditional | 21 (0.25/kLOC) | 21 (0.25/kLOC) |
| state_sprawl | 25 (0.3/kLOC) | 25 (0.3/kLOC) |
| utility_function | 41 (0.49/kLOC) | 41 (0.49/kLOC) |

### faraday

|  | before | after |
| --- | --- | --- |
| files | 32 | 32 |
| kloc | 3.17 | 3.17 |
| seconds | 1.98 | 1.29 |
| megabytes | 51.7 | 41.2 |
| complexity | 4 (1.26/kLOC) | 5 (1.58/kLOC) |
| control_parameter | 1 (0.32/kLOC) | 0 |
| cycle | 1 (0.32/kLOC) | 1 (0.32/kLOC) |
| data_clump | 2 (0.63/kLOC) | 2 (0.63/kLOC) |
| duplication | 14 (4.42/kLOC) | 15 (4.73/kLOC) |
| feature_envy | 4 (1.26/kLOC) | 0 |
| indirection | 0 | 6 (1.89/kLOC) |
| manual_dispatch | 11 (3.47/kLOC) | 4 (1.26/kLOC) |
| mixed_audience | 1 (0.32/kLOC) | 1 (0.32/kLOC) |
| nil_check | 29 (9.15/kLOC) | 13 (4.1/kLOC) |
| repeated_call | 25 (7.89/kLOC) | 13 (4.1/kLOC) |
| repeated_conditional | 3 (0.95/kLOC) | 3 (0.95/kLOC) |
| state_sprawl | 1 (0.32/kLOC) | 1 (0.32/kLOC) |
| utility_function | 5 (1.58/kLOC) | 5 (1.58/kLOC) |
| wide_edge | 1 (0.32/kLOC) | 1 (0.32/kLOC) |

### rubygems.org

|  | before | after |
| --- | --- | --- |
| files | 558 | 558 |
| kloc | 20.73 | 20.73 |
| seconds | 14.81 | 11.61 |
| megabytes | 202.4 | 165.9 |
| complexity | 18 (0.87/kLOC) | 18 (0.87/kLOC) |
| control_parameter | 16 (0.77/kLOC) | 4 (0.19/kLOC) |
| cycle | 2 (0.1/kLOC) | 2 (0.1/kLOC) |
| duplication | 136 (6.56/kLOC) | 147 (7.09/kLOC) |
| feature_envy | 20 (0.96/kLOC) | 10 (0.48/kLOC) |
| indirection | 0 | 18 (0.87/kLOC) |
| manual_dispatch | 13 (0.63/kLOC) | 7 (0.34/kLOC) |
| nil_check | 90 (4.34/kLOC) | 37 (1.78/kLOC) |
| repeated_call | 165 (7.96/kLOC) | 95 (4.58/kLOC) |
| repeated_conditional | 9 (0.43/kLOC) | 9 (0.43/kLOC) |
| roll_call | 3 (0.14/kLOC) | 3 (0.14/kLOC) |
| sdp_violation | 1 (0.05/kLOC) | 1 (0.05/kLOC) |
| state_sprawl | 20 (0.96/kLOC) | 10 (0.48/kLOC) |
| utility_function | 24 (1.16/kLOC) | 24 (1.16/kLOC) |
| wide_edge | 2 (0.1/kLOC) | 2 (0.1/kLOC) |

## Precision (labeled sample)

| kind | before | after |
| --- | --- | --- |
| repeated_call | 9/25 = 0.36 [0.202, 0.555] of 981 | 25/25 = 1.0 [0.867, 1.0] of 371 |
| feature_envy | 3/25 = 0.12 [0.042, 0.3] of 226 | 11/25 = 0.44 [0.267, 0.629] of 34 |
| nil_check | 4/25 = 0.16 [0.064, 0.347] of 275 | 7/25 = 0.28 [0.143, 0.476] of 111 |
| manual_dispatch | 5/25 = 0.2 [0.089, 0.391] of 147 | 9/25 = 0.36 [0.202, 0.555] of 29 |
| duplication | 16/25 = 0.64 [0.445, 0.798] of 401 | 17/25 = 0.68 [0.484, 0.828] of 444 |
| control_parameter | 5/15 = 0.333 [0.152, 0.583] of 105 | 12/15 = 0.8 [0.548, 0.93] of 21 |
| utility_function | 15/15 = 1.0 [0.796, 1.0] of 70 | 15/15 = 1.0 [0.796, 1.0] of 70 |
| data_clump | 12/15 = 0.8 [0.548, 0.93] of 54 | 12/15 = 0.8 [0.548, 0.93] of 54 |
| state_sprawl | 8/15 = 0.533 [0.301, 0.752] of 46 | 10/15 = 0.667 [0.417, 0.848] of 36 |
| repeated_conditional | 12/15 = 0.8 [0.548, 0.93] of 33 | 12/15 = 0.8 [0.548, 0.93] of 33 |
| indirection | — | 15/20 = 0.75 [0.531, 0.888] of 327 |

## Indirection, calibrated

`indirection` fires when a method's trace (its single-use helpers read in
place) scores at least the complexity threshold, 10, while the method alone
scores less. The threshold is the complexity threshold on purpose: a trace
that would be flagged written as one method is flagged written as six.

| codebase | kLOC | traces | p50 score | p90 | max | helpers p50 | depth 1/2/3/4+ |
| --- | --- | --- | --- | --- | --- | --- | --- |
| hashira (`lib`) | 6.4 | 7 | 11 | 12 | 12 | 4 | 1/3/3/0 |
| kimera (`lib`) | 9.6 | 6 | 14 | 23 | 23 | 7 | 1/1/1/3 |
| rubocop-kata (`lib`) | 1.0 | 3 | 17 | 21 | 21 | 10 | 0/0/2/1 |
| rubocop (`lib`) | 82.9 | 303 | 15 | 30 | 77 | 4 | 69/136/68/30 |
| faraday | 3.2 | 6 | 16 | 40 | 40 | 4 | 2/2/2/0 |
| rubygems.org | 20.7 | 18 | 16 | 48 | 65 | 4 | 6/5/6/1 |

hashira's own seven are recorded in its baseline, so the ratchet holds them by
score. On the labelled rubocop/faraday/rubygems.org sample, 15 of 20 are true;
the five false ones are traces that only just reach 10 through well-named
predicates.

## Known limits

- nil_check is still the least precise kind (7 of 25): most nil checks in
  AST-heavy code test an optional child or a pattern match, and the
  provenance rule cannot tell a meaningful absence from a designable one.
- manual_dispatch (9 of 25) and feature_envy (11 of 25) still name a class
  from a variable's name; a name that collides with an owned class
  (`loc` and a `Loc` struct) can mislead it.
- Recall fell with precision. Envy toward an ActiveRecord model through
  columns its class does not declare, nil checks on public arguments, and
  flags no caller in the codebase passes are no longer reported.
- The labels were written by the agent that wrote the rules; the owner's
  blind relabel is the real measurement.
