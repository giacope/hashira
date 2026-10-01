# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Found by running hashira against fifteen MIT-licensed Rails apps and gems
(rails, rubocop, chatwoot, feedbin, rubygems.org, huginn, …).

### Upgrading

Three changes move what a recorded baseline expects; run `--update-baseline`
once after upgrading, after reading what the ratchet reports:

- With several directories (every Rails app run as `hashira app lib`), paths
  are now named from where hashira runs, so every recorded path changes.
- Cycles are one finding per knot, keyed by its alphabetically first member.
- Complexity scores methods it could not see before (`private def`,
  `class << self`, `class_methods do`) and charges nesting for ternaries and
  rescue modifiers, so more methods cross the threshold.

Across the fifteen field repos, findings fell from 15,557 to 12,711. Every
true positive the earlier triage confirmed still fires.

### Added

- `--kind KINDS` keeps only the findings of the kinds named, in text and
  JSON, with the `--fail-on` names and shorthands (`cycles`, `sdp`, `dupe`,
  `smells`, or one smell). It narrows the way `--only` does: under
  `--ratchet` it judges only those kinds, leaving removals and edges to the
  full run, and it refuses `--update-baseline`, the diagram formats, a kind
  whose analyzer `--skip` drops, and a `--fail-on` kind it leaves out.
- JSON findings carry a `confidence`: `high` for measurements (complexity,
  the structural kinds, clones that differ in one narrow way), `medium` for
  patterns that turn on intent (every smell, clones that differ several
  ways), `low` where hashira already hedges (clones whose control flow
  differs). It is a category, not a probability.
- JSON gains `kinds`, each kind's count and the number of files it touches.
- When the text findings list is capped, a rollup above it states every
  kind once — `nil_check  113 in 92 files` — withheld findings included.

### Changed

- With several directories, every file is named as you would open it from
  where hashira runs: `app/models/user.rb`, `activerecord/lib/active_record/base.rb`.
  Paths were relative to each directory, so in rails `railtie.rb`,
  `callbacks.rb` and `test_case.rb` each named two or three files, their
  hotspot rows merged (activemodel's and activesupport's `callbacks.rb` became
  one row), and a Rails app's `lib/hoptoad/v2.rb` really meant
  `app/lib/hoptoad/v2.rb`. Findings, duplication sites, complexity rows,
  hotspots, churn and `--only` all use the same name. A single directory keeps
  its directory-relative names. **Multi-directory baselines (`hashira app lib`)
  need one `--update-baseline`**, since every recorded path changes.
- Folder packaging gives each directory's loose files their own root package
  (`lib/(root)`, `app/(root)`) when several are analyzed, instead of merging
  them all into one `(root)`.
- Single-folder wrapper chains are descended only when one directory is
  analyzed. Each of several directories was descended on its own, so in rails
  three gems dropped to `lib/<gem>` while nine stayed at `lib`, and package
  granularity differed from gem to gem. Rails now reads as 25 gem-level
  packages and 15 cycles (was 60 and 45).
- A bare `hashira` analyzes `lib/<gem>` when `lib/<gem>.rb` sits beside it,
  preferring the name a `*.gemspec` gives if `lib/` holds several. It used to
  stop at `lib/` whenever `lib/` also held `generators/`, `ruby_lsp/` or
  `helpers/`, so rubocop's 949 files read as 2 packages (now 13), devise 2
  (now 10), faker 2 (now 17).
- A bare `hashira` in a Rails root (`config/application.rb`) analyzes `app`
  and `lib` instead of printing a hint and reading `lib/` alone. The progress
  line on a terminal now names the directories it reads.
- Handed a file, hashira suggests a focused run (`hashira --only
  app/models/problem.rb`) instead of the file's folder, which silently
  changed the packages and the scope.
- `--only` accepts directories and expands them to every `.rb` file under
  them. It still refuses paths that do not exist, and an `--only` directory
  with no Ruby files, which would have reported everything.

- The findings list is dealt across kinds instead of grouped by kind: each
  round takes the next finding of every kind, structural kinds first, and
  each kind comes worst first where it has a size. The capped top 25 on
  rails, chatwoot and feedbin was all cycles; it now shows every kind
  found. JSON findings come in the same order.
- An explicit `--top N` caps the JSON's ranked lists too (findings,
  complexity methods and classes, duplication, hotspots) and adds
  `withheld`, how many rows each lost. The graph and `accepted` stay whole;
  without `--top` the JSON is uncapped as before.
