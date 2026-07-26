# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Duplication: a listing interrupted by a statement of another shape is no
  longer windowed as a clone. The rule applied only when an entire sibling run
  was homogeneous, so one trailing `module` after a block of requires — or a
  `banner =` before a run of `o.on` calls — put the whole list back in scope.
  Listings are now the maximal same-shape stretches within a run, and they are
  opaque: no window reaches into one, so a list row never lends its mass to the
  statements beside it. Two files ending a require block with `module Foo` no
  longer match on the tail of the block, and a genuine clone next to a list is
  weighed on its own size rather than the list's.
- Duplication: a near-miss neighbour no longer buries the exact clone pair
  inside its cluster. Exact matches and near misses are unioned into one
  cluster, which is then judged as a whole — so a single fuzzy member raised the
  mass floor from 16 to 40 and took the exact pair down with it, and adding a
  third, sloppier copy of a duplicated method made the finding disappear. A
  cluster that misses the raised floor now falls back to its identically shaped
  core and is weighed again on the floor that evidence earns.

## [0.2.0] - 2026-07-25

### Added

- Cognitive-complexity analyzer (AST-only): per-method scores
  ranked by readability rather than by call count, the call count shown beside
  each score, and a per-class rollup that survives extract-method.
- `complexity` findings for methods over the threshold, each with a per-source-line
  breakdown and a suggested refactoring; gate on them with `--fail-on complexity`.
- Duplication analyzer (structural clone detection, AST-only): statement
  windows from one statement up, whole methods, `when` arms and `rescue` clauses,
  matched exactly and by
  near-miss (Type-3 clones, via an inverted index over rare token types and an LCS
  check), unioned into clusters rather than pairs, each reduced to its maximal
  non-overlapping sites. Runs of identically shaped statements — require blocks,
  routes files — are read as lists, not clones. Window length is capped, so the
  candidate count stays linear in the length of a statement sequence. A match
  whose sites share no name at all is held to a much higher mass floor: identical
  trees collide by coincidence, and structure alone is thin evidence.
- `duplication` findings that classify what varies across a cluster (literals,
  receiver/message, constant, or control flow) into a refactoring, with a git-churn
  overlay when available; gate on them with `--fail-on duplication`.
- Hotspot rollup: the per-file join of cognitive complexity, the mass of the clones
  a file carries, and git churn, ranked by `(cognitive + duplication) × churn` — the
  files that cost the most and change the most, worst first. A ranked work queue
  rather than a letter grade. Churn floors at one, so a repo with no git history
  ranks by cost alone instead of collapsing to zero.
- `--skip` drops any analyzer (`coupling`, `complexity`, `duplication`); all run by
  default. Complexity, duplication and hotspot metrics are included in `--json`
  output; the rollup is omitted when both analyzers feeding it are skipped.

- `--ratchet` now guards findings as well as edges. The baseline (schema v2) records
  a signature per finding, and the build fails when the set grows — printing each new
  finding in full, with its evidence. Improvements fail too, and say so, because an
  unrecorded gain is one the next commit can undo. Measures direction, not level: no
  score to chase, and no need to start from a clean codebase.
- Findings carry a positionless `digest` where they have one. A clone is identified
  by the shape of its canonical fragment rather than by `file:line`, so both a
  baseline entry and an `accepted` entry survive the lines above it moving.

### Changed

- The three analyzers share a single parse of the source, so running them together
  costs no more than parsing once; complexity and duplication are computed lazily,
  so skipping one costs nothing.

### Fixed

- An `accepted` entry for a duplication finding matched on `file:line`, so it stopped
  matching — and the finding came back — as soon as anything above the clone moved.
  Clones are now accepted by `digest`.

## [0.1.0] - 2026-07-19

### Added

- Package (layer) metrics from the AST via Prism: TC, Ca, Ce, instability, cycles.
- Plain-English findings with file-level evidence, each stating something
  provable from the AST: cycles and SDP violations.
- CI gate (`--fail-on cycles,sdp`) and edge-set ratchet (`--ratchet`,
  `--update-baseline`), with accepted-by-design findings recorded in the
  baseline.
- Output formats: text, JSON, Graphviz dot, Mermaid (`--format`, `--json`).
- `--help` and `--version`.

[0.2.0]: https://github.com/giacope/hashira/releases/tag/v0.2.0
[0.1.0]: https://github.com/giacope/hashira/releases/tag/v0.1.0
