# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Constraints: tell hashira which Ruby escape hatches your code forbids.** A
  project may write a `.hashira.yml` naming facts about the Ruby subset it keeps
  to, each scoped to a directory:

  ```yaml
  constraints:
    - fact: no_method_missing
      scope: lib/
    - fact: no_define_method
      scope: lib/
  ```

  Constraints describe your Ruby, never your architecture — hashira reads
  registries, hierarchies and handlers from the code, and stays silent when
  either the code or the constraint leaves the intent unclear. hashira owns the
  closed list of five facts — `no_method_missing`, `no_define_method`, `no_eval`,
  `no_const_missing`, `no_refinements` — and what each one means, and checks every declaration
  against the source it already parses: a contradiction stops the run naming the
  line that broke it (`constraint no_method_missing is contradicted by
  lib/gem/proxy.rb:17`), as does an unknown fact or a scope that is not a
  directory. RuboCop is not read, run, or imitated. A project without a
  `.hashira.yml` gets exactly the behaviour and output it got before.
- **Ten gated smells.** Each names the facts it needs, and hashira runs it only
  where the declarations cover every file the run parses. Each reports a concrete
  counterexample — a name, a signature, a line — rather than a rule it
  disapproves of, and each stays silent wherever the code leaves the intent
  ambiguous: `registry_gap`, `abstract_stub_gap`, `private_override`,
  `override_arity_mismatch`, `dead_method`, `mixin_collision`,
  `unchained_initialize`, `hierarchy_dispatch`, `unanswered_message`, and
  `unreachable_rescue`. They gate and ratchet like every other smell —
  `--fail-on smells` covers them, or name one.
- **registry_gap, the first gated smell.** Needs `no_method_missing` and
  `no_define_method`, and runs only where the declarations cover every file the
  run parses. It reports a frozen literal table of handler names, dispatched
  through `send` on the object's own self, that routes a key to a method nothing
  in the class, its ancestors, or its subclasses defines — an entry that raises
  `NoMethodError` the first time its key turns up. Silent when the table is
  unfrozen or built from anything but literals, when the values are not method
  names, when the send goes to another object, or when the class inherits
  something the project cannot see. It gates and ratchets like every other smell.
- **The effective constraint scope is part of the baseline's identity** — fact
  name, hashira's own version of that fact, and the normalized scope. Adding,
  changing, or removing a constraint asks for `--update-baseline` instead of
  reporting findings that appeared or vanished on their own. Schema version 6;
  baselines recorded without constraints keep working untouched.
- **Findings carry the files they came from.** Every finding now records its
  source files as data, so `--only` selects on that list instead of matching
  paths out of the rendered message, and `--json` exposes it as `sources`.

### Fixed

- **One immutable source snapshot per run.** The file list is settled and every
  file read once, before the first parse; parsing and reporting both work from
  that snapshot. A file written while hashira runs can no longer change which
  files the report says it counted.
- **A graph lookup stops inventing what it was asked about.** `EdgeMap` answered
  a missing key by creating it, so asking for the weight of a pair with no
  edges, or the neighbours of a package that is not in the graph, added it —
  `packages` grew as the report walked it. Reads no longer write.
- **The duplication pre-filter counts a repeated token once.** `Similarity`
  re-tallied the right-hand side on every token, so its cheap upper bound spent
  one token as many times as the left repeated it, and let pairs through that
  could never meet the threshold. Tallied once, the bound is the multiset
  overlap it always claimed to be.
- **`--format dot` escapes its identifiers.** A package name carrying a quote or
  a backslash broke the graph it drew.

## [0.9.0] - 2026-08-20

### Fixed

- **A rename stops reading as churn in the ratchet.** A finding is keyed by what
  it names, so renaming a class reported the twelve findings under it as
  resolved and new at once, and adding `?` to four predicates did the same. The
  baseline now records a `traces` map beside `findings` — for each finding, the
  file it sits in and what its evidence says, with line numbers stripped — and
  the ratchet pairs a disappeared key with an appeared one carrying the same
  trace. The match is one for one, so a rename that brought a new finding along
  still fails, and a renamed method that also got worse still reports WORSE.
  Acceptance is untouched: `accepted` entries still name a finding by `package`
  or `digest`. Baselines recorded before this have no traces and behave exactly
  as they did; the next `--update-baseline` writes them (schema version 5, which
  older hashira reads too).
