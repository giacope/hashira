# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

The second half of this release was driven by `eval/`, a verification suite
that scores a hashira checkout: SonarSource conformance, coupling fixtures
whose cheapest cut is checked by brute force, clusters and non-clusters,
smell true and false positives, CLI behaviour, and three pinned corpora
(rubocop, faraday, rubygems.org) with findings per kLOC, runtime, peak memory
and precision on a fixed labelled sample. Two independent raters then
labelled a mixed sample of main and branch findings blind (they agree on 92%,
κ 0.65): rater 1 found 19 of 200 main findings and 28 of 160 branch findings
true, rater 2 23 of 200 and 33 of 160. A fresh holdout of 117 findings, drawn
after the rules changed and labelled the same way (κ 0.66), settled which kinds
are on by default (below). A separate blind readability study of 120 entry
methods calibrated and validated `fragmentation`. The raters in both were
independent AI reviewers: separate model instances that saw only the shuffled,
version-blind items and the corpus source, not hashira's code or labels. No
human has relabelled them yet. `eval/results/README.md` has every number. Every suite
passes; main passes between 31% (cli) and 83% of each.

The first half was found by running hashira against fifteen MIT-licensed
Rails apps and gems (rails, rubocop, chatwoot, feedbin, rubygems.org, huginn,
…).

### Upgrading

- `refused_bequest` is one finding per refused parent method, named for it
  (`Questionnaires::Base#next_step`) and sited at its definition, with every
  refusing subclass as evidence (npq-registration's seven are one); its JSON
  detail carries `places` and `parent`. `concrete_inheritance` is sited at the
  parent's definition instead of its first subclass. A baseline recorded before
  lists the per-subclass refusals as resolved and the per-method ones as new
  until `--update-baseline`.
- A `def` in `X.class_eval do … end` (any constant `X`) or in a `Module.new do
  … end` handed to `X.include`/`X.prepend` is `X`'s, not
  `Outer::(class_eval block, line n)`'s; one in Thor's `no_tasks`/`no_commands`
  or a Sinatra/Padrino app's `helpers do` is the class's; a refinement's owner
  prints as `Ext refine ::String`. Baseline entries named after the old owners
  move until `--update-baseline`.
- Generated files are recognised by more markers, read over the whole leading
  comment block (stripe-ruby's 1,249 `# File generated from our OpenAPI spec`
  files), and project templates under `lib/` are skipped: their findings drop
  out of a recorded baseline as resolved.
- `concrete_inheritance` is one finding per concrete parent, named for the
  parent, with every subclass as evidence (rails_event_store's 13
  `< RubyEventStore::Event` findings are one). A baseline recorded before lists
  the per-subclass findings as resolved and the per-parent ones as new until
  `--update-baseline`.
- `def`s inside a block handed to a call are no longer the enclosing module's
  (rodauth's 855-method `Rodauth` is 55 feature modules), and a narrowed
  library's entry file prints as `lib/rack/attack.rb` instead of `../attack.rb`.
  Baseline entries named after either move until `--update-baseline`.
- A shallow clone (or a history of fewer than two commits) counts as no
  history: change_coupling stays out of `--fail-on all` and reports nothing.

- `sdp_violation` is now `unstable_dependency`, in the text and JSON reports and
  in `--kind`/`--fail-on`. `sdp` and `sdp_violation` still name it on the
  command line and in `.hashira.yml`, and baselines that recorded it read it
  under the new name.

- `dead_code` is on by default and `layer_violation` is on once `layers:` are
  declared; `checks: all` also turns on `change_coupling`. A baseline recorded
  before them lists their findings as not ratcheted until `--update-baseline`.
  change_coupling reads git history, so a CI job that gates it needs the full
  history (`fetch-depth: 0`).
- **The design smells are on by default**, but `repeated_conditional`,
  `middle_man`, `indirection` and `boundary_sprawl`. A kind is on when hashira
  reads the facts behind it correctly and its advice follows hashira's aim
  (objects that own their state, no nil passed around, no type switches, no
  reaching through); agreement with Rails or Ruby convention is not a
  criterion, and volume is handled by grouping and the ratchet rather than by
  switching a kind off. A field test on ten more MIT-licensed codebases
  (sequel, graphql-ruby, yard, ruby-lsp, fastlane, chatwoot, feedbin, huginn,
  human-essentials, coursemology2) fixed what the smells misread first (see
  Fixed). `nil_check` is one finding per nil source and `message_chain` one per
  pair of classes reached through, each with every site as evidence. A
  baseline recorded before lists the newly on kinds' findings as not ratcheted
  until `--update-baseline`; `checks: { nil_check: false }` turns one back off.
- In a Rails app, an association declared both ways (`has_many :posts` and
  `belongs_to :user`) no longer closes a cycle: it is a
  `bidirectional_association` finding. Recorded cycles made only of such pairs
  resolve, and the pairs appear under the new kind.
- Baselines are schema 7 and record the kinds the recording hashira knew.
  Findings of a newer kind (`indirection` here) are listed as not ratcheted
  instead of failing the build until `--update-baseline`. Baselines from
  earlier versions read as before, and findings or accepted entries recorded
  under `duplicate_method_call`, `too_many_instance_variables` and
  `instance_variable_assumption` are read under their current names.
- Smell precision work (below) retires most `feature_envy`, `nil_check`,
  `manual_dispatch` and `control_parameter` findings and many
  `repeated_call` ones; `--update-baseline` records the smaller set.
- The baseline and `.hashira.yml` are read from the analyzed project's root,
  not from where hashira runs. A CI step that ran `hashira other/lib` from a
  parent directory now uses `other`'s files.

Three changes move what a recorded baseline expects; run `--update-baseline`
once after upgrading, after reading what the ratchet reports:

- With several directories (every Rails app run as `hashira app lib`), paths
  are now named from where hashira runs, so every recorded path changes.
- Cycles are one finding per knot, keyed by its alphabetically first member.
- Complexity scores methods it could not see before (`private def`,
  `class << self`, `class_methods do`) and charges nesting for ternaries and
  rescue modifiers, so more methods cross the threshold.
- In a Rails app, controllers, controller concerns and serializers now report
  as one `(web)` package and analyzed tests as one `(test)` package instead of
  joining domain packages, folds gain the
  `plural` and `mixin` kinds, and SDP needs a measurable gap, so namespace
  baselines see edges and findings move. Smell and clone fixes from the
  precision audit (below) retire findings; a few kinds also see new ones.

Across the fifteen field repos, findings fell from 15,557 to 12,711. Every
true positive the earlier triage confirmed still fires.

A second field test on twenty more MIT-licensed codebases (rails, mongoid,
rouge, apply-for-teacher-training, camaleon-cms, whitehall, …) changed three
things a baseline sees:

- `repeated_call` is one finding per class and `bidirectional_association` one
  per owning model. A baseline's per-method and per-pair keys read as the
  grouped findings, so neither needs a re-baseline; a class whose every
  repeat is gone reports as resolved.
- A project holding one Rails engine (no `config/application.rb`) now gets
  the Rails handling and namespace packages, so an engine's baseline sees its
  packages and edges move: run `--update-baseline` once.
- Ownership and caller resolution fixes (below) retire findings in
  `manual_dispatch`, `concrete_inheritance`, `control_parameter`,
  `dead_code`, `assumed_state`, `nil_check`, `repeated_call` and
  `duplication`; `--update-baseline` records the smaller set.

### Added

- **`strict: true`** in `.hashira.yml`, or `--strict`, turns on the strict
  set: the `stateful_mixin` kind and the stricter readings of `nil_check`,
  `concrete_inheritance`, `low_cohesion` and `data_class` listed under
  Changed. Without it every run reports what it reported before, under
  `checks: all` too: the new rules report code that passed, and a codebase
  gating on zero findings (rubocop-kata and kimera turn every kind on)
  should not fail on an upgrade. `checks: { stateful_mixin: true }` turns
  that kind on alone; `--kind` and `--fail-on` do not, since `--fail-on
  smells` names every smell. On the three gems' own code the strict set
  finds 0 in hashira, 3 in rubocop-kata and 12 in kimera.
- Found by the round-6 conformance matrix (one Elegant Objects principle per
  case, a violating and a compliant project each):
  - `stateful_mixin` (strict): a mixin whose behavior works on its
    host's state, by reading instance variables the module never assigns,
    keeping fields of its own in the host, or installing fields,
    associations, callbacks or validations on it (`included do after_save
    :track end`). Elegant Objects asks for a decorator that reaches the host
    through its public methods. Protocol mixins over public methods, memo
    caches, `extend self` and `module_function` modules and refinements are
    left alone. 56 findings in the 30 round-6 projects, 55 of them judged
    right (a refinement, now exempt, was the miss): state_machines' `Machine`
    split into eight modules over its ivars, pay's billable concerns, Rails
    helpers and controller concerns reading `@site`.
- `manual_dispatch` reads a type switch spread over methods: the same type test
  on the object's own state in three or more methods of a class (planner's
  `@check_in_target.is_a?(Event)` in six actions) is one finding for the class,
  each site as evidence. `repeated_conditional` stays opt-in.
- A shallow clone, or fewer than two commits, prints one stderr line naming
  what hashira could not weigh (`hashira: shallow git history (1 commit) for lib
  — hotspots are ranked by cost alone; change_coupling cannot judge`), the
  hotspot table's heading says the rank is the cost alone, and a run with no
  findings no longer calls the structure healthy for a kind it could not judge:
  `none — change_coupling could not judge: shallow git history (1 commit)`, or
  `none ✓ for the kinds judged; change_coupling not judged (…)`. `--json` lists
  them under `unjudged`.

- `--fail-on all` (and `fail-on: all` in `.hashira.yml`) gates every kind the
  run checks: the default kinds, the ones `checks:` turns on, less what
  `--skip` drops, narrowed to `--kind` when given. Unlike naming a kind, it
  turns no opt-in kind on. A codebase at zero findings gates with it instead of
  keeping a baseline for `--ratchet`, and the gate's verdict lists the kinds it
  covered.
- `.hashira.yml` takes `boundaries:`, the interpreted-model declarations the
  baseline holds, so a codebase without a baseline can still declare one. Both
  lists apply when both exist.

- **Rails engines** are Rails: a project with no `config/application.rb` that
  holds exactly one `class Engine < Rails::Engine` is packaged by the classes
  under the engine's module and gets associations, Zeitwerk folder namespaces
  and the framework's dead-code roots (camaleon-cms: layer folders no longer
  read as packages; 9 model pairs found where there were none).
