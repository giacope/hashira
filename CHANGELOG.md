# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `mixed_audience` coupling finding: a package whose constants split into
  parts with disjoint client bases — one set of packages leaning on one slice,
  another set on another — is separate packages in disguise. Detected from
  constant-level inbound references: clients whose touched constants overlap
  merge into one audience; constants used by a strict majority of clients are
  set aside as the shared base layer; two or more remaining parts of at least
  two constants each name the seam. Gate with `--fail-on mixed_audience`.
  Hashira's first run on itself flagged its own oldest namespace, `analysis` —
  and the split below dissolved it.

### Changed

- **Breaking:** the coupling machinery moved out of `Hashira::Analysis` into
  `Hashira::Coupling` (`Graph`, `Census`, `Cycles`, the structural findings,
  packaging and resolution), matching the `--skip coupling` analyzer name.
  `Hashira::Analysis` now holds only the substrate every analyzer shares:
  `Syntax`, `NodeWalk`, `TypeWalk`, and `Finding`. Exactly the seam the new
  `mixed_audience` finding pointed at; hashira now gates itself with
  `--fail-on cycles,sdp,mixed_audience` and an empty-findings baseline.

## [0.4.0] - 2026-08-02

### Added

- Code smells analyzer: eleven design smells — the object-relationship kinds
  no line count sees —
  `control_parameter`, `data_clump`, `duplicate_method_call`, `feature_envy`,
  `instance_variable_assumption`, `manual_dispatch`, `module_initialize`,
  `nil_check`, `repeated_conditional`, `too_many_instance_variables`, and
  `utility_function` — reported as findings with file:line evidence, gated and
  ratcheted like every other kind. On by default; `--skip smells` drops the
  analyzer; `--fail-on smells` gates all eleven, or name a single kind
  (`--fail-on feature_envy`). `@x ||=` memoization counts neither as class
  state nor as an ivar assumption, `module_function` methods are exempt, and
  `utility_function` flags public instance methods only. Methods born inside
  blocks or `class << self` are seen like any other, and safe navigation
  counts wherever a plain call would.

- Rails awareness. A directory with `config/application.rb` inside it (the
  Rails root) or beside it (its `app` folder) is detected as a Rails app:
  coupling defaults to namespace packaging, and under namespace packaging
  references to app-defined `Application*` base classes (`ApplicationRecord`,
  `ApplicationJob`, `ApplicationSerializer`, `ApplicationPolicy`, …) are
  skipped as framework plumbing. An explicit `--package-by folder` keeps the
  full legacy edge set, `Application*` references included.
- Baselines record their packaging mode (schema v3; older baselines read as
  folder). `--ratchet` refuses a baseline recorded under another mode with
  instructions to rerun with `--package-by <recorded>` or refresh via
  `--update-baseline`, instead of failing every edge as drift after the
  Rails default flips packaging.
- `--package-by folder|namespace`. Namespace packaging groups types by
  top-level constant (`Billing`, `Ci`, `User`) across layer folders, so the
  coupling tables and findings answer the domain question — does `Billing`
  reach into `Ci`? — instead of restating Rails layout (`models -> jobs`).
  Folder packaging stays the default outside Rails and remains available
  everywhere via the flag.

### Changed

- **Breaking (Ruby API only; the CLI is unchanged.)** Names throughout the
  library are now single-word, following rubocop-elegant: `Graph#dependents_of`
  is `#incoming`, `Graph#edge_list` is `#edges`, `Project#package_for` is
  `#package`, `Churn.from_git` is `Churn.scan`, and `Similarity#at_least?` is
  `#meets?`. Cycle queries moved off `Graph` onto `Graph#cycles`:
  `graph.cyclic?(p)`, `graph.cycle(p)`, and `graph.weakest(path)` are now
  `graph.cycles.through?(p)`, `graph.cycles.path(p)`, and
  `graph.cycles.weakest(path)`.
- One cycle finding per distinct loop, reported from its smallest member,
  instead of one per participating package.
- Under namespace packaging, a top-level class that anchors no namespace of
  its own and inherits from an app-defined class folds into its base's
  package, transitively — a flat family of notification subclasses reports
  as one package, not twenty.
- Past 25 rows, the metrics table hides single-type packages with no
  outgoing edges and at most one incoming behind a count line; they stay in
  the graph, so their afferent weight still counts. A heavily depended-upon
  package (high Ca) always keeps its row — its stability is the point of
  the table.