- **A shared namespace stops passing for a shared name.** The duplication
  near-miss guard raises the mass floor when two sites have no name in common —
  but `Prism::CallNode` and `Prism::BlockParameterNode` counted `Prism` as
  common, so two unrelated one-liners that both mention a Prism class slipped
  under the low floor. A constant is now read by what it points at, not the
  namespace it sits in.
- **A nested class is named the way Ruby resolves it.** `class Widget::Broken`
  written inside `class Widget` was reported as `Widget::Widget::Broken`. The
  smell census now resolves a compound constant path against the constants the
  codebase actually declares, the way the coupling graph already did. Findings
  on such classes change name, so a baseline recorded before this reports them
  once as resolved-and-new; re-record it with `--update-baseline`.

### Changed

- **`duplicate_method_call` stops flagging calls that are supposed to differ.**
  `stdout = "".b` next to `stderr = "".b` is two buffers, and
  `rand(1_000_000_000)` twice is two ids — naming either once writes a bug. The
  check now excuses calls that mint a fresh value each time (`new`, `dup`,
  `clone`, `allocate`, `rand`, anything from `SecureRandom` or `Random`, and
  any call on a literal) and repeats that no single run can reach twice: the
  two arms of an `if` or `unless`, two `when` or `in` branches, a body and its
  `rescue`. Nothing can be hoisted across those, and a `raise` has no result to
  name.
- **`instance_variable_assumption` asks whether anything assigns, not whether
  `initialize` does.** Assignment through a mixin, a superclass, an
  `attr_writer`, a reopening of the class, or a private method the constructor
  calls all count now — every shape that made the old check report a class that
  was perfectly fine. What survives is the ivar nothing the class can reach ever
  sets: a typo, or state another object is expected to install. When a class
  inherits or includes something the codebase can't see, the check stays quiet
  rather than guess.
- **A run of declarative macros is a schema, not a clone.** Two models opening
  with the same `has_many ..., dependent: :destroy` lines, or two serializers
  with the same `typelize`/`attribute` pairs, were reported as duplication whose
  only fix was to hide the schema behind a class method. A fragment built purely
  from directives — receiverless calls with literal arguments — no longer
  clusters. A block, a method, a variable, a receiver, or a branch anywhere in
  the fragment makes it code again.

## [0.8.0] - 2026-08-15

### Added

- **`--only PATHS` narrows the findings to the files you name.** Meant for
  hooks: after a formatter, a refactor, or an agent's edit, ask whether *these*
  files got worse — `hashira --only "$CHANGED" --ratchet`. The whole project is
  still parsed, because half of what hashira knows is cross-file (which
  constants are yours, which methods reach into a neighbour, which fragments
  are clones); reading one file alone would answer differently. A focused
  ratchet stays quiet about package edges, which belong to no single file, and
  about findings that disappeared, which only a whole-project run can confirm —
  it reports what your files introduced or made worse. `--only` refuses
  `--update-baseline` and the diagram formats, and ignores paths outside the
  analyzed directories so a hook can hand it every changed file.

### Changed

- **Memoization stops reading as state.** An instance variable named `@_thing`
  is a cache, not a responsibility: `instance_variable_assumption` no longer
  reports lazy presence as an assumption, and `too_many_instance_variables`
  no longer counts derived values against the class. Codebases that memoize
  behind the `@_` convention will see both smells quieten; codebases that
  don't are unaffected.
- **Every object is built the way this tool says to build one.** Constructors
  only assign, class-method logic dissolves into instances (`Project.detect`
  and `CLI.run` are plain constructors — `exe/hashira` now calls
  `CLI.new(argv).status`), factories are named `build`, and hashes acting as
  objects got names (`SdpViolationFindings::Imbalance`,
  `DuplicationFinding::Overlap`, `MethodFinding::Effort`). Internal
  throughout: the command line, the reports, the JSON, and the baseline
  format are unchanged. Only embedders calling the Ruby API directly are
  affected.
