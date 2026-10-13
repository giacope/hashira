# Fragmentation: a blind readability study

`fragmentation` was set from what readers judged, not from a metric chosen in
advance. This folder holds the study.

## Method

Each item is one entry method shown with every same-class method it reaches,
rendered as one class excerpt (comments stripped, at most 120 lines, at most
one entry per class). An entry is a public `def`, not `initialize` or
`method_missing`, that reaches at least two same-class methods along a path at
least two deep. Half the items come from the house style, kimera and hashira
on `main` (15 each), and half from a control group: rubocop (`lib`), faraday
(`lib`) and rubygems.org (`app`, `lib`), 10 each. `build.rb` draws the items
deterministically (seed 42 for sample 1, 1729 for sample 2, which also leaves
out every sample-1 entry). `items.json` is what the raters saw: an id and the
code, with no source, path or group. `key.json` maps each id to its source,
entry and metrics.

Two raters judged each item on its own. They were independent AI reviewers:
separate model instances that saw only the shuffled items (an id and the code),
not their sources, hashira's code or the rule. No human has rated the items yet.
They scored readability (1 to 5), name clarity (1 to 5), whether the method is
over-fragmented (yes or no), and a one-line summary of what it does, which
checks that they read it (`rater1.json`, `rater2.json`).

## Results

| | sample 1 | sample 2 |
| --- | --- | --- |
| items | 60 | 60 |
| raters agree on over-fragmented | 55/60 (κ 0.78) | 54/60 (κ 0.74) |
| house style judged over-fragmented, rater 1 / rater 2 | 15/30, 14/30 | 16/30, 14/30 |
| control judged over-fragmented | 2/30, 0/30 | 1/30, 1/30 |
| readability, house / control (mean of both raters) | 3.0 / 3.9 | 2.95 / 4.0 |
| name clarity, house / control | 2.5 / 4.1 | 2.7 / 4.1 |

## The first rule, calibrated on sample 1 and validated on sample 2

An entry is fragmented when it reaches at least 4 same-class methods and the
entry and those methods average at most 3.5 non-blank, comment-free lines.
`key.json` records both numbers per item. The limits were chosen on sample 1;
sample 2 was drawn afterwards and scored once.

| | sample 1 (calibration) | sample 2 (validation) |
| --- | --- | --- |
| flagged | 13 | 13 |
| against both raters agreeing: precision, recall | 11/13, 11/13 (0.85, 0.85) | 9/13, 9/13 (0.69, 0.69) |
| against either rater: precision, recall | 13/13, 13/18 (1.0, 0.72) | 12/13, 12/19 (0.92, 0.63) |

The rule picks out fragmented methods within the house style, not just the
style itself. Of the house items it flags, a rater judged 12 of 12 (sample 1)
and 11 of 12 (sample 2) over-fragmented. Of the house items it leaves alone, a
rater judged 4 of 18 and 6 of 18 over-fragmented.

Over every eligible entry, this first rule flagged 75 of 217 in kimera (35%)
and 143 of 233 in hashira (61%) on `main`, but 3 of 708 in rubocop, 0 of 39 in
faraday and 2 of 135 in rubygems.org.

## Dogfood: named predicates are not fragmentation

rubocop-kata refactored its 21 findings of the first rule away, merging helpers
into their entries. Two blind AI reviewers then compared 9 before-and-after
pairs, not told which was which. They preferred the refactored version in 4 and
the original in 4, agreeing each time, and split on 1. Every loss had the same
cause: the merge removed a helper that was a named predicate (`deferred?`,
`raised?`, `guard?`, `alone?`, `bare?`, "exactly one read"), which the
reviewers read as meaning rather than fragmentation.

So the rule now leaves predicates (helpers whose names end in `?`) out of the
helper count. The depth and mean-lines conditions are unchanged; predicates
still count towards the mean and are listed in the evidence as not counted.
Re-scored on both samples:

| | sample 1 (calibration) | sample 2 (validation) |
| --- | --- | --- |
| flagged | 9 | 10 |
| against both raters agreeing: precision, recall | 9/9, 9/13 (1.0, 0.69) | 8/10, 8/13 (0.80, 0.62) |
| against either rater: precision, recall | 9/9, 9/18 (1.0, 0.50) | 9/10, 9/19 (0.90, 0.47) |

Precision is what a kind that is on by default needs, and it rises against
both raters agreeing; recall falls. Over every eligible entry on `main`, the
rule now flags 65 of 217 in kimera (30%), 121 of 233 in hashira (52%), 1 of 708
in rubocop, 0 of 39 in faraday and 0 of 135 in rubygems.org. hashira's
implementation reproduces the study's extraction exactly on all five.

## Caveat: the blinding is partial

The raters did not see sources or groups, but the house style is recognisable:
endless one-line methods, one-word names, no comments. A rater who recognised
it could judge the style rather than the method. The within-style figures above
are the check against that: the rule separates fragmented from
unfragmented methods inside the house style too. The two samples share their
raters, so the validation is out of sample for the items, not for the raters.
Until a human rates the items, these are AI reviewers' judgements.