- Under namespace packaging in a Rails app, a singleton class named by
  convention (`SandboxResource`, `UserSerializer`, `AccountPolicy`,
  `PlanDecorator`) folds into its domain's package when that package exists;
  an app-defined superclass still takes precedence over the name.
- Every fold is disclosed: a `Folded` list under the coupling tables and a
  `folds` array in `--json`, each entry naming the fold and whether it came
  from a base class or a naming suffix.
- Classes count toward TC even when their body is pure DSL (Alba resources,
  notifiers); only modules still need a directly defined method.

### Fixed

- References into `Application*` namespaces (`ApplicationCable::Channel`)
  are skipped in Rails apps like the bases themselves, and no longer pull
  channels into a plumbing package.
- A proper prefix of a reference only matches exact definition paths: with
  an app-defined `Billing::Stripe`, the gem constant `Stripe::RateLimitError`
  no longer resolves to `Billing` when `RateLimitError` is unknown.
  Whole-reference suffix shorthand is untouched.
- Constants resolve through their lexical nesting, like Ruby. A bare
  `Authentication` inside `class User` now resolves to `User::Authentication`
  before a top-level `Authentication` in another package, superclasses
  resolve in the enclosing scope (but are charged to the class they define),
  and a scoped hit claimed by several packages resolves to nothing rather
  than falling through to a namesake. Kills phantom cross-package edges in
  Rails apps, where nested concerns routinely shadow top-level names.
- `::`-anchored references resolve at top level only, like Ruby: `::User`
  inside `module Admin` binds to the top-level `User`, never a nested
  `Admin::User` namesake.
- A constant under a namespaced class (`Invoice::STATES` with
  `Admin::Invoice` defined, referenced inside `Admin`) resolves through the
  enclosing scope by longest registered prefix, so the edge to the class's
  package is kept.
- A compact reopen (`class Foo::Bar` inside `module Baz`) anchors its root
  like Ruby — innermost enclosing scope that defines it, else top level —
  so its types and references are charged to `Foo`, not `Baz`.
- A class reopened across files counts once toward TC, and a lone subclass
  reopened in a later-sorting file keeps its base fold; fold results no
  longer depend on file order.
- Mutually-linked folds (a base fold one way, a suffix fold the other)
  merge into one package instead of swapping the two packages' identities,
  and a fold link from a package to itself is dropped instead of being
  disclosed as `X -> X`.
- A superclass resolves only against registered definition paths: a bare
  `Base` no longer folds its subclass into an unrelated `Admin::Base`
  matched by suffix shorthand.
- Namespace-prefix inference votes with every distinct definition path and
  requires a wrapper to enclose all of them, so a domain namespace sharing
  a single folder with top-level classes is kept as a package instead of
  being stripped as a gem wrapper.
- `--package-by auto` is accepted as the explicit spelling of the default.

## [0.3.0] - 2026-07-26

### Changed

- Package boundaries are found at any depth. Directory detection descends
  single-folder wrapper chains (`lib` → `lib/gem` → `lib/gem/core`), so
  `hashira`, `hashira lib`, and `hashira lib/gem/core` land on the same
  boundaries; descent stops at loose code files. Constant resolution now
  strips the inferred shared namespace *prefix* (majority per level across
  packages) instead of a single root module, so analyzing a nested subtree
  resolves cross-package references instead of silently reporting no edges.
- With several directories, same-named subfolders no longer merge into one
  package: a contested name is qualified by its directory (`app/models` vs
  `lib/models`); unique names stay short.
- Constant resolution is path-based. Each definition registers its full
  constant path and its suffixes as shorthand; a sighting resolves by longest
  match, and a name claimed by several packages resolves to nothing rather
  than to the last one parsed. A namespace mirrored across layers
  (`Admin::Account` in `app/models/admin`, `Admin::AccountsController` in
  `app/controllers/admin`) now attributes each reference to the right side —
  a model reaching into its controller layer shows up as an edge (and a
  cycle) instead of vanishing as a self-reference — and a bare reference to
  a name declared in exactly one package (`Skill.all`) now counts.

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

[0.4.0]: https://github.com/giacope/hashira/releases/tag/v0.4.0
[0.3.0]: https://github.com/giacope/hashira/releases/tag/v0.3.0
[0.2.0]: https://github.com/giacope/hashira/releases/tag/v0.2.0
[0.1.0]: https://github.com/giacope/hashira/releases/tag/v0.1.0