- Coupling reads its rule list from `Rule.subclasses`, the way the smells
  report already read `Check.subclasses`, and parameters stop carrying their
  node type (`def_node` → `definition`). hashira's own baseline is down to
  zero findings and one accepted boundary.

## [0.7.0] - 2026-08-10

### Added

- **The ratchet compares magnitudes, not just identities.** The baseline now
  records a value beside each finding's signature — cognitive complexity,
  clone-cluster mass — so a baselined method that gets measurably worse fails
  the build instead of hiding behind set membership. On a legacy codebase this
  is the case the ratchet exists for: everything hot is already baselined on
  day one.
- **Exit codes stop meaning six different things.** 0 clean, 1 findings or a
  caught regression, 2 misuse, 3 an improvement the baseline has not recorded,
  70 internal error. Failing on 1 while treating 3 as a nudge blocks
  regressions without blocking progress. Unexpected exceptions now print the
  class, message, origin frame, and where to report — not a backtrace.
- **The report says what produced it.** The heading names the packaging mode,
  files Ruby itself rejects are counted and named on stderr instead of
  contributing half-parsed trees silently, and a terminal run shows a sign of
  life before the parse and a timing line after (never when stderr is not a
  tty — stdout stays byte-identical).
- `--top N` caps every list at once; the package table and findings list gain
  a default cap of 25 with a note saying what was withheld. `--json` is never
  capped.
- `--compact` emits `--json` on one line instead of pretty-printed
  indentation, and `--json` now opens with schema version, packaging, targets,
  and file count.

### Fixed

- **Green no longer means unchecked.** `--fail-on ""` armed nothing and
  passed; `--fail-on cycles --skip coupling` switched off the only analyzer
  that finds cycles and announced there were none; a directory with no Ruby
  files was congratulated on its healthy structure. All three now fail
  loudly.
- **The baseline guards the whole scope it was recorded under.** A baseline
  recorded over four analyzers, compared against a run with `--skip smells`,
  reported every smell finding as an improvement and suggested locking it in.
  Schema 4 records analyzers and target directories, and the ratchet refuses
  a mismatched run the same way the packaging guard already did.
- Churn runs `git -C <directory>` instead of reading the working directory,
  so analyzing a repo from anywhere else no longer zeroes every count and
  silently reorders the hotspot queue. A run with no history says so; an
  unreadable baseline is a one-line error, not nine frames of Ruby.
- Five CLI misreadings: a file argument is named as a file (with the
  directory to try), duplicate directories are deduplicated by realpath, a
  gem whose lib holds only loose files is accepted, a value flag given twice
  is not "unknown", and a diagram whose analyzer is skipped is refused
  instead of drawn anyway.
- Diagrams stop losing packages: mermaid/dot ids are generated so `my-pkg`
  and `my_pkg` no longer merge (and a package named `end` no longer breaks
  the grammar), and isolated packages appear instead of vanishing.
- `Gate FAILED` names the kinds that actually fired, worst first, mirrored to
  stderr; `--update-baseline` and `--ratchet` no longer report contradictory
  totals for the same run.
- Tables size their columns to their contents: long names clip in the middle
  instead of pushing rows into ribbons, numeric columns right-align, and
  trailing whitespace is gone.
- An edgeless package prints "—" and sorts last instead of claiming I=0.00
  beside genuine foundations.

### Changed

- The four house cops and shared style defaults moved to the published
  `rubocop-kata` gem; `.rubocop.yml` keeps only project-specific config.
- Docs: the `--fail-on` shorthands (`cycles`, `sdp`, `dupe`) are documented,
  and a bare `hashira` in a Rails root notes once on stderr that `hashira app`
  reads the application.

## [0.6.0] - 2026-08-05

### Changed