- **bidirectional_association** (on): two packages whose classes each declare
  an association to the other, one finding per pair, naming the owning side
  (`has_many`, `has_one`) to drop and any `dependent:` option it carries,
  which has to move before the side does. Those declarations stay out of the
  cycle search, so a cycle is code reaching back (a pair whose code also
  reaches both ways is still in it), and the pair's edges out of the SDP
  check, where one direction of a mutual pair always pointed at the less
  stable side.
- `layers: rails` declares the conventional layering: `web` (controllers,
  views, helpers, components, serializers, presenters, decorators, policies,
  avo, dashboards), `app` (jobs, workers, mailers, services, channels,
  mailboxes) and `domain` (models, validators, `lib`).
- With no code in `lib/`, hashira reads where the gemspecs' `require_paths`
  say the code lives, globs included (fastlane's `Dir["*/lib"]`).
- `nil_check` and `message_chain` group their findings: one per nil source
  (`Account@owner`, `Account#current`: "may be nil, and 3 methods check for
  it") and one per pair of classes (`Order → Customer`), each site listed as
  evidence. A check on a local or an argument stays on its method.

- A cycle's cut names the `dependent:` options its edges carry. `has_many
  :messages, dependent: :destroy` is a guarantee as well as a reference:
  deleting the owner deletes the messages. Cutting that edge to break the cycle
  drops the guarantee, so later deletes leave orphans or trip a foreign key.
  The finding now says which edges to cut carry one, and the JSON lists them
  under each cut edge's `guarantees` (`"app/models/user.rb:8: has_many
  :messages, dependent: :destroy"`). On Campfire, 8 of the 12 edges in its
  model cycle's cut carry one.
- Declared layers and `layer_violation`. `layers:` in `.hashira.yml` lists
  the layers outermost first, each a package name or a name with the
  packages and paths it holds; every reference from a layer to one declared
  outside it is reported, one finding per pair of layers, with the package
  edges to cut, the cheapest first, and the references as evidence. When
  another order of the same layers (found by the cycles' exact cut search)
  would leave fewer references pointing outward, the finding says the code
  leans another way. On whenever layers are declared; the ratchet holds a
  pair by its references. hashira declares its own five layers and has none.
- `dead_code`, on by default: methods and constants the project never reaches,
  by the constant-reference graph and every call, symbol, string and literal
  name prefix in the code, and every word in the project's other files
  (specs, views, rake tasks, configuration). A library is judged on its
  private methods and private constants, its public surface being its users'
  API; a Rails app on everything outside the framework's entry points.
  Protocol methods, hooks, overrides that call `super`, classes that send
  themselves computed names, registries (`inherited`, `.subclasses`) and the
  public methods of framework-hosted classes and their mixins are left
  alone. `checks: dead_code: { roots: [...] }` names more roots: constants,
  methods and paths. Two blind raters judged all 13 corpus findings true
  (26 of 26); it costs about 2.6 s on rubocop and 1.3 s on rubygems.org.
- `change_coupling`, opt-in: two files in different packages that changed
  together in five or more commits and half or more of their changes
  (Tornhill's degree of coupling), from the same git log as the hotspots,
  commits of more than 30 analyzed files aside; `commits:`, `degree:` and
  `files:` move the limits. The finding says whether either file refers to
  the other. It needs the full history wherever it is gated. Opt-in: the
  corpus holds three findings at these limits (3 of 6 labels true), and on a
  looser sample (degree 30% and over) 5 of 34; most false ones were pairs
  that only ever changed together in lint sweeps.
- `checks: { all: true, ... }` turns every kind on beside settings that turn
  one off or move it.
- `eval/` cases for the three kinds, a fixture's git `history:` and `config:`
  in the smells suite, a per-project `config:` in `eval/corpus.yml` (the
  corpus declares plausible layers for each project), and precision samples
  for dead_code and change_coupling.
- `fragmentation`, a complexity kind, on by default: a public method that
  reaches four or more methods of its own class, named predicates aside (calls
  with no receiver or on `self`, `send(:name)`, `method(:name)`; instance to
  instance, class to class, across reopened classes) along a path at least two
  deep, when the entry and every method it reaches average 3.5 lines or fewer
  without blank and comment lines. The finding names the helper count, the
  mean, the depth and the deepest path, and lists the helpers, predicates marked
  as not counted; its advice is to merge the helpers that only move data and
  keep named predicates. `checks: fragmentation: { helpers: N, lines: M }`
  moves both limits; the ratchet holds it by helper count. A blind readability
  study set it on 60 entry methods and validated it on 60 more: of the 10 it
  flagged in the second sample, a rater judged 9 over-fragmented and both
  raters 8 (independent AI reviewers; no human has rated them yet). Predicates
  are left out because, when rubocop-kata merged its findings away, the
  raters preferred the original wherever the merge removed a named predicate.
- `indirection`, an opt-in complexity kind that counts hollow hops: helpers
  that are private, called once from their own class, and whose body is one
  call with no decision and no block, wrapping at most one more call. It
  reports the path through an entry's single-use helpers that holds the most
  hollow ones once it holds two (the threshold is configurable); helpers that
  decide, loop or hold several statements cost nothing. The finding lists the
  hollow helpers and the ratchet holds it by their count.
- Inline suppression: `# hashira:disable KIND[,KIND] -- REASON` (this line) or
  `# hashira:disable-next-line ...`. The reason is required; suppressed
  findings and directives that no longer silence anything are listed in the
  text and JSON reports, and a malformed directive stops the run.
- `checks:` in `.hashira.yml` turns a kind on (`nil_check: true`) or off
  (`duplication: false`), or sets its threshold (`complexity: { threshold: 12
  }`) for complexity, indirection, state_sprawl, repeated_conditional,
  boundary_sprawl and wide_edge. `checks: all` turns on every kind.
- Rails associations are references: `belongs_to :user`, `has_many
  :line_items` and `has_one` name their class through ActiveSupport's
  inflection rules, including the app's `config/initializers/inflections.rb`;
  `class_name:` wins and `polymorphic: true` names nothing.
- `eval/`: the verification suite described above, with `eval/run`.
  `--seed SALT` draws a fresh precision sample disjoint from every labelled
  key, for a holdout.
- `bin/inventory` regenerates `lib/hashira/analysis/inventory.yml`, what a bare
  Ruby ships (core constants, standard and bundled libraries, Kernel and
  BasicObject methods, core value methods, class macros).

- A precision audit of 643 findings on a production Rails app judged 57%
  of them sound. The fixes below target the causes of the false positives
  (detectors matching names instead of types, ignoring reachability, and
  missing framework or protocol contracts). Each one is pinned by the
  audit's own false positive and a true positive that must still fire.
- A finding can state its own `confidence`, overriding its kind's: repeated
  cheap reads, parameter defaults, request-derived `respond_to?` probes, nil
  checks on library objects and clone conventions are `low`, and a low
  finding is listed after the confident ones of its kind.
- `manual_dispatch` also catches `case`/`is_a?` dispatch over two or more of
  the project's own types, and a `case` that does more than map the object's
  own status, state, type or kind to a value; dispatch over a library's types
  stays boundary_sprawl's.
- `nil_check` also sees `blank?`, and `&.`, `x || default` and `unless x` on
  a local, ivar or parameter the code itself leaves nil.
- Duplication names two new variances: `nil_guard`, twins that differ only by
  `&.`, and `convention`, one finding for a declaration repeated at ten or
  more sites, instead of arbitrary pairs of them.
- Cycle findings list in `detail.folded` the members that are in the knot
  only through folded types.

- A `.hashira.yml` where hashira runs holds the options you would otherwise
  type every time: `directories`, `fail-on`, `skip`, `kind`, `top`,
  `package-by` and `baseline`, each named as its flag. The file is checked on
  its own, naming itself in any error. A flag on the command line replaces its
  setting, and a setting the command line rules out steps aside instead of
  failing the run, so `fail-on` from the file leaves `--json`, `--ratchet`
  and `--update-baseline` alone. `--config PATH` reads another file;
  `--no-config` ignores it.
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
- Six class-level design kinds, all opt-in because none clears the precision
  bar (one independent rater, every corpus finding up to 25 per kind; see
  `eval/results/README.md`):
  - `concrete_inheritance` — a class extends an owned class the project also
    builds on its own; the evidence is where. Abstract parents (named `Base` or
    `Abstract…`, an unimplemented hook, `abstract_class`/`abstract!`) and
    hierarchies rooted in a framework or core class are left alone. 5 corpus
    findings, 1 of 5 true.
  - `refused_bequest` — a subclass overrides a method an owned ancestor
    implements only to raise or do nothing. 1 corpus finding, judged false.
  - `low_cohesion` — LCOM4 over classes of six or more methods: groups of two
    or more methods that share no instance variable and never call each other.
    Readers, writers and Forwardable delegators count as touching their field,
    and the constructor joins what it derives together. `threshold` moves the
    class size. 3 corpus findings, 0 of 3 true.
  - `message_chain` — the Law of Demeter on a single chain through objects the
    project owns (`order.customer.address`), each link typed by name and
    declared by its class; library objects, collections, hops with arguments or
    blocks, fluent hops, Struct and Data readers and universal messages are left
    alone. `repeated_call` still reports a chain read twice. 81 corpus findings,
    2 of 25 true.
  - `data_class` — a class of two or more fields with nothing but attribute
    macros, plain readers and writers and a constructor that stores its
    arguments; Struct, Data and classes with a superclass or subclass are left
    alone. 1 corpus finding, judged false.
  - `middle_man` — a class whose public methods mostly (at least three, more
    than half) only forward to one field. Declared delegation (Forwardable,
    `delegate`, SimpleDelegator, DelegateClass), collection protocols and
    facades are left alone. `threshold` moves the minimum. No corpus findings.

### Changed

- Found by the round-6 conformance matrix (one Elegant Objects principle per
  case, a violating and a compliant project each) and the gaps the sixth
  field test listed (GH2–GH5):
  - `middle_man` leaves a decorator alone: a class whose every public method
    that does not forward wraps the same call on the same field
    (`def subject = "URGENT: #{@origin.subject}"` beside `body`, `recipient`
    and `to_s` passed straight through). It was told to "let
    callers talk to the delegate directly", which undoes the decorator Elegant
    Objects asks for, while the same class spelled with `def_delegators` was
    left alone.
  - Under `strict: true`, `nil_check` no longer exempts a parameter
    defaulting to nil: a method that tests its own `coupon = nil` (or `label:
    nil`) is an optional argument, two methods in one, and is told to split
    it or ask for a null object, as Elegant Objects accepts no nil arguments.
    By default it stays "the caller's option". Strict also follows a nil to
    another owned class's method
    that can answer nil (its body ends in `detect`, `find`, `first`, `[]`,
    `dig`, `&.`, a literal `nil`, an `if` without `else`, or it returns early
    with nothing): `item = @catalog.find(code); item.nil?` in `Cart` is one
    finding named `Catalog#find`, with every method that checks it as
    evidence, reached through an instance variable or local named for the
    class or an object built on the spot (content-tagger's
    `TaxonomyQuery.new.parent(id)`), where it was quiet. A field named
    like its own class (`@contexts` inside `Contexts`) is not that class.
  - `nil_check` leaves a shorthand guard that raises alone, as README says
    of every raising guard: `fail exception unless @socket` (excon),
    `raise InvalidEvent unless event` (state_machines) were reported because
    the check was the `unless` itself rather than its condition.
  - Under `strict: true`, `concrete_inheritance` no longer leaves every
    hierarchy rooted outside the project alone (batch-1 GH2). Under a
    framework root, a subclass that
    overrides a working method of its concrete parent is reported, each
    overriding method as evidence: pay's `Stripe::Charge#sync!` over
    `Pay::Charge#sync!` and its three other STI families, collections-publisher's
    `MainstreamBrowsePage#dependent_tags` over `Tag`. A subclass that only adds,
    or gives itself a constructor, stays quiet. A class extending `Array`,
    `Hash`, `String` or `Set` is reported on its own (V1 P26: `class LineItems
    < Array`), told to hold one in a field. A parent named `Base…` reads as
    abstract, like `…Base`. 24 new findings in the 30 round-6 projects, all
    judged right on reading. The JSON detail of such a finding carries
    `mode` (`overriding` or `core`); a parent the project builds itself, the
    only kind without strict, carries none, as before.
  - Under `strict: true`, `data_class` no longer exempts a value by
    declaration (V1 P28): a bare `Struct` or `Data` value, or an ActiveRecord
    model with no behavior of its own, is reported once another owned class
    computes with two or more of its fields from one object (`Invoice#total`
    over `@order.quantity`, `@order.unit_cents`, `@order.shipping_cents`),
    each such method as evidence. No new findings in the 30 round-6 projects
    (none of their 25 bare values is computed with elsewhere) or in the three
    gems.
  - `data_class`'s advice no longer offers "or declare it a Data value": a
    `Data` value with nothing but its members is the same bag, which the
    strict reading reports, so the advice only moved the finding out of
    sight.
  - Under `strict: true`, `low_cohesion` judges models (batch-1 GH4). Its
    framework exemption, written for controllers and mailers, covers every
    class under a framework base by default; strict narrows it to the
    presentation stratum
    (controllers, mailers, jobs, channels, mailboxes). A model's column
    readers (a bare call to a name the class does not define) count as
    fields, as hashira does not read the schema: transition's `Hit` splits
    into its `http_status` predicates and its `path` URLs. 12 new findings in
    the 30 round-6 projects.
- **A def inside a DSL block has an owner of its own.** Its owner is the
  constant the call names by a CamelCase symbol or string
  (`Feature.define(:change_login, :ChangeLogin)` → `Rodauth::ChangeLogin`), or
  else one per block (`Auth::(configure block, line 7)`). Blocks that reopen
  the class or build one keep the enclosing owner: `included`, `class_methods`,
  `concerning`, `class_eval` on self, `Class.new`, `Module.new`, `Struct.new`,
  `Data.define`. rodauth's complexity rollup is 55 feature owners, and their
  `before_logout`s are no longer one class's.
- **A dependency claims a namespace by its whole name.** `travis-config` claims
  `Travis::Config`, never `Travis`; a `require:` path in the Gemfile claims the
  namespace it names. A root the project defines stays the project's beside
  plugin gems that share its first word (travis-api's `Travis`, a
  `shop-core` gem beside `shop-sql`).
- **A reopened core class is Ruby's whatever superclass it spells**
  (``class ::Array < `Array` ``, `class String < Object`), so a core-type ladder
  in the rest of the project is not manual dispatch (opal's compiler).
- `manual_dispatch` leaves the comparison protocols (`<=>`, `==`, `eql?`,
  `===`, `equal?`, `coerce`) to type-test what they are handed, as
  rubocop-kata's NoTypeCheck does.
- `--kind` turns the kinds it does not name off for the run, so the design
  smells it leaves out are never computed.
- `lib/templates/**`, where Rails reads generator template overrides, is left
  out like `lib/generators/**/templates/**` (homeland's ERB-in-`.rb`
  controller template no longer fails to parse).
- `analysis/inventory.yml` is read from Ruby 4.0.7; the standard libraries
  Ruby 3.4 ships stay listed.

- **boundary_sprawl follows copied and aliased constants to their source.** A
  namespace that hands out another's constants as its own, with
  `const_set(name, Prism.const_get(name))` or `Node = Parser::AST::Node`,
  was reported as a foreign root of its own (`SyntaxTypes` in kimera). A type
  test through it now counts against the root it came from, which a declared
  interpreted model covers; a constant the namespace defines itself stays its own.

From the third field test (thirty MIT-licensed codebases):

- **Scope**: with no directory, every `lib/<gem>` beside a `lib/<gem>.rb` is
  analysed, entry files included (rubygems was read as bundler alone);
  vendored code (`vendor/` below the analysed directory) and generated code
  (a sibling `.rl`/`.y`/`.racc`/`.treetop`/`.rex`, or a "generated by" / "do
  not edit" / `@generated` comment in the first ten lines) is skipped, and
  stderr says how many files were analysed and skipped. Naming the directory,
  or `--only` a file, analyses it anyway.
- **Engines anywhere**: any `lib/` file holding `< Rails::Engine` or
  `isolate_namespace` makes the project an engine (devise keeps its engine in
  `lib/devise/rails.rb`); an engine's `lib/` keeps a library's dead-code roots.
- **layers: rails** puts every other `app/` folder in `app` and mailer
  previews in `web`, never proposes an order with the preset's `app` below
  `domain`, says on stderr how many files sit in no layer, and a cut names
  classes (`Archived::Report -> DatesHelper`), not packages.
- **repeated_call** counts chains under a repeated prefix once, as the prefix,
  and prints `params[:user]`, not `params.[](:user)`.
- **dead_code** reads a spec's words only as calls, symbols and constants
  (a `let` or a local no longer keeps a method alive), RSpec predicate
  matchers as predicates (`be_x` → `x?`, `have_x` → `has_x?`), and a gem's
  README and `docs/**/*.md`.
- **feature_envy** types a variable by its name only when the name resolves to
  an owned class in sight of the method; a type test outranks the name.

- **repeated_call is one finding per class** ("repeats 14 calls in 6
  methods"), each method's repeated calls as evidence, and
  **bidirectional_association one per owning model** ("Edition is navigated
  both ways by 9 models"), named by class even inside a namespace package.
- The capped text report deals structural kinds (cycles, layers, dead code,
  associations) first and `repeated_call` and `duplication` last in every
  round.
- `layers: rails` puts mailers, mailboxes and channels in `web` with the
  other delivery mechanisms; an edge whose ends share a package names the
  layer at each end.
- Templates a generator copies (`lib/generators/**/templates/`) are not
  analyzed.
- **A cycle's cut follows the dependency direction when weights tie.** Among
  cuts of the same weight it keeps the edges into the packages more others
  depend on (the higher Ca) and cuts the ones out of them. It used to break
  the tie by package name, and in a Rails app, where most edges weigh one
  association, the name decided the advice. Campfire's model cycle was cut at
  `Ban -> User`, `Membership -> User`, `Search -> User` and the other
  `belongs_to :user` lines, the edges into the identity every model rests on,
  which is the direction to keep. The cut now takes `User -> Ban`, `User ->
  Search` and its other `has_many` lines, at the same 15 refs. When the
  code leans away from declared layers, the order `layer_violation` names keeps the
  declared order wherever the references leave it free, rather than the
  alphabetical one.
- **Smells report only where their advice applies to owned code.**
  `feature_envy` needs a destination class it can name (from a constructor,
  a rescue, a type test, or the variable's name or last words), that the
  codebase owns, that is not a core class or the method's own, and that
  declares every message sent; the advice names the class. `nil_check` needs
  the nil to be the codebase's own (its state, a nil it assigns, its own
  methods, a private method's argument, a literal it built, an owned class's
  records or declared attributes); the boundary advice is gone with the
  boundary findings. A nil-defaulted parameter is the caller's option, and a
  check whose branch raises, or a one-line predicate that answers a nil test,
  is left alone. `manual_dispatch` probes must be on self or a
  variable of a nameable owned class, and ask for a message the codebase
  defines. `control_parameter` needs a caller that passes the flag as a
  literal, to a method outside callers can reach (a private or protected
  helper sits behind explicit public methods). Each lists every check, probe or
  flag as evidence.
- `utility_function` judges classes only; a module's methods (a mixin, a
  concern, a view helper) lend behavior. Its advice is to move the method or
  make it private.
- `data_clump` needs three or more parameters travelling together.
- `repeated_conditional` counts comparisons with a fixed value, type tests and
  `case` subjects; a plain truth test asks about state and stays quiet.
- `repeated_call` leaves a plain read of self, a local or an instance
  variable (no arguments, or literal keys) made exactly twice alone as style,
  and a reading measured by distance or order against a stored copy of its
  own earlier result as a second sample. The clock and calendar name lists
  are gone; `Time.now` twice is still reported (a constant's query), and so
  is `clock.now` through a helper method.
- `state_sprawl` weighs each field: nothing if the constructor takes it
  straight from an argument (an input, like a component's props), one if the
  constructor, a helper it calls or a registered callback (`before_action
  :set_user`) sets it otherwise, two if it is set elsewhere and another method
  or a reader takes it up, nothing if no method reads it. That replaces the `*Controller`, `*Mailer` and
  `*Component` exemption. The message says what was weighed against what:
  `holds 5 instance variables, weighing 6, more than 4`.
- A call made by symbol (`send(:name)`, `public_send`, `__send__`,
  `method(:name)`) is a call to that method, for recursion and the helper kinds.
- Cognitive complexity follows the SonarSource specification on lambdas
  (they nest), recursion (+1), `a && (b && c)` (one run), and `define_method`
  bodies (scored as methods).
- The cheapest cut of a cycle is a minimum feedback arc set: exact for knots
  of up to twelve packages, a peeling heuristic with insertion moves beyond,
  and the message says "the cheapest cut found" when it is not exact.
- A top-level constant written as a compact path (`class Alpha::One`) is
  looked up at top level, not under the inferred namespace, so it no longer
  adds a phantom edge.
- Namespace packaging recognises a Rails app's framework adapters by shape (a
  top-level class extending an outside class that the app's classes extend)
  instead of a list of ten `Application*` names.
- Near-miss clones must share their names (calls, constants, and the words
  in their strings and symbols) as well as their shape, and are compared only
  between whole methods, rescue clauses and when arms. A crowded bucket of
  more than sixty candidates is split by MinHash bands instead of dropped.
- A log line is a Logger severity sent to something named `log` or
  `logger`, and an error report is a call that hands on the rescued error;
  the vendor list (`Sentry`, `Honeybadger`, …) is gone. A rescue clause that
  only reports its error weighs nothing wherever it sits.
- Duplication weighs a constructor that only stores its arguments, and a
  frozen list of constants, as declarations.
- Builtin detection reads the generated inventory instead of
  `Gem::BUNDLED_GEMS`, `Object.const_defined?` and the running process's
  method tables, so two runs on the same code agree whatever is loaded.
- The README is rewritten and every console example in it is run by the
  test suite.

- Namespace packaging knows Rails layers. Everything under `app/controllers`
  (concerns included), `app/serializers` and `app/resources` is the `(web)`
  package: never suffix- or base-folded into a domain (`OrderResource` stays
  out of `Order`, `CurrentResource` out of `Current`), never a package of its
  own namespace (`Admin::OrdersController`), and counted only as a client.
  SDP, cycles, wide edges and audiences are judged on the domain graph. In
  the audited app 36 of the cycle's 53 members entered only through folds.
- `Foos` folds into `Foo` when both exist, and a module that only extends or
  includes another (`module OrderShipped; extend Notifier; end`) folds into it.
- A top-level `Payments::Rate = …` or `Payments::Ledger.private_constant` is
  charged to `Payments`, not `(root)`, and a constant's own definition is no
  longer an edge into itself. `class_name: "A::B"` association strings count
  as references.
- An SDP violation needs at least three edges at each end and a gap of 0.10,
  and an edge inside a cycle is cycle evidence, not an SDP violation.
- A cycle's cut must leave no strongly connected part larger than half the
  knot; detaching one leaf no longer passes.
- A wide edge counts a nested class with the class that holds it
  (`Gate`, `Gate::Policy`, `Gate::Exceeded` are one API). Mixed audience
  ignores `(root)` as a client and parts whose clients define fewer than
  three types.
- `state_sprawl` weighs state, not a count: a variable first set outside the
  constructor weighs two (an intermediate result parked between calls), and
  a class whose methods use all its constructor state together is one
  cohesive handle. A controller's, mailer's or component's actions hand
  variables to a template, so they weigh one.

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

- Found by the sixth field test's sixth batch (service-manual-publisher,
  state_machines, rubycritic, sshkit, acts-as-taggable-on):
  - `repeated_call` reads a call to any reader the class, a parent or a mixin
    declares as the instance variable it reads, plain or keyed, as README's
    "plain read of self" promises: service-manual-publisher's
    `GuidePresenter` reading `guide.slug` twice through `attr_reader :guide`,
    and acts-as-taggable-on's tag queries reading `options[:on]` twice
    through their parent `QueryBase`'s private `attr_reader :options`, are
    style like `@guide.slug` twice. Only a literal-key read through the
    class's own reader was taken before (48 evidence lines in the corpus). A
    helper method's result read twice, a chain, or three reads in one run
    are still reported.
  - `repeated_call` parts two reads around a bang or a change sent by name
    (`object.send("#{event}!")`, `public_send(:launch!)`, `__send__(:<<,
    item)`), as it does around the call spelled out: state_machines'
    `assert_sm_sync_execution` reads the state, fires the event with
    `object.send("#{event}!")` and reads it again, and naming the first read,
    as advised, made the assertion fail on every correct transition. A name
    the code computes with no literal tail (`send(event)`) is still read as
    a query.
  - `nil_check` names a nil a method makes for the class or mixin that
    defines the method: sshkit's `Backend::Abstract#pwd_path` answers nil,
    and `Local` and `Netssh`, which inherit it, test `pwd_path.nil?`; that
    was two findings named `Local#pwd_path` and `Netssh#pwd_path`, telling
    to settle the nil in two classes that make nothing. It is now one
    `Abstract#pwd_path` finding with the four checking methods. A subclass
    that overrides the method keeps its own.
- Found by the sixth field test's fifth batch (local-links-manager, bullet,
  excon, counter_culture, turbo-rails):
  - `stateful_mixin` takes ActiveSupport's module, class and thread
    attribute macros (`mattr_accessor`, `cattr_reader`,
    `thread_mattr_accessor`, ...) for fields a mixin installs on its host, as
    it took `class_attribute`: turbo-rails' `Turbo::Broadcastable`, whose
    `included` block installs `thread_mattr_accessor
    :suppressed_turbo_broadcasts` on every model and whose methods test it,
    went unreported under strict. One in the module's own body (ahoy's and
    counter_culture's configuration) stays the module's.
  - `utility_function` finds kin where two more kinds of place meet:
    a class attribute's default and the classes assigned to it
    (`class_attribute :debouncer_class, default: Turbo::Debouncer` beside
    `ThreadDebouncer.debouncer_class = Turbo::ImmediateDebouncer`), and a
    class that hands itself to a decorator or seeds a chain of them
    (excon's `middlewares.inject(self) { |stack, m| m.new(stack) }`) with the
    decorators that forward what they define to the object they wrap.
    excon's `Connection#response_call`, the innermost answer of the
    middleware chain, and turbo-rails' `ImmediateDebouncer#debounce` were
    told to go private or move; either breaks every response or every test
    run.
  - Strict `nil_check` types an instance variable by what its object's
    classes and mixins build into it before its name: excon's `SOCKS5`
    module tests `@socket.read_nonblock(n, exception: false)` for nil, and
    `@socket` was read as an `Excon::Socket` for its name, though every
    class that mixes `SOCKS5` in builds it from core `::Socket.new` (through
    a local in `Excon::Socket#connect`), whose nil at EOF is the library's
    contract. A field nothing builds is still typed by its name, and one an
    owned class is built into (`@pipe = Socket.new`) is now typed as that
    class.
  - `low_cohesion` reads a hook the class leaves abstract (its body only
    raises `NotImplementedError` or `NoMethodError`) as calling what its
    subclasses' overrides call: bullet's `Notification::Base` stubs `title`
    and `body`, which build the notification text, and every heir's `body`
    calls `klazz_associations_str` and `associations_str`, so the two groups
    it was told to split along meet in every notification bullet builds.
  - `repeated_call` ends a run where Ruby does: at a `raise` (also one whose
    message holds the first read, `raise E, "... #{attrs[:name]}"`), and
    inside a block at `next` and `break`, whether the exit holds the first
    read (`orphaned << child[:slug] && next`) or follows it as a statement
    (`if c; skip(x); next; end; keep(x)`); a block's next pass no longer
    brings round a read of what the block binds afresh (its parameter), and
    a raise has no result to name. local-links-manager's `connect_parents`
    and `create_or_update_la`, excon's six `socket.read(n) ||
    raise(EOFError)`, rack-mini-profiler's five `@app.call(env)` (one per
    exit: naming it would not call the app twice, it would not call it at
    all on some paths) and ten other evidence lines across the corpus were
    reads no run makes twice. A loop that does not rebind the read, and a
    raise a `rescue` catches, still let a run reach both.
  - `repeated_call` takes any call that holds a reading measured against a
    stored earlier one for a new value each time, as the reading is: excon's
    `SOCKS5#socks5_read_exactly` measures `deadline - Time.now` before its
    first wait and again for the second (`[deadline - Time.now, 0].max`),
    and naming the first makes the second wait overshoot the deadline. A
    clock read with nothing measured against it is still reported.
  - `repeated_call` parts two reads around a call that consumes or changes
    the receiver whatever becomes of its answer (a draw such as `shift` or
    `pop`, a bang, `<<`, `push`, `delete`, `clear`, ...), as it parted them
    around a command: counter_culture's `relation_reflect_and_model` tests
    `relation.size > 0` before and after `cur_relation = relation.shift`,
    and naming the first test runs the last link's lookup its comment says
    it skips on purpose. `done = job.finalize!` between two reads of
    `job.status` now parts them too.
  - `dead_code` reads a module mixed in bare inside a library's load hook
    (`ActiveSupport.on_load(:active_record) { include M }`, and `extend`,
    `prepend`, `self.include`, `send(:include, M)`) as handed to the
    framework class Rails runs the block on, as it read
    `ActiveRecord::Base.include(M)`: turbo-rails' engine mixes
    `Turbo::Broadcastable` into every model that way, and its documented
    macros `broadcasts_refreshes_to` and `broadcasts_refreshes` were told to
    be deleted. The hook counts in an analysed file and in one outside the
    analysed directories (`config/initializers/`).
  - A file is generated only when its leading comments carry a generator's
    stamp: a line that opens by saying the file was generated ("This file
    was generated by", "Code generated by", "Generated by", "Auto-generated
    from"), opens with "do not edit", a `@generated` tag, or "DO NOT EDIT" in
    capitals. "generated by" anywhere in the leading comments was taken for
    one, so turbo-rails' hand-written `Turbo::StreamsChannel`, whose class
    comment says "a `signed_stream_name` parameter generated by turning a
    set of streamables …", was skipped from every kind: its `Streams` /
    `StreamsChannel` cycle went unreported and `unstable_dependency`
    counted its package as absent. Across the 52 projects of the sixth
    field test (and the fifth's 50) every other file skipped before is
    still skipped; the only others no longer skipped are Rails'
    `new_framework_defaults` initializers, whose comments speak of "messages
    generated by" a cipher.
- Found by the sixth field test's fourth batch (transition, WebsiteOne,
  unparser, strong_migrations, hashie):
  - `low_cohesion` under strict reads a model's columns in every spelling the
    model touches them, not only a bare read: transition's `MappingsBatch`
    split its `finished?`, `succeeded?` and `failed?` (which read `state`) from
    `with_state_tracking`, which writes `state` with `update_column(:state,
    …)` three times, and joined the rest through `@raise`, the bare `raise`
    in its `rescue`. A call on `self` (`self.state`, `self.state = …`,
    `self.count += 1`) and the column a persistence call names
    (`update_column`, `update_attribute`, `write_attribute`,
    `read_attribute`, `self[:state]`, and the keys of `update`,
    `update_columns` and `assign_attributes`) now touch the column; a Kernel
    method called bare (`raise`, `binding`, `caller_locations`) is Kernel's,
    and a reader `delegate`d to an association (`delegate :hostname, to:
    :site`, with its `prefix:`) is the association's field, as a
    `def_delegators` reader already was its target's. A column only written
    still makes no group of its own.
  - `nil_check` leaves a guard alone whose branch raises through a method of
    the class that always raises, as it leaves an inline `raise`: hashie's
    `Dash#_assert_property_set!` and `#_assert_property_required!` call
    `_fail_property_required_error!`, which builds the message and raises,
    and were told to prefer a default or a null object, which would drop
    Dash's required-property assertion. A method always raises when its last
    statement raises (itself, or through another such method) and it never
    returns early; a helper that may return, logs, or belongs to another
    object leaves the check reported.
  - `module_initialize` leaves alone a module that extends itself:
    WebsiteOne's `GithubCommitsJob` (`extend self`, never included, its `run`
    calling `initialize` to set the module's own client) was said to carry
    constructor state into its includers, which it has none of; renaming the
    method made the finding vanish with the module-level state unchanged.
    That state is kata's to report (`Kata/NoClassMethodLogic`,
    `Kata/FrozenState`); `stateful_mixin` already read such a module as no
    mixin.
  - A `::`-rooted constant a value is tested against (`is_a?`, `case`),
    built from (`::Catalog.new`) or rescued as types the value at the root,
    not as the owned class of the same name: hashie's
    `IndifferentAccess#_hash_lacking_indifference?` and
    `#_hash_with_indifference?` test `other.is_a?(::Hash)`, Ruby's Hash, and
    `manual_dispatch` read it as `Hashie::Hash` and reported their
    `respond_to?` probes on a value of no owned class. The same root reaches
    strict `nil_check`'s typing of a built local and `boundary_sprawl`'s
    foreign roots (`::Ast::Node` beside an owned `App::Ast::Node`).
  - `stateful_mixin` reports a mixin that only installs on its host, as its
    README example says (`included do after_save :track end`): WebsiteOne's
    `ActAsPage`, whose `self.included` installs a presence validation (and
    library macros) on every page model, went unreported because it defines
    no method, while transition's `NilifyBlanks`, the same shape plus one
    method, was reported. A call inside a block that opens another object (a
    refinement, `Struct.new`/`Class.new`/`Module.new`/`Data.define`)
    installs nothing on the host, which the old method gate had covered for
    refinement-only modules, and a `ClassMethods` module its namespace hands
    to the host, whose methods are the host's class methods, stays out as
    before.
- Found by the sixth field test's third batch (collections-publisher,
  travel-advice-publisher, mechanize, ancestry, ahoy):
  - `low_cohesion` under strict reads an association and the columns that back
    it as one field: collections-publisher's `Tag` split into a `parent_id`
    group (`can_have_children?`) and a `parent` group (`has_parent?`), two
    spellings of one fact, and `list_items`, which `has_many …, through:
    :lists` reads through `lists`, into a group of their own. A
    `belongs_to`'s key column (its `foreign_key:`, and its `_type` when
    polymorphic) and a `through:` association are now the association's field.
  - `stateful_mixin` counts what a module assigns itself as its own when it
    extends or includes a module hashira cannot see: mechanize's `Parser`
    (`extend Forwardable`) was said to read `@response`, `@uri` and
    `@filename` from its host, though it assigns `@response` and `@filename`
    and mints `uri` with `attr_accessor`, and a memo cache under the same
    extend (`@entries ||= {}`, then `@entries.fetch`) was reported, though
    memo caches are left alone. A field nothing in the module assigns is
    still the host's.
  - `concrete_inheritance` reads a parent method that only raises
    `NoMethodError` as the parent saying it is abstract, as one that raises
    `NotImplementedError` does: collections-publisher's `Tag` declares
    `can_be_archived?` and two more as `raise NoMethodError` stubs its
    subclasses fill, and strict reported it as a concrete class.
    `refused_bequest` and the strict "working method" reading already took
    any raise-only stub for unimplemented. A method that raises another error
    (`ArgumentError`) is still a working method.
  - A library's hook stays a hook unless the project sends its name to an
    object of the class's own lineage: collections-publisher's
    `DependentTagPublishJob#perform`, which Sidekiq calls, lost its exemption
    because controllers call an unrelated `ListPublisher.new(@tag).perform`,
    and `SlugValidator#validate`, which ActiveModel calls, because a model
    writes `save!(validate: false)`; `utility_function` said to make each
    private (NoMethodError). A message now counts for a class when it goes to
    `self` inside its lineage (the class, an ancestor, a subclass, a mixin),
    to an object built from a class of that lineage, or to a receiver hashira
    cannot type; one sent to another class's objects or to a library's does
    not, and a hash key or keyword is a label, not a message. warden's
    `Config#serialize_into_session` and `#serialize_from_session` (forwarders
    to `Warden::Manager`'s class methods, on a `Hash` subclass) go quiet the
    same way.
  - `nil_check` reads memoization in the rest of its spellings:
    collections-publisher's boolean memo (`if @x.nil? then @x = lists.any?
    else @x end`, since `||=` cannot keep `false`), a guard return before the
    fill (`return @x unless @x.nil?`), and mechanize's `Page#labels_hash`
    (`unless @x` around a fill whose last statement writes it, a cache the page
    clears to nil). Only a fill that sets the value tested, and an `else` that
    only answers it, count: an `else` that does more, a guard that returns
    something else or is never followed by the fill, and a write on the
    non-nil side are still reported. mechanize's `Form#set_fields` (`value =
    val unless value`, the `||=` spelling on a local) goes quiet the same way.
    A parameter is never memoized: under strict a nil-defaulted one the body
    fills (`parser = self.parser unless parser`, mechanize's
    `Page#encoding_error?`) stays an optional argument in either spelling,
    `if parser.nil?` included, which the old one-statement reading let pass.
  - `repeated_call` parts two reads of an instance variable around a call on
    self whose method moves it: mechanize's `WWWAuthenticateParser#parse`
    reads `@scanner.pos` around `auth_scheme`, `spaces` and `auth_param`,
    private helpers that scan `@scanner` forward, and naming the read would
    give every challenge the same raw text. A self call between the reads
    disturbs them when the method it reaches (or one that method calls on
    self) sends the instance variable a message as a command (its result
    thrown away) or as its own answer, other than a predicate or the same
    reader, or reassigns it, as a command on the receiver already did. Still
    reported: a helper that only asks (`@scanner.eos?`), rereads, or reads
    the field to compute something else (rack-mini-profiler's
    `matches_action?` builds a pattern from `@config.profile_parameter`),
    one that touches another field, a method the class does not define, a
    call on another receiver, and a receiver that is not an instance
    variable (a reader or a local).
  - `repeated_call` reads `__LINE__` as the line it is written on: ancestry's
    `InstanceMethodsBuilder.build` passes `__FILE__, __LINE__ + 1` with two
    `class_eval` heredocs, on lines 40 and 462, and was told to name
    `__LINE__.+(1)` in a local, which would give the second heredoc the
    first's line numbers in every backtrace. The same text twice on one line
    is still one value.
  - The design smells name a `ClassMethods` module's methods for its
    namespace (`Concern.method`) only when that namespace hands the module to
    its host or extends it itself (`extend ActiveSupport::Concern`, an
    `included` or `class_methods` block, `base.extend` in `self.included`, or
    `extend ClassMethods`), and never a `def self.` inside it, which is the module's own: ancestry's
    `nil_check` and `repeated_call` named `Ancestry.tree_view`,
    `Ancestry.restore_ancestry_integrity!` and
    `Ancestry._check_ancestry_integrity!`, methods `Ancestry` does not answer
    (the macro `has_ancestry` extends `Ancestry::ClassMethods` into each
    model, and the code calls `Ancestry::ClassMethods._check…`), while the
    complexity table named them `Ancestry::ClassMethods#…`. Any other
    `ClassMethods` module's methods now keep that name, `#` and their own
    visibility. Baseline entries named the old way move until
    `--update-baseline`.
- Found by the sixth field test's second batch (manuals-publisher,
  places-manager, ferrum, friendly_id, dry-monads):
  - `utility_function` leaves to the object what Ruby asks of every object:
    `==`, `eql?`, `equal?`, `<=>`, `===` and `coerce` with one argument,
    `hash`, `inspect` and `to_s` with none. dry-monads' `None#eql?` and
    `None#hash` answer without state because every None is equal; Hash keys,
    `uniq` and `sort` call them, so "make it private" broke them and "move
    it" meant nothing. A method of another name, or one that takes what Ruby
    never passes (`def hash(password)`), is still reported.
  - A library's hook stays a hook when the project only sends its name to a
    class, as a macro in a class body: places-manager's
    `CannotEditPlaceDetailsUnlessNewestInactiveDataset#validate` fills
    `ActiveModel::Validator#validate`, which `validates_with` calls, but
    `validate :has_both_lat_lng_overrides` in `Place` made it read as the
    project's own message, and `utility_function` said to make it private
    (every update would raise NoMethodError). A name the project sends an
    instance still counts.
  - The classes one hash literal holds as its values are kin, as the
    classes one array literal builds are, whether it builds them or holds the
    classes themselves for the code to pick one: ferrum's `Log::FORMATS = {
    default: Default, json: Json, annotated: Annotated }`, read through
    `FORMATS.fetch(format).new(color: @color)`, is a strategy table, so
    `Json#sent` and `#received`, stateless because JSON is never colored,
    are its protocol and not `utility_function`s. A class an array, a fork
    or a table names without building is a peer the same way.
  - `dead_code` leaves an override of a library hook to the library however
    deep the subclass sits: dry-monads' `RegularConstructor <
    ::SuperDiff::…::CustomObject` fills the flattener's private `open_token`
    and `close_token` hooks and was left alone, but `TupleConstructor <
    RegularConstructor` overriding the same two (and `CompareTuples`'s
    `build_operation_tree`) were "never called", though deleting them turns
    `Success[` into `Success(`. A private method no ancestor leaves to the
    library is still judged.
  - `repeated_call` leaves alone a deadline loop that names each reading as
    it compares it: ferrum's `Output#wait_for` (`deadline =
    monotonic_time + timeout; while (now = monotonic_time) < deadline`) read
    as one value to name, and naming it freezes `now`, so the loop never
    ends. The comparison's operand is read through its parentheses and the
    local it writes, as README's "a deadline loop" says.
  - `repeated_call` leaves alone a read that draws the next item from a
    stream or a queue (`gets`, `getc`, `getbyte`, `readline`, `readpartial`,
    `read_nonblock`, `recv`, `accept_nonblock`, `pop`, `shift`, `deq`, …):
    ferrum's proxy reads the upstream status line and then each header line
    with the same `os.gets(WEBrick::LF)`, and naming the result would reuse
    the status line and never end the header loop. `read` and
    `File.readlines(path)` read twice are still reported.
  - `low_cohesion` reads a computed send that spells a writer (`send
    "#{name}=", value`) as calling every writer, the ones `attr_writer` and
    `attr_accessor` mint as well as hand-written ones, so it touches their
    fields: friendly_id's `Configuration#set`, its mass assignment, reaches
    `model_class=` and `base=`, and the class is no longer split into a
    `@model_class` group and a `@base` group.
  - A class-level finding sits at the class's own file, not at the
    alphabetically first file that reopens it: dry-monads'
    `concrete_inheritance: Dry::Monads::Task` named `maybe.rb:374`, where
    Maybe's file adds `Task#to_maybe`, instead of `task.rb:12`. The site is
    the opening in the file named for the class, else the one with the most
    statements, as rubocop-kata's `Kata/Reopening` chooses; a subclass's
    place in `concrete_inheritance` evidence reads the same way.
- Found by a sixth field test (content-tagger, support, searchkick,
  statesman, pay):
  - A superclass computed by a call (searchkick's `< Searchkick.parent_job.constantize`,
    pay's `ApplicationRecord < Pay.model_parent_class.constantize`) is a parent
    the project cannot see, as `< ActiveJob::Base` is: the classes built on
    the same expression are kin, so searchkick's three jobs' `perform` is their
    shared role and not a `utility_function`; the classes under it are hosted,
    so `dead_code` leaves pay's `Subscription#unpaid?` and
    `Stripe::PaymentMethod.sync_setup_intent` to the framework; and a class
    built on it is a framework adapter. `dead_code` still judges a class
    under a parent Ruby builds (`Struct.new(…)`, `Data.define(…)`).
  - An engine's `ApplicationRecord` is framework plumbing however its models
    spell it: the adapter question is asked of the constant a reference
    resolves to, not of its first written segment, and an adapter's heirs are
    read past the engine's namespace. pay's six models wrote
    `< Pay::ApplicationRecord`, so they folded into an `ApplicationRecord`
    package that drew six `wide_edge` findings ("Front ApplicationRecord with
    one facade"), a `mixed_audience` and a place in the cycle. A record
    straight on `ActiveRecord::Base` is an adapter only when it says it is
    abstract or is named `Application…`, so a concrete record with
    single-table subclasses (mailboxer's `Notification`, which `Message`
    extends) stays a package its subclasses fold into.
  - `feature_envy` types a local by its name only if the class declares
    every message the method sends it, as README says, not only the messages
    the codebase itself speaks, when the class's ancestry stays in the
    project: searchkick's `RelationIndexer#reindex` sends `primary_key` to an
    ActiveRecord relation, which `Searchkick::Relation` (the query builder)
    does not declare, so it is no longer told the method "may belong on
    Relation". A class built on a library's parent (a model) still needs only
    the codebase's own messages declared.
  - `nil_check` does not take a reader that answers a literal or memoizes
    one (`def successors = @successors ||= {}`) for the source of a nil:
    statesman's `return if successors.nil?` and `callbacks.nil?` test values
    that are never nil, so "Settle it where the nil is made" pointed at a
    place that makes none. A reader that memoizes a call (`@parent ||=
    find`) may still answer nil and is still the source.
  - A `nil_check` grouped by the nil it tests cites only the lines that
    test that nil, not every check line of the method: searchkick's
    `Query@json` and `Query@highlighted_fields` each named both lines 125
    and 128.
  - The classes one array literal builds side by side
    (`[FeedexSection.new(user), EmergencyContactDetailsSection.new(user)]`)
    are kin, as the two arms of a fork are: the methods they share are a
    protocol the collection is read through, so support's two section
    `#link`s are not `utility_function`s to make private or move.
  - `feature_envy` (and `nil_check`'s typed sources) read what a class
    declares at the path Ruby resolves, not under every suffix of it: in a
    top-level controller `taxon` is `::Taxon`, and content-tagger's
    `ProjectsController#taxons` no longer borrows `GovukTaxonomy::Taxon`'s
    `name` and `parent_node` to be told it "may belong on Taxon".
  - `repeated_call` reads a literal-key lookup through an attribute reader
    the class declares as the instance variable it is, as README's "plain
    read of self" promises: searchkick's `options[:routing]` twice (with
    `attr_reader :options`) is style like `@options[:routing]` twice (33 of
    its evidence lines). A helper's result, or a framework method's such as
    `params`, read twice is still reported.
  - `state_sprawl` counts the fields an `attr_writer` or `attr_accessor`
    mints: set from outside and read back, they are parked between calls
    and weigh two. content-tagger's `Taxon` holds 17 fields, not the 4 its
    hand-written writers set, and support's ActiveModel request forms
    (`TimeConstraint`'s 10 accessors) are no longer invisible to it. A
    constructor that sets a field through its own writer (`self.red = red`,
    ferrum's `RGBA`) sets constructor state, as `@red = red` does.
  - `nil_check` leaves Ruby's nil to Ruby when the receiver is an owned
    constant that only holds a core value: content-tagger's
    `PATH_COMPONENTS_REGEX.match(base_path)` answers nil for no match, as the
    same regexp written inline does, so `Taxon#base_path=` checking it is no
    finding. A class the project owns still answers for its own nil.
  - A method that overrides what a core ancestor defines stays a hook when
    the project sends that message too: pay's
    `Braintree::AuthorizationError#message` overrides `Exception#message`,
    which every `rescue => e; e.message` reads, and is no
    `utility_function` to make private. `bin/inventory` records each core
    class's methods (`inherited` in `inventory.yml`).
- Found by a fifth field test (50 more MIT-licensed codebases):
  - A file is generated when its leading comments (before the first line of
    code) say "generated by" or "generated from", `@generated`,
    "auto-generated"/"autogenerated", "a generated file", "do not edit/modify"
    or "has been generated": stripe-ruby's `# File generated from our OpenAPI
    spec` (1,249 of its 1,294 files; 86 s → about 3 s) and nokogiri's jars
    header are skipped and counted on stderr. Prose after the first code line
    never marks a file, and the old ten-line limit is gone.
  - A folder named `templates` or `*_template` below `lib/` that holds template
    or project files (`.erb`, `.tt`, `Gemfile`, gemspec, `Rakefile`) is a
    project template a gem copies into new projects (bridgetown's
    `site_template/`, whose `SiteBuilder` closed a false cycle; middleman-cli's
    `templates/`): left out and counted on stderr ("in project templates").
  - Ownership matches names as Ruby spells them: a root the project opens and
    also reads under a differently cased twin it never opens is its own
    (npq-registration's `Omniauth` beside the gem's `OmniAuth`, whose dead code
    the gem-patch rule had silenced), and a root the project's own `require`
    paths name outside its files is the gem's (`require "gds_api/…"` →
    `GdsApi`).
  - `dead_code` frames a module included into a class with a foreign
    superclass like the class: its private methods may be that superclass's
    hooks (solid_cache's `Store::Api#read_multi_entries`, simple_form's
    `CollectionExtensions#render_collection`). Constants of a namespace an
    interpolated `eval`/`class_eval` string runs in are never "never referred
    to" (kaminari's `FirstPage`, `LastPage`). `X.class_eval do … end` and
    `X.prepend(Module.new do … end)` patch `X`: a dependency's class keeps the
    methods as its API, and `module_initialize` no longer takes such a block
    (bridgetown's `Samovar::Output::UsageFormatter.class_eval do def
    initialize`) for a mixin: it judges modules only.
  - `assumed_state` counts a computed `instance_variable_set` anywhere in the
    class or its ancestors, whatever method reaches it (caxlsx's `b=` writers
    → `set_run_style`); a literal one on an instance any method builds of the
    class, through a local or a `.tap { |x| … }` (bridgetown's
    `ConfigurationDSL@context`); and never judges a class whose lineage runs
    through a class the project only reopens under a dependency's root
    (middleman's `Tilt::HamlTemplate@options`).
  - `manual_dispatch` takes a `respond_to?` probe on a receiver typed only by
    its name for a duck test unless that class or its family answers the
    message (haml's `template.respond_to?(:type)`, refinerycms's
    `image.respond_to?(:length)`).
  - `low_cohesion` joins every group through a method that reads fields by
    computed name (`instance_variables`, `instance_variable_get(ivar)`), in the
    class or a module it includes (caxlsx's `PageMargins`, `SheetView`,
    `DataValidation`, `IconSet` and `SerializedAttributes`).
- Found by a field test on 50 more MIT-licensed codebases:
  - `utility_function` never calls stateless a method whose body holds code
    hashira cannot read: an x-string (`` `self.write_proc(s)` ``, `%x{}`), an
    `eval`/`class_eval`/`instance_eval`/`module_eval` string, `binding` or
    `local_variables` (47 of opal's corelib findings).
  - `assumed_state` counts a literal `instance_variable_set` on a peer the class
    builds (roda's `TypecastParams::Params.nest`), a computed set a subclass's
    constructor reaches (pagy's `assign_and_check`), never judges a class whose
    code holds an `eval`'d string or an x-string (active_merchant's generated
    writers), and leaves a `def` nested in a method to the class it is defined
    on (shoulda-matchers' `def subject` in
    `::ActionController::TestCase.class_eval do … end`). get-into-teaching's
    `Agency#key`, which reads an `@city` nothing sets, is still reported.
  - `dead_code` reads a constant reached through a computed scope
    (`journey::SlugSequence::RESTRICTED_SLUGS`, `presenter::SEARCH_FIELDS`) as
    a use of every owned constant of that name; leaves to a dependency the
    methods the project patches into its namespace
    (`Rack::PageCaching::Utils.gzip_level`), into a module it prepends into a
    dependency's class (kamal's `SSHKit::Backend::Netssh`), or into one a
    plugin hook includes, `send(:include, …)` too (padrino's `dispatch!`); and
    knows Ruby 4.0's `instance_variables_to_inspect` and ActiveModel's
    `use_relative_model_naming?`, `i18n_scope` and `persisted?` as hooks.

- Read on the trifecta's own code (self-hosting):
  - `low_cohesion` links a class's methods through the project modules it
    includes, whose methods call back into the class (kimera's
    `Baseline::Entry` reaches `matching` through `IgnoreList::Drift`), and a
    computed send (`__send__(command(name))`) to every method the class names as
    a symbol, its dispatch table.
  - `repeated_call` takes the same call again, in the arm of a test of its first
    answer that falls back from it (`outcome.lost? ? attempt(job) : outcome`),
    for a retry, not a repeat.
  - `change_coupling` leaves out a pair where one file only loads the other or
    lists its path (a registration such as a list of harness-critical files);
    with a constant reference between them it stays an explicit finding.
  - `fragmentation` leaves a helper that a subclass overrides out of the path:
    it is a template hook (a base check's `detail` or `evidence`), and merging
    it into the entry would remove the extension point.
  - `repeated_conditional` counts a test in a trailing condition
    (`@job.claim! if @job.state == :open`) or in a command's argument as made
    before that command, not as a recheck after it: the condition and the
    argument run first.
- Namespace packaging keeps an engine's `Engine` class and a namespace's value
  constants (rails_admin's `EXTENSIONS`, `AUTHORIZATION_ADAPTERS`) in the
  namespace's own `(root)` package instead of making each a package.
- `assumed_state` counts a computed `instance_variable_set("@#{key}", …)` as
  assigning only where the class's construction reaches it: through its
  `initialize`, `super` and the methods they call. fog's `Real` services, whose
  `initialize` runs `setup`, stay quiet; the `Mock` services, whose
  `initialize` never does, are reported again.

From the third field test (thirty MIT-licensed codebases):

- Ownership is resolution, finished: a namespace is the project's only where
  the project opens it with definitions (or Zeitwerk makes it of a folder); a
  dependency's root in `Gemfile.lock`, the `Gemfile` or a gemspec is foreign;
  a file path or a derived class no longer claims a namespace (early-careers-
  framework's and signon's `Devise::Models` were reported dead).
- No suffix ownership anywhere in the smells; an unknown type stays unknown,
  never the method's own class (rails_admin's `value.respond_to?(:name)`); a
  type test (`case`/`when`, `case`/`in`, `is_a?`) outranks a local's name
  (spoom's `node.parent` on a Prism node was read as a `FileTree::Node`).
- manual_dispatch: a computed `respond_to?` message is never one the codebase
  defines (devise's `respond_to?(home_path, true)`).
- dead_code: a constant handed to a library resolves with the nesting it is
  written in, and `X.include(self)` hands over the enclosing module
  (rails_admin's `user_for_paper_trail`, early-careers-framework's
  `WizardRouter`); a type whose body runs code at load is used (signon's
  Warden hook); a superclass constant that aliases a framework class leaves
  the project (good_job's `BaseRecord < ActiveRecordParentClass`).
- assumed_state: a computed `instance_variable_set("@prefix#{…}", v)`
  assigns every read with that prefix (fog-openstack's `Storage::Real`).
- low_cohesion: a computed `send("matches_on_#{name}?")` links the caller to
  every method its literal parts spell (mail's `HasSentEmailMatcher`).
- utility_function: `Mock` is a stand-in, like `Fake` (fog-openstack's 190
  `Mock#<request>` findings).
- A Rails app whose only top-level constant is a class with a nested constant
  no longer crashes.

From the second field test (twenty MIT-licensed codebases):

- Ownership is resolution: a constant is the project's only if the project
  defines it as Ruby would resolve it (lexical nesting, `::` cbase), never by
  a suffix. `case x when ::String` beside an owned `Types::String` is not
  manual dispatch (rails 106, mongoid 38 findings), and a subclass of a core
  class the project reopens (`class Label < String`) is not concrete
  inheritance.
- dead_code: Zeitwerk folder namespaces under `app/*` are modelled, so a
  compact `class Wizard::Step` inside `module Steps` lands where Rails puts
  it; a library's mixin under a namespace the project also uses stays the
  library's (its hooks are not dead); a namespace that only wraps a hosted
  class (`module RuboCop; module Cop; class MyCop < Base`) is not dead;
  `Backends.const_get(name)` inside a module reaches what sits under
  `Backends`; several directories share one project root, whatever their
  order (rails' frameworks read each other's tests).
- control_parameter counts a caller only where its receiver is the method's
  class (self, the class, an object it builds, a variable named for it); an
  unrelated `@items.build(:line)` no longer turns a factory's argument into a
  flag, and a branch that only builds an object maps to a value.
- assumed_state counts writers an `attr_accessor(*OPTIONS)` mints from a list
  the class declares, and writes in a block the class body hands its DSL
  (`start { @mode = … }`, `before_action { … }`).
- repeated_call reads `render … and return` as leaving the method.
- repeated_call sees a value change between two calls when an instance
  variable is assigned between them (`flips[@active]` before and after
  `@active = id`), and when the first call sits in a trailing `if`/`unless`
  whose statement writes what it reads (`at += 1 if @source[at] == "^"` runs
  the condition first).
- nil_check reads `@x = v if @x.nil?` as memoization.
- duplication reads the rows of a literal table as a list even when their
  literal lists differ in length.

From the field test on ten MIT-licensed codebases:

- Constants resolve the way Ruby does: a `::`-rooted class written inside a
  module is the top-level one; a qualified constant is looked up through the
  ancestors of the type it names; `Error` and `Sequel::Error` are one constant
  to wide_edge and mixed_audience; a framework adapter's superclass resolves
  where it is written, so a namespace mirroring a library's no longer hides
  real cycles.
- dead_code: top-level code in a file that defines a type is charged to that
  type; names built around a literal suffix or namespace prefix reach what they
  can name; modules handed to a library are hosted; constants of a class whose
  ancestry leaves the project are hosted; `self.class::X` reads `X`; a private
  method of a class extending a library type may fill a template hook;
  documented Devise, FriendlyId and routing-constraint hooks are contracts; a
  computed `const_get` reaches the constants under its receiver.
- fragmentation follows only private helpers one method calls, so a public API
  is no longer advised merged into its caller, reports a knot once, and past
  fifteen private steps names the object hiding in the class instead.
- Smells judge only what the project owns: a reopened core or library class
  is its owner's (manual_dispatch over `Array` and `Symbol`, assumed_state on
  `Gem::DocManager`); a bare call's nil is the project's only when the class
  answers it; `instance_variable_set` assigns.
- low_cohesion reads an inherited constructor; concrete_inheritance tells a
  factory only subclasses call from one that builds the parent; duplication
  reads `CONST.each_value(&:freeze)` as part of a declaration and two short
  lists that share only their shape are not a clone; utility_function's role
  exemption reads roles peers get from mixins.
- Cognitive complexity charges each change of boolean operator in a mixed run,
  in source order, as the SonarSource specification does (`a || b && c || d`
  is +3).
- roll_call needs the shared words to be most of every list, ignores column
  and schema words (`id`, `created_at`, `type`, `properties`), and names each
  list's file and line.
- A grouped message_chain of one method says it "reaches", not "reach".
- repeated_call reads `it`, Ruby 3.4's implicit block parameter, as the local
  it is: `it.name` twice is style, as `row.name` twice already was.
- With no code in `lib/`, hashira no longer stops at "no lib/ directory" when
  a gemspec says where the code lives.

- The duplication exemption for calls into an abstraction the project already
  has now covers a test block: `test "..." do`, `it`, `specify` and `example`
  define a method just as `def` does. Two tests whose body is one call to the
  project's own assertion, differing only in what they pass it and in their
  names, were reported as a clone, while the same bodies under `def test_...`
  were not (Campfire).
- `roll_call` reads each array literal and hash on its own. It used to pool
  every word a file lists into one set, so separate lists that only shared a
  few words with each other became one roll: a controller's
  `only: %i[show edit update]` and `only: %i[new create]`, next to the
  `resources ... only:` lists in routes, was reported as the hand-kept list
  "create, edit, new, show, update" (Campfire). A roll is now a set of words
  that one literal in each file holds whole.
- `roll_call` charges each file to the package its definitions live in. Under
  namespace packaging (every Rails app) it asked for the package of an empty
  nesting, so every file outside the web layer landed in the root package and
  a roll could only ever span "(root)" and "(web)".
- `roll_call` leaves a Rails app's lists of REST actions alone (`index`,
  `show`, `new`, `create`, `edit`, `update`, `destroy`). Routes and
  controllers both have to spell them, and Rails, not the app, owns the words.
- Under namespace packaging, analyzed tests (every file under the Rails root's
  `test/` or `spec/`) are one "(test)" package that depends on what it tests
  and is no package's client. A test joined the package whose namespace it
  was named into. A `Users::SidebarsControllerTest` folded into `User`, so its
  edges to view helpers and caching concerns made the model look unstable
  (Campfire's `Room -> User` SDP finding). A `WebPush::ConnectionsTest` that
  includes a helper building `WebPush::Connections::HTTP` made a cycle that
  existed only in test code, and it merged into the model cycle: the finding
  listed `PushServiceTestHelper` as a member, and test references raised its
  cut from 15 refs to 21. Run with `test/`, Campfire's cycle is now the one
  `app lib` reports.

- `dead_code` no longer reports a class the project reopens but leaves to its
  owner: Ruby's (`class String`) or one opened in a library's namespace
  (`class ActionText::Content::Filters` in `lib/rails_ext/filters.rb`).
  References to such a class never resolve to the project, so it was always
  "never referred to", even with `ActionText::Content::Filters.new` in plain
  sight (Campfire). The methods the project adds to it are still judged.
- `state_sprawl` weighs fields a constructor takes from its arguments in one
  parallel assignment (`@title, @body = title, body`) as inputs, as it did
  `@title = title`, pairing them by position. Campfire's
  `WebPush::Notification` weighed 8 for eight fields its constructor only
  stores.
- `repeated_call` counts the plain reads one run makes. A cheap read made at
  most twice per run is style, however many exclusive `when` arms repeat it:
  Campfire's `@room.messages` was reported "× 5" across three arms that read
  it twice, twice and once.
- A literal that spells bytes UTF-8 cannot read (`"\xFF".b`, a binary
  protocol's magic number) no longer stops the run with "invalid byte sequence
  in UTF-8": every analyzer reads a literal's text with such bytes replaced by
  U+FFFD. Files are read the same way: in the encoding their magic comment
  declares (`# encoding: Shift_JIS`), with a binary file's high bytes and
  stray bytes replaced, so their names, comments and evidence reach the
  report, the JSON and the baseline as UTF-8. A single such file made hashira
  unusable on its whole project.
- `middle_man` counts a forwarder only when it passes the method's block
  through unchanged, as it already required of the arguments. A call given a
  block of its own does the method's work: a counter whose methods each run
  `@mutex.synchronize { ... }` was reported as forwarding to `@mutex`.
- `duplication` counts the block a call hands a shared method as part of what
  it passes, like its arguments. Campfire's `edited_meanwhile` and
  `boosted_meanwhile`, each one call to `meanwhile(email, name) { ... }`, were
  reported as "2 similar fragments" and told to call one shared method, which
  they already do. Such a call is set aside before the smaller clones inside
  it are weighed, so copies within the blocks are still reported.
- The analyzed project's root is the nearest folder holding a project marker
  (`.git`, a `Gemfile`, a `*.gemspec`) or hashira's own files, so a project
  checked out inside another (a corpus under `eval/tmp`, a vendored gem) no
  longer reads the enclosing project's baseline and config.
- A baseline whose analyzers or directories are listed in another order no
  longer blocks the ratchet.
- `state_sprawl` no longer mixes up nodes by offset in a class reopened
  across files.

- `feature_envy` no longer envies core values (locals built from literals,
  constants, `params.permit`, `.to_h` or `.map`), `fetch(:k, default)`, a
  mapper whose reads all feed a hash, keyword or `new`/`render`/`update!`
  argument, a sum type normalised with `is_a?`, fields passed alongside their
  whole, or a method that fills a polymorphic role.
- `utility_function` and `feature_envy` treat fakes and duck-typed
  strategies as peers: classes chosen between at one site
  (`live? ? Launcher.new : FakeLauncher.new`), `Fake::X` and `X`, and
  `Fake*`/`*Stub`/`Null*` classes whose public methods another class has.
- `repeated_call` no longer pairs calls that never both run (one in a
  `return`'s value and one after it), the operand of `defined?`, reads a
  command or hand-off between them must change (`job.finalize!`), match
  globals, or calls in different blocks; `generate` mints. Repeated cheap
  readers and literal-key reads, and a parameter default repeated in the
  body, are rated low; clock reads and reach-through chains are not.
- Duplication reads a class body's reader-block and lambda macros
  (`attribute(:id, &:id)`, `belongs_to :tenant, default: -> { Current.tenant }`)
  as declarations, ignores macro names a class body repeats when judging
  structure, skips a lone log line or error report, and drops call sites of a
  method the project already defines and inverse pairs (`lock`/`unlock`).
- `manual_dispatch` passes over protocol probes (`close`, `read`, `to_hash`,
  `call`, …), the `method_missing`/`respond_to_missing?` pair, probes on a
  library's objects (a rescued exception) and nil checks in disguise
  (`respond_to?(:positive?)`).
- `control_parameter` treats a comparison with anything but a literal or
  constant as data (`current_epoch == expected_epoch`), and a conditional
  that only maps a flag to literals or translation keys as a lookup.
- `nil_check` skips a validator's guard on an attribute a presence validation
  or required `belongs_to` already covers, and a default supplied where a
  parameter or payload value enters; a `find_by(...).nil?` predicate is told
  to use `exists?`.
- `data_clump` needs the group to travel (one holder passes it to another),
  and ignores polymorphic methods, `_`-prefixed and defaulted parameters.
- `assumed_state` tells an ivar nothing ever assigns (a typo or dead hook)
  apart from one subclasses install.
- `repeated_conditional` splits compound tests into their parts
  (`@closed` and `@closed || @exited`), and ignores database queries and a
  recheck after a command on the same receiver (double-checked locking).

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

- `data_clump` looks for shared parameter groups among the methods that carry
  three or more, from pairwise intersections, instead of every 3-combination
  of a class's methods, and is computed only when reported. A class of 800
  parameterless methods takes 0.5 s instead of 51 s; rodauth takes 2.7 s
  instead of 60 s.

- Duplication tallies a cluster's shapes once and looks for a site's
  enclosing method among its own file's definitions: dependabot-core's 4-gem
  slice takes 38 s against main's 100 s on the same machine.

- Recursion detection looks callees up in a set (rubocop's complexity: 4.5s
  to 0.5s), and duplication computes each statement's silent nodes once per
  file. A full rubocop run takes 34s against main's 40s, with 5% more peak
  memory for the type and call indexes the smells now use.
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