- The dependency map honours `--top` and says how many rows it withheld.
  It leads with the most connected packages, and packages with no edges
  either way share one line instead of a row each — 341 lines on chatwoot.
- Cognitive complexity charges a ternary like an `if`: it pays for the
  nesting it sits at, and its arms nest one level deeper. A `x rescue y`
  modifier costs what a `rescue` clause does. Scores rise where ternaries
  and rescue modifiers nest; across fifteen field repos complexity findings
  went from 571 to 614.
- An unknown `--fail-on` kind reads like the other choice flags:
  `unknown --fail-on "typos" (use: …)`.

- **One cycle finding per knot.** A cycle used to be reported once for every
  package that could reach itself, so one 119-package tangle in chatwoot read
  as 104 findings ("Account can reach itself…", "AccountEmailRateLimitable
  can reach itself…"). Each strongly connected component is now reported
  once. The finding names its members and the cheapest cut, found by dropping
  the lightest edges until the knot splits and then putting back any edge the
  split did not need. The evidence is the references on the cut edges, which
  are the lines to change. Across fifteen field repos, cycle findings fell
  from 270 to 26.
  The finding's `detail` is now `{members:, cut: [{from:, to:, weight:}]}` in
  place of `{weak:, weight:}`. It is keyed by its alphabetically first member
  (`cycle:<member>`), so a two-package cycle keeps the key it had. For a
  larger knot, a saved baseline reports the other members' old `cycle:` keys
  as resolved. Re-record it with `--update-baseline`.

- `nil_check` words its advice for where the checked value came from. When
  the method itself read it from outside the program (a literal-key read
  such as `params[:id]` or `request.headers["X-Token"]`, or a call on a
  constant the codebase doesn't define, such as `JSON.parse`), it says to
  translate the missing value where it enters, at the boundary, rather than
  reach for a null object. Such findings are still reported, and their JSON
  `detail` carries `origin: "outside"` (or `"both"`).
- `module_initialize` gives a reason that holds even when the initializer
  calls `super`: a mixin that carries constructor state is implementation
  inheritance, so compose a collaborator. "Construction order becomes
  anyone's guess" was false for the cooperative initializers that are most
  of them.
- `assumed_state` says when the ivar a base class reads is one its own
  subclasses assign (`detail.installed`): a base class waiting for
  subclasses to install its state is a fragile base class, so pass the
  value in.
- The README now describes `manual_dispatch` as what it always checked: any
  `respond_to?`, not only `respond_to?` followed by `send`.

### Fixed

- Complexity scores every method a class body declares, not only its
  top-level `def`s: `private def` / `protected def`, methods inside
  `class << self` and `class_methods do` (named `Class.method`), behind an
  `if`, and in a `Const = Data.define do … end` block (owned by `Const`).
  They were invisible, so writing `private def` made a complexity
  regression vanish from the ratchet. Expect `--ratchet` to report methods
  it could not see before as new findings.
- Churn charges a file its own commits. It matched by bare file-name suffix
  across the whole repository and took the maximum, so rails'
  `action_view/base.rb` got activerecord's 1218 commits (its own: 352), a
  model took its spec's churn, and `base.rb` matched `database.rb`. Every
  analyzed directory's history is read now, not only the first one's.
- A clone is flagged "Both sites change often" only when two distinct files
  it spans change more often than the typical analyzed file (above the
  median commit count). Any committed file used to qualify, so the flag was
  on every clone in a git repository.

- Table cells under `file` and `Loc` are never clipped. A 48-character cap
  printed paths like `controllers/users/omnia…llbacks_controller.rb:58`
  that could not be opened; only names are clipped now.

- Constants resolve the way Ruby resolves them. Lookup goes through the
  lexical scopes first, then the superclass chain and the included or
  prepended modules of the innermost class, then top level. A bare name no
  longer falls back to any namespace that happens to end in it. In
  fat_free_crm, `I18n` in a top-level `ApplicationController` had resolved to
  `FatFreeCRM::I18n`, which accounted for 6 of 13 cycles and 8 of 12 SDP
  violations. The same fallback sent postal's `Process.exit` to
  `Worker::Process` (8 of 18 cycles). In rails it caught `Queue`,
  `ConnectionPool` and `Logger`'s inherited `ERROR`. A constant a class
  inherits from a superclass or mixin inside the project now resolves to that
  class's package.
- Ruby's core and standard-library constants are detected at runtime without
  loading anything. That covers constants with no Ruby source file, plus
  names that have a library on Ruby's own shelves. `Process` and `Set` used
  to slip through, and so did `JSON`, `Logger`, `URI` and `Date` whenever
  they were not loaded. Such a constant never belongs to a package that
  reopens it. rails' `core_ext` no longer owns `String`, `Hash` or `File`,
  which removes 28 of rails' 60 wide edges. What the project creates inside
  one, such as `Time::DATE_FORMATS` or a derived class, stays its own.
- A library namespace the project only patches is left to the library. Such a
  namespace is opened only in files not named for it, and the project derives
  no class inside it. Examples are huginn's `class Rufus::Scheduler` in
  `huginn_scheduler.rb` and actionpack's `module Rack` stub. `::Rack::BodyProxy`
  no longer resolves to `action_dispatch`, and `Mail` no longer resolves to
  `action_mailbox`.
- `self::VERSIONS`, `namespace::Service` and any other `expr::Const` are
  dynamic and stay unresolved. They were read as a bare constant, which made
  false cycles such as rubygems' `CompactIndexVersions` <-> `GemInfo`.
  hashira still walks the receiver expression.
- An SDP violation now needs a gap the report can show. Instabilities are
  compared at the two decimals the table prints, so "Feed (I=0.33) depends on
  LESS stable WebSub (I=0.33)" is no longer reported.

- Duplication stops reporting declarations as clones in more of their
  forms. A macro whose block holds only more declarations counts as one
  (`string :host do description "…"; default "…" end` — postal's config
  schema was that repo's top hotspot at cognitive 0), and so do constant
  arguments (`include Foo`), constants assigned a literal (`.freeze`
  included) and heredocs with nothing interpolated (rubocop's
  `def_node_matcher :x, <<~PATTERN`).
- A class or module is never a clone fragment of its own. Files that wrap
  similar code in the same `module Faker … end` matched as whole files; the
  body is now windowed like any other.
- Three or more identically shaped `when` arms in a row are a dispatch
  table, and follow the same list rule as a run of identical statements.
- Duplication labels say what actually differs. Method and parameter names,
  `||=` and other op-writes, constant assignments, regex text and `&.` were
  invisible to the diff, so "byte-for-byte identical" and "differs only in
  literal values" were often false. Copies that differ only in the method's
  name are now labelled as such, with their own advice; `&.` against `.` is
  a control-flow change (postal's `client.trace_id` / `client&.trace_id`
  was called identical).
- A smaller clone nested inside a bigger one is reported only when at least
  two of its copies lie outside it. One extra site kept whole families
  alive: rails' routing mapper `get`/`post`/`patch`/`put`/`delete` was five
  findings.
- Hotspots charge a file each cloned node once. The Dup column summed every
  cluster's site mass, so code shared by overlapping clusters was paid for
  again and again: rails' `routing/mapper.rb` was charged 3802 for 1766
  distinct nodes.
- A clone's range runs to the closing line of a heredoc it carries, and no
  longer opens on a bare `private` line heading the methods below it.

- feature_envy keeps the promise that it only speaks when the destination is
  yours: `x.m` counts only when `m` is a message the codebase publicly
  defines — a `def`, an `attr_*`, an `alias`, or a name a class body hands to
  a macro (`has_many :lines`, `delegate :total`, `Data.define(:x)`).
  Operators (`==`, `+`, `[]`), what every object answers (`to_s`, `is_a?`,
  `tap`) and `x += 1` never count. Across fifteen field-test repos this
  drops findings from 2,497 to 1,030 while every sampled true positive
  still fires.
- feature_envy tallies each variable binding on its own: three blocks that
  each name their parameter `r` are three variables, not one.
- feature_envy treats a block parameter handed over by a foreign constructor
  or call chain (`Faraday.new do |f|`, `Rails.application.tap { |app| }`)
  as foreign, and block parameters referenced together, as in a comparator
  (`sort { |a, b| ... }`), as peers rather than a destination.
- The feature_envy message states both counts ("more than to self, 3 to 1")
  and the evidence lists self's references, so the claim can be checked; a
  tie no longer names the first variable as the place the behavior belongs.
- utility_function reads polymorphism as polymorphism: a method an owned
  ancestor or descendant also defines, or that a sibling under the same
  superclass defines too (every job's `perform`), is not flagged.
  `extend self` modules are exempt like `module_function` ones. Findings
  drop from 980 to 612 on the field-test repos.
- Methods defined in `class_methods do` blocks and `ClassMethods` modules are
  class-level: every smell names them `Concern.method`, not
  `Concern#method` (or `Concern::ClassMethods#method`). A bare `private`
  inside `included do` no longer makes the rest of the module private, and
  `private def` inside `class << self` is no longer skipped.
- utility_function advice follows the owner: "make it a module function" for
  a module, "make it private" for a class.

- `control_parameter` no longer counts `param || default` or `param && x`
  as steering when the result is assigned, passed, or returned. Such a
  parameter is handed on as data, so it is no control parameter anywhere in
  the method. An `&&` standing alone as a statement (`flag && run`) or in a
  loop's condition still steers (832 → 670 findings on the fifteen repos).
- `manual_dispatch` skips `respond_to_missing?`, which Ruby requires of any
  class that uses `method_missing` and which has to ask `respond_to?`.
- `state_sprawl` doesn't count a memo predeclared as `@x = nil` and filled
  by `||=`, or one filled behind `return @x if defined?(@x)`, as state; the
  README already said memoization doesn't count. A `defined?`-tested flag
  still counts.
- `assumed_state` stays quiet when the class body (or a superclass's) calls
  a macro that neither Ruby nor the codebase defines, such as attr_extras'
  `pattr_initialize [:user]`, just as it already did for an unseen
  superclass or mixin, since the assignment may live in the macro
  (30 → 10 findings, 20 of them `pattr_initialize`).

- `repeated_call` flags repeated queries only. A call whose result the
  method throws away is a command (`render …`, `@out << row`, `raise`, a
  log line as a statement, the body of a loop or `ensure`), and repeating a
  command is deliberate; hashira reads that from the call's position in the
  AST, not from a list of method names. A call fed a freshly minted
  argument (`render(Row.new)`) no longer counts as identical, a call
  repeated only at the method's exits (`return head(:ok) unless …` twice,
  then `head :ok`) runs once per call and is left alone, and a repeated
  chain is listed once at its longest: `DateTime.now.utc × 3` no longer
  drags `DateTime.now × 3` along. On the fifteen field repos: 4689 → 4571
  findings, 7271 → 6424 evidence lines.
- `repeated_conditional` no longer treats one local variable name in
  different methods as the same test: feedbin's `Import` had `all == 0 × 4`
  across four methods with four different `all`s. A test that reads a local
  groups only within the method or block that binds it; tests on the
  object's own state still group across the class. Each line is listed
  once, in order (`lines 18, 18, 39` was possible). 238 → 144 findings.
- `data_clump` lists each clump at its widest: `(a, b)` is no longer listed
  beside `(a, b, c)` in the same finding (134 of 612 evidence rows).
- Class-level smells (data_clump, repeated_conditional, state_sprawl,
  assumed_state, module_initialize) judge a class across every file that
  opens it and report it once. rails' `FormBuilder`, reopened in three
  helper files, got three data_clump findings under one key.
- `boundary_sprawl` no longer reports classes built into Ruby (`String`,
  `Hash`, `Array`, `Proc`): 9 of its 12 field findings. A root counts as
  built in when hashira's own runtime defines it without a source file, so
  gems such as `Parser` or `Rubydex` still count.
- The ratchet no longer lets a new finding through as a rename. A finding
  that carries no evidence (utility_function, nil_check, manual_dispatch,
  module_initialize) left a trace of nothing but its kind and file, so
  fixing `Shop#tax` and adding a stateless `Shop#discount` in the same file
  paired the two and printed "unchanged". Such a finding is now traced by
  the code it names, its parameters and body without its name, so a method
  renamed with its body intact still pairs and a different method does not.
  Traces recorded for these kinds before this no longer match; the next
  `--update-baseline` rewrites them.
- `repeated_call` compares calls, not their text. A literal block is part of
  the call, so `kids.index { it.equal?(child) }` and `kids.index {
  it.equal?(assign) }` are two calls. A local counts by its binding, the way
  feature_envy already counted it: `it`, `_1` or `|list|` in two separate
  blocks are different variables, and a variable reassigned between two
  calls (`parent = parent.parent`, `count += 1`, a write inside a block or
  a loop) holds a different value in each.
- A duplication cluster whose copies sit under different method names and
  also differ inside no longer reads as "differs only in literal values —
  extract a method, pass them as arguments", which hid the names and
  proposed passing a callback's name (`on_class` / `on_module`) as an
  argument. It now says the names differ too, and advises keeping each
  name as a call into one shared method (kinds `renamed_literal`,
  `renamed_message`, `renamed_constant`, `renamed_mixed`; confidence
  `medium`, like `renamed`).
- `utility_function` stays quiet on a library's hooks. A class whose
  ancestry reaches a superclass or mixin the codebase does not define
  (`class Plugin < LintRoller::Plugin`) may be overriding methods the
  library calls, which can be neither made private nor moved; a public
  method there that nothing in the codebase calls (or names as a symbol) is
  read as such a hook. `LintRoller::Plugin#about` was flagged.

### Performance

- Duplication walks each statement's subtree once per file instead of once
  per window that holds it; smells read a class name's ancestry once instead
  of once per file that reopens it; churn lookups are exact instead of a
  scan over every path in history. Output is unchanged; a full run on
  rubocop drops from about 49s to 19s, and on rails from 93s to 43s.

## [0.10.1] - 2026-09-26

### Fixed

- `--ratchet` and `--update-baseline` no longer stop with an internal error
  when the locale isn't UTF-8 (e.g. `LANG` unset) and the baseline holds
  non-ASCII text, such as an em dash in an acceptance reason. The baseline is
  read and written as UTF-8 whatever the locale.
- A run no longer stops with an internal error when the locale isn't UTF-8,
  git's `core.quotepath` is off, and the history names a non-ASCII file.
  Churn matches file names byte for byte.
- Churn counts files whose names aren't ASCII. git quotes such names by
  default (`"caf\303\251.rb"`), so they never matched and scored 0.

Found by mutation-testing the suite with [kimera](https://rubygems.org/gems/kimera).

- An exact clone no longer disappears when one copy runs a statement longer:
  the near-miss window that absorbed it failed its floor and took the exact
  pair down with it. Two unrelated clones side by side are no longer trimmed
  to shorter windows either.
- The duplication pre-check is linear again. It re-tallied one side for every
  token, which was quadratic and never used a token up, so lopsided pairs paid
  for the full comparison. Results are unchanged.
- `unless … else` charges the `else` +1 that `if … else` does, and scores its
  condition at the same nesting.
- `feature_envy` counted `self.x` as two references to self, which hid real
  envy such as `self.rate * order.net + order.tax`.
- `assumed_state` no longer resolves a same-named superclass to the class
  itself (`class Thing < Thing` inside a module, `class User < ::User`), which
  reported ivars set in the real parent as assumed.
- `mixed_audience` shows evidence for an audience whose clients reach only
  nested constants (`Core::Walk::LIMIT`); such a part printed none.
- The worst-methods, per-class, and hotspot tables say how many rows `--top`
  withheld, as the package table and findings list already did.
- Hotspots charge each clone site the mass of its own copy, as the README
  says. Every site of a near-miss cluster was charged the canonical copy's
  mass, so a longer copy was under-charged and a shorter one over-charged.
- `feature_envy` reads `TABLE.fetch(x.class)` as table dispatch, as it
  already read `TABLE[x.class]`; a fetch-keyed guard was reported as envy.

## [0.10.0] - 2026-08-30

### Added

- **Interpreted foreign models are verified architecture, not accepted debt.**
  A baseline can declare a foreign root with `role: interpreted_model`, its one
  API entrypoint, and a reason. Type dispatch over that model no longer emits
  `boundary_sprawl`, while a missing root call or a call which bypasses the
  entrypoint is rejected as misuse. Baseline schema 6 preserves these
  declarations on `--update-baseline`. Hashira now declares Prism this way and
  dogfoods with zero findings and zero acceptances.

### Changed

- `boundary_sprawl` now distinguishes a missing adapter from a program which
  deliberately interprets a foreign data model. Undeclared foreign roots keep
  the same 12-method, 3-file threshold and behavior.

- Three smell kinds are renamed to name the smell, not the mechanism:
  `duplicate_method_call` is now `repeated_call`, `too_many_instance_variables`
  is `state_sprawl`, and `instance_variable_assumption` is `assumed_state`. A
  saved baseline reports the old kinds as resolved and the new ones as new;
  accept once to move on.

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