- **feature_envy now respects ownership.** The classic remedy — move the
  method onto the envied object — assumes the envied class is yours to edit.
  The smell now stays quiet when the method body itself proves otherwise:
  the name is type-guarded only against constants the analyzed code never
  defines (`node.is_a?(Prism::CallNode)`); every call on it is a literal-key
  read (`msg["id"]`, `values_at`, `dig`, `key?` — wire data, not an object);
  it was built from a literal in the method itself (`options = { ... }`); it
  was derived by calling a foreign name or foreign constant
  (`value = node.unescaped`, `app = Rails.application`); it was rescued from
  a foreign or implied error class (`rescue => e`); the method dispatches on
  it through a constant table keyed entirely by foreign classes
  (`TABLE[node.class]`); or the method is a stateless converter whose last
  act is building a typed object. Guards against types the codebase does
  define — including by suffix, and including subclasses of gem classes —
  still flag, as do rescues from error classes the codebase defines and
  tables keyed by owned classes, so anemic-model envy in Rails apps is
  untouched.

### Added

- **boundary_sprawl** — the aggregate the suppression above makes room for:
  when 12+ methods across 3+ files each type-guard against the same foreign
  root (`Prism`, `ActiveRecord`, ...), one finding proposes fronting that
  boundary with an adapter. One method inspecting a foreign type is a fact of
  life; a codebase-wide sprawl of them is a missing seam.

## [0.5.1] - 2026-08-05

### Fixed

- The churn scan passes `--no-renames` to `git log`, counting a move as a
  delete plus an add. Rename detection needs blob contents, so on a partial
  clone (`--filter=blob:none`) the old command lazy-fetched objects from the
  network one at a time — on a long history the scan stalled for minutes and
  looked like a hang. It also made the tally depend on which blobs git could
  see, so the same tree could report different churn (and different
  findings) run to run. A dogfood run against a large open-source app fell
  from 3m39s to under 9 seconds.
- A bare reference to a Ruby core constant (`String`, `Regexp`, `File`, …)
  no longer couples to whichever package defines a namespaced namesake such
  as `Sql::Nodes::Regexp` — Ruby would resolve it to the core class, so
  hashira now drops the edge. The registry answers these through `rooted`,
  which skips the shorthand tails: a lexical namesake still shadows the core
  name as Ruby's own lookup does, and a project that reopens the class at
  top level still owns it. Dogfooding against a large open-source library,
  this deleted a phantom `mixed_audience` finding built entirely on `Array`,
  `String`, and `File`.
- Constants assigned in a class body (`Node = Struct.new(:path)`) now join the
  census as definitions, so a bare reference resolves to the local constant
  instead of a foreign package's namesake — a karat run had minted two phantom
  edges this way. For usage counts they still collapse into their enclosing
  type: `wide_edge` measures classes, not the constants they carry.

## [0.5.0] - 2026-08-04

### Added

- `wide_edge` coupling finding: an edge carrying five or more distinct
  constants is an interface with that many reasons to change — front the
  target with one facade. Found from the same constant-level usage data as
  `mixed_audience`. Its first run flagged the pipeline's own five-constant
  reach into `coupling`, dissolved by the new `Coupling::Report` facade.
- `roll_call` coupling finding: a list of three or more words (symbols or
  string keys in array and hash literals) maintained by hand in three or more
  files across two or more packages is a registry in disguise. Its first run
  flagged the analyzer names synced between the pipeline, `--fail-on`, and the
  JSON report — dissolved by deriving `--fail-on` kinds from
  `Pipeline::ANALYZERS` and the coupling rule roster.
- `Hashira/ProsePlacement` cop: sentence-length string literals are presentation
  and belong under `report/` or `ci/` — domain classes pass data. All finding
  messages now render in `Report::Phrases` from structured `Finding#detail`;
  `Finding` no longer carries a `message` member (the JSON report still emits
  a phrased `message` per finding).
- Coverage floors raised to 100% line and 100% branch — and CI now gates
  `wide_edge` and `roll_call` alongside cycles, SDP, and mixed audiences.

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

[0.5.1]: https://github.com/giacope/hashira/releases/tag/v0.5.1
[0.5.0]: https://github.com/giacope/hashira/releases/tag/v0.5.0
[0.4.0]: https://github.com/giacope/hashira/releases/tag/v0.4.0
[0.3.0]: https://github.com/giacope/hashira/releases/tag/v0.3.0
[0.2.0]: https://github.com/giacope/hashira/releases/tag/v0.2.0
[0.1.0]: https://github.com/giacope/hashira/releases/tag/v0.1.0
