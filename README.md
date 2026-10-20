<h1 align="center"><img src="assets/logo.svg" alt="hashira" width="360"></h1>

**Coupling, cognitive-complexity, duplication and design-smell analysis for Ruby, read from the AST with [Prism](https://github.com/ruby/prism).**

hashira tells you which file to open first. It reads a codebase four ways —
which packages depend on which, how hard each method is to follow, what has
been copied, and which objects reach into each other — ranks files by cost
against how often they change, and ratchets every finding in CI, so a build
fails on what *this commit* made worse rather than on a score.

- **Precision first.** A finding is advice: move this method, split that flag,
  cut this edge. hashira reports one only where the advice applies to code you
  own. A library's AST node, a public argument, a core collection are not yours
  to redesign, so they are left alone. Each smell section below says what is
  left alone and why.
- **No runtime dependencies.** Prism ships with Ruby 3.4+. What Ruby itself
  defines (core classes, the standard and bundled libraries, `Kernel`'s
  methods) comes from a generated inventory, never from whatever the running
  process happens to have loaded, so two runs on the same code agree.
- **Four analyzers, opt-out.** `--skip` drops any of coupling, complexity,
  duplication and smells.
- **Made for CI.** A committed baseline ratchets edges *and* findings, with
  magnitudes; `--fail-on` gates outright; a `# hashira:` comment silences one
  finding, with a mandatory reason that the report repeats.

Let `billing` and `shipping` reference each other, and hashira names the cycle
and the cheapest edge to cut:

<!-- example: cycle app -->
```console
$ hashira app
Package (folder) metrics for app  (2 packages, 2 files)

package   TC  Ca  Ce     I  Cyc
-------------------------------
billing    1   1   1  0.50  YES
shipping   1   1   1  0.50  YES

Findings (1):
  cycle: billing and shipping depend on each other in a cycle — any change may ripple back around. The cheapest cut is billing -> shipping (1 ref).
      · billing/client.rb:5: Shipping::Rate
```

A healthy project reports `Findings (0): none ✓ — structure is healthy`.

Every console example in this README is run by the test suite against a
fixture, so what you read is what hashira prints.

---

[Install](#install) · [Running it](#running-it) · [Configuration](#configuration) · [Coupling](#coupling) · [Whole-codebase checks](#whole-codebase-checks) · [Rails apps](#rails-apps) · [Complexity and fragmentation](#complexity-and-fragmentation) · [Duplication](#duplication) · [Design smells](#design-smells) · [Hotspots](#hotspots) · [CI](#ci) · [Other formats](#other-formats) · [Design choices](#design-choices)

## Install

```sh
gem install hashira          # or, in a Gemfile: gem "hashira", group: :development
```

Requires Ruby 3.4 or newer.

## Running it

```sh
hashira                        # auto-detects lib/<gem>, or app + lib in a Rails root
hashira lib/myapp              # one directory
hashira app lib                # several — one shared graph
hashira --skip complexity      # drop an analyzer
hashira --kind cycles,smells   # keep only these findings (tables stay whole)
hashira --top 50               # longer tables and findings list
hashira --only app/models      # report only findings in these files; still reads everything
```

With no directory, hashira picks `lib/<gem>` (the one beside `lib/<gem>.rb`, or
the one the `*.gemspec` names), else `lib`, and in a Rails root (a
`config/application.rb`) `app` and `lib`. One directory is descended through
single-folder wrappers, so `hashira`, `hashira lib` and `hashira lib/gem/core`
land on the same packages. With one directory files are named relative to it;
with several, as you would open them from where hashira runs.

The text report is the coupling tables, the complexity tables, the hotspot
rollup and the findings, capped at 25 packages and findings and 10 methods and
files; every capped list says what it withheld, and `--top N` moves every cap.
Findings are dealt out across kinds, worst first within a kind, and a capped
list opens with one line per kind, so hundreds of findings of one kind read as
one fact. Anything hashira had to work around (no git history, a file Prism
could not parse) goes to stderr.

## Configuration

A `.hashira.yml` holds the flags you would pass every time, each key a flag
without its dashes, plus `directories` and `checks`:

```yaml
directories: [app, lib]
skip: duplication
fail-on: cycles
package-by: namespace
checks:
  duplication: false               # turn a kind off
  nil_check: true                  # or an opt-in kind on
  complexity: { threshold: 12 }    # or move a threshold
  fragmentation: { helpers: 6 }    # fragmentation has two limits
  indirection: { threshold: 3 }    # (a setting turns an opt-in kind on too)
layers: [web, app, domain]         # outermost first; see Layers below
```

`checks: all` turns every kind on. Kinds with a threshold, and what reaches it:
`complexity` (a score of 10 or more), `fragmentation` (`helpers:` 4 or more,
averaging `lines:` 3.5 or fewer), `indirection` (2 or more hollow helpers),
`boundary_sprawl` (12 or more methods), `wide_edge` (5 or more constants),
`state_sprawl` (a weight of more than 4), `repeated_conditional` (more than 2
tests), `low_cohesion` (classes of 6 or more methods) and `middle_man` (3 or
more forwarders). `change_coupling` takes `commits:`, `degree:` and `files:`,
and `dead_code` takes `roots:` (see [whole-codebase checks](#whole-codebase-checks)).
`checks: { all: true, nil_check: false }` turns every kind on but the ones
it names. A flag on the command line wins over
the file, and a key the command line rules out sits that run out (`fail-on` under
`--json`). `--config PATH` reads another file; `--no-config` ignores it.

### Which kinds are on by default

A kind is on by default when it reports a measurement (`complexity` and the
coupling kinds), or when its precision, measured independently, clears one in
three. Two raters labelled findings on rubocop, faraday and rubygems.org without
knowing which version of hashira had reported them: a sample drawn before the
rules below were last changed, and a fresh holdout drawn after (they agreed on
92% and 87%, κ 0.65 and 0.66; see [eval/results](eval/results/README.md)). The
raters were independent AI reviewers: separate model instances that saw only the
shuffled, version-blind findings and the corpus source, not hashira's code or
labels. No human has relabelled them yet. True findings, per rater:

| kind | sample | holdout | pooled | default |
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
| indirection | — | 2/2, 0/2 | 2/4 | opt-in |
| dead_code | 13/13, 13/13 | — | 26/26 (100%) | on |
| change_coupling | 1/3, 2/3 | — | 3/6 | opt-in |

Six class-level kinds came later and were measured the same way, on every
finding the corpus gives them up to 25, by one independent rater (an AI
reviewer that saw only the shuffled findings and the corpus source). None
clears the bar, so all six are opt-in:

| kind | corpus findings | true |
| --- | --- | --- |
| message_chain | 81 | 2/25 (8%) |
| concrete_inheritance | 5 | 1/5 |
| refused_bequest | 1 | 0/1 |
| low_cohesion | 3 | 0/3 |
| data_class | 1 | 0/1 |
| middle_man | 0 | — |

`fragmentation` is on: a separate blind readability study measured it (see
[Complexity and fragmentation](#complexity-and-fragmentation)). `assumed_state`,
`boundary_sprawl` and `module_initialize` are too rare in the corpus to measure,
so they are opt-in too, and so is `change_coupling`: three findings at its
limits, and 5 of 34 labels true on a looser sample (degree 30% and over).
`layer_violation` is on whenever `layers:` are declared. `--kind` and `--fail-on` turn on the kinds they name,
and a `checks:` setting for a kind turns it on.

hashira finds the file, and the baseline, in the analyzed project's root: the
nearest folder at or above the analyzed directory that is where hashira runs or
holds a `.hashira.yml`, a `hashira_baseline.json`, `.git`, a `Gemfile` or a
`*.gemspec`. A project checked out inside another stops at its own root. So `hashira ../other/lib` reads and writes the other project's
files, not the ones where you stand. Paths inside the file are read from that
root.

### Suppressing one finding

A comment silences the findings of the kinds it names, on its own line
(`hashira:disable`) or on the next one (`hashira:disable-next-line`). The
reason after `--` is required:

<!-- example: suppressed lib/shop --kind complexity -->
```console
Findings (0):
  none ✓ — structure is healthy

Suppressed (1):
  ~ complexity/Shop::Pricing#total — legacy rules, rewrite scheduled (pricing.rb:3)
```

from

```ruby
# hashira:disable-next-line complexity -- legacy rules, rewrite scheduled
def total(order)
```

A finding is matched by any line it names (a method's `def`, each site of a
clone), so one directive can sit beside the copy you mean. A directive that no
longer silences anything is listed as unused, and a malformed one (no reason,
an unknown kind) stops the run with its file and line.

## Coupling

Every folder under the analyzed directory is a **package**:

- **TC** — classes and modules it defines (a namespace wrapper with no methods
  does not count).
- **Ca** / **Ce** — how many packages depend on it, and how many it depends on.
- **I** — instability, `Ce / (Ce + Ca)`: 0 is a foundation everyone leans on, 1
  is free to change. Neither is good or bad; the findings are about arrows that
  point the wrong way.

An edge A→B exists when a file in A references a constant B declares,
resolved the way Ruby resolves it: lexical nesting first, then the innermost
class's ancestors, then top level. `Billing::Client` inside `module Shipping` is
not `Shipping::Billing::Client` unless that exists. Ruby's own constants never
belong to a package, even where the project reopens them. Each edge carries a
weight, the number of references behind it.

Findings:

- **cycle** — packages that can all reach one another, reported once per knot
  with its **cheapest cut**: the set of edges of least total weight whose removal
  leaves no cycle (a minimum feedback arc set). Among cuts of the same weight
  it keeps the edges into the packages more others depend on (the higher Ca)
  and cuts the ones out of them, so the package everything rests on stays at
  the bottom. It is exact for knots of up to twelve packages; beyond that it is
  a heuristic, and the message says "the cheapest cut found". The evidence is
  the references on those edges — the lines to change.
- **sdp_violation** — a stable package depends on a less stable one, against
  the Stable Dependencies Principle. It needs a gap of at least 0.10 and three
  edges at each end; edges inside a cycle are the cycle's.
- **mixed_audience** — a package whose constants split into parts that disjoint
  sets of clients use: separate packages in disguise. The finding names the seam
  and any shared base layer.
- **wide_edge** — one package reaching into another through five or more
  distinct constants; a facade would narrow it to one.
- **roll_call** — the same list of three or more words maintained by hand in
  three or more files across packages; the list wants a single owner.

## Whole-codebase checks

These checks read the whole codebase at once: the layering you declare, the
code nothing reaches, and the files that keep changing together.

### Layers

Declare the layers in `.hashira.yml`, outermost first. Each is a package name,
or a name with the packages and paths (from the project's root) it holds:

```yaml
layers:
  - web: [app/controllers, app/views, app/helpers]
  - app: [app/jobs, app/services]
  - domain: app/models
```

A layer may use the layers declared inside it, never one outside it.
**layer_violation** reports every reference that points outward, one finding
per pair of layers, with the package edges to cut, the cheapest first:

<!-- example: layers app --kind layer_violation -->
```console
Findings (1):
  layer_violation: billing depends on web, an outer layer, through 1 ref — a layer may depend only on the layers declared inside it. Cut billing -> web (1 ref).
      · billing/ledger.rb:5: Web::InvoicesPage
```

A file is in the layer whose path holds it or whose package it charges, a
constant in the layer of the files that define it (one defined in two layers is
left alone), and a file in no layer is not judged. The ratchet holds a pair by
its count of references, so a new one fails the build. When the code leans the
other way (another order of the same layers, found by the same exact search as
a cycle's cheapest cut, would leave fewer references pointing outward), the
finding says so, naming that order, which keeps yours wherever the references
leave it free: the declaration may be what is wrong. With no `layers:`, the
check does nothing; declared, it is on, since the intent is yours.

### Dead code

**dead_code**, on by default, reports methods and constants defined in the project that
nothing in it reaches. A constant is reached when the constant-reference graph
resolves a reference to it or to anything inside it; a method when any call,
symbol or string in the project names it (`send(:name)`, `before_action
:name`, `respond_to?(:name)`, a `delegate`, a string `class_eval`), when a
call builds its name from a literal prefix (`public_send("on_#{event}")`
reaches every `on_` method), or when a word in the project's other files names
it: specs, views, rake tasks, configuration, scripts. Matching is by name, not
by type, so a method called anywhere under its name counts as used: hashira
misses dead code rather than report live code. Also left alone:

- Ruby's protocols and hooks (`to_s`, `each`, `==`, `call`, `initialize`,
  `inherited`, `method_missing`, `as_json`, …) and a method that calls `super`,
  which overrides something its caller reaches.
- Every method of a class that sends itself a computed name (`send(name)`), and
  of its descendants.
- Subclasses registered through an `inherited` hook or found with
  `.subclasses` or `.descendants`.
- A `ClassMethods` module, and the public methods of a class whose ancestry
  leaves the project (`< ActiveRecord::Base`, `include Sidekiq::Job`) or of a
  module mixed into one: the framework calls them.
- A class the project reopens but [leaves to its owner](#coupling): Ruby's
  (`class String`), or one opened in a library's namespace
  (`class ActionText::Content::Filters`) that the project does not otherwise
  claim. References to it never resolve to the project, so they cannot show it
  is used. The methods the project adds to it are still judged.

The roots differ by kind of project. In a library, every public method and
public constant is its users' API, so only private methods and
`private_constant`s are judged. In a Rails app, controllers, helpers, views,
jobs, mailers, channels, policies, components and validators are the
framework's entry points, and everything else is judged. `roots:` names more:
constants (`MyGem::CLI`, with everything inside), methods (`MyGem::CLI#run`)
and paths (`lib/my_gem/plugins`). In a library, naming roots says what the API
is, and the rest of the public surface is judged too.

<!-- example: dead lib/app --kind dead_code -->
```console
Findings (1):
  dead_code: Invoice#legacy_total is never called in the project (invoice.rb:8). Delete it, or name it in dead_code roots if code outside the project uses it.
```

### Change coupling

**change_coupling**, opt-in, reads the git history behind the hotspots: two files in
different packages that changed together in at least `commits:` 5 commits, and
in at least `degree:` 50% of their changes (shared commits over the mean of
the two files' commits, Tornhill's degree of coupling). Commits touching more
than `files:` 30 analyzed files (a rename, a style sweep) are not counted. The
finding says whether one file refers to the other: a pair with no reference
between them is coupled where the code does not show it.

It needs the history: a CI checkout of one commit (`actions/checkout`'s
default) sees none, so the ratchet would find the pairs resolved there. Fetch
the history (`fetch-depth: 0`) wherever change_coupling is gated.

## Rails apps

Layer folders are framework layout, not architecture, so when the analyzed
directory is or sits in a Rails root, hashira groups types by top-level
constant instead (**namespace packaging**), and asks whether `Billing` reaches
into `User`:

<!-- example: rails app -->
```console
$ hashira app
Package (namespace) metrics for app  (4 packages, 4 files)

package            TC  Ca  Ce  I     Cyc
----------------------------------------
Billing             1   2   1  0.33  YES
User                1   1   1  0.50  YES
(web)               1   0   1  1.00  -
...
Findings (1):
  cycle: Billing and User depend on each other in a cycle — any change may ripple back around. The cheapest cut is Billing -> User (1 ref).
      · models/billing/invoice.rb:3: User
```

- **Associations are references.** `belongs_to :user` refers to `User` and
  `has_many :line_items` to `LineItem`, inferred with ActiveSupport's inflection
  rules, including the app's own `config/initializers/inflections.rb`; an
  explicit `class_name:` wins and `polymorphic: true` names nothing.
- **A cut can drop a guarantee.** `has_many :posts, dependent: :destroy` is
  more than a reference: deleting the user deletes the posts (or nullifies
  them, or refuses). When an edge to cut carries a `dependent:` option, the
  cycle finding names it, and the JSON lists it under that edge's
  `guarantees`. Move the guarantee before cutting the edge: to an object above
  both packages, or, for `:delete_all` and `:nullify`, to the foreign key's
  `on_delete`. A foreign key cannot stand in for `:destroy`, which runs the
  records' callbacks.

<!-- example: cascade app --kind cycles -->
```console
$ hashira app --kind cycles
...
Findings (1):
  cycle: Post and User depend on each other in a cycle — any change may ripple back around. The cheapest cut is User -> Post (1 ref). User -> Post carries a dependent: option (has_many :posts, dependent: :destroy at models/user.rb:2) — cutting it drops what deleting the owner does to its records, so hand that to an object above both packages first.
      · models/user.rb:2: Post
```

- **Framework adapters are plumbing.** A top-level class that extends an outside
  class and that the app's classes extend (`ApplicationRecord <
  ActiveRecord::Base`, a `ApplicationCable::Channel`) is not a package anyone
  depends on. A domain base class (`Billing::Base`) stays part of its domain.
- **Presentation stays out of the domain.** Controllers, serializers and
  resources are one `(web)` package, counted once as a client of each package it
  uses.
- **Tests stay out of the structure.** Analyzed, the files under the app's
  `test/` and `spec/` are one `(test)` package: it depends on what it tests but
  is no package's client. A test named into a domain's namespace
  (`WebPush::ConnectionsTest`) and the helpers it includes never join that
  domain's cycles, SDP, audience or wide-edge findings, and never add to a
  package's Ca.
- **Folding.** A package that is part of another joins it, and every fold is
  listed: `base` (a lone class joins its superclass's package), `suffix`
  (`OrderPolicy` joins `Order`), `plural` (`Orders` joins `Order`), `mixin` (a
  module that only includes another).

`--package-by folder` or `--package-by namespace` forces either grouping
anywhere.

## Complexity and fragmentation

Every method gets a **cognitive complexity** score, per the
[SonarSource specification](https://www.sonarsource.com/docs/CognitiveComplexity.pdf):
straight-line code is free, each `if`, loop, `case`, `rescue` and ternary costs
one plus its nesting, `else`/`elsif` cost one, a run of one boolean operator
costs one, and recursion costs one. Blocks and lambdas nest what they hold, a
method defined with `define_method` is scored like any other, and parentheses
do not split a boolean run. **Calls** sits beside it: when the two disagree,
Cog is the one that tracks reading effort. A per-class rollup keeps a class's
total visible after a method is split into five.

Methods at or over 10 are `complexity` findings, with where the points came
from:

<!-- example: complexity lib/shop --kind complexity -->
```console
Findings (1):
  complexity: Shop::Pricing#total — cognitive 11, 14 calls (pricing.rb:3). flatten the branching — guard clauses, early returns, or polymorphism.
      · if +6 (lines 4, 5, 6)
      · elsif +2 (lines 8, 14)
      · else +1 (line 10)
      · boolean +2 (line 14)
```

Splitting a method into helpers lowers every score, and past a point it stops
helping the reader, who now hops between many small methods to follow one piece
of work. **fragmentation** reports an entry, a public method, that reaches four
or more methods of its own class along a path at least two deep, when the entry
and every method it reaches average three and a half lines or fewer (blank and
comment lines aside, a heredoc's lines in). Named predicates (`deferred?`,
`alone?`) are left out of the count: readers keep them as meaning, so the
finding lists them as not counted. A method reaches another by calling it with
no receiver or on `self`, or by `send(:name)` and `method(:name)`; instance
methods reach instance methods and class methods class methods, across every
file that reopens the class.

<!-- example: fragmentation lib/app --kind fragmentation -->
```console
Findings (1):
  fragmentation: Report#render spreads its work over 7 private helpers only it calls, averaging 1.0 lines a method, 3 deep (render → body → lines → line) (report.rb:4). Merge the helpers that only move data into the entry; keep named predicates.
      · title (line 8)
      · label (line 10)
```

The limits come from a blind readability study
([eval/results/fragmentation](eval/results/fragmentation/README.md)): two
raters read 60 entry methods with their helpers, half from two codebases
written in this many-tiny-methods style and half from rubocop, faraday and
rubygems.org, then 60 fresh ones. The rule was set on the first sample. On the
second it flagged 10 entries once predicates were left out of the count; one
rater or both judged 9 of them over-fragmented, and both raters 8. The raters were independent AI reviewers,
separate model instances that saw only the shuffled items, not their sources or
hashira's code; no human has rated them yet.

A helper can also add nothing at all: a private one-liner, called once, that
only passes a call on. The reader still makes the hop. **indirection**, opt-in,
counts those hollow hops. A helper
is hollow when it is private, called exactly once from its own class (never by
name, `send`, or through a receiver), and its body is one call with no decision
and no block, wrapping at most one more call (`def import(rows) =
persist(rows.compact)`). hashira follows each method's single-use helpers and
reports the path holding the most hollow ones once it holds two:

<!-- example: indirection lib/app --kind indirection -->
```console
Findings (1):
  indirection: Importer#run reaches its work through 2 hollow helpers, private one-liners called once that only pass a call on (importer.rb:4). Inline them into their callers.
      · import (line 8)
      · persist (line 10)
```

A helper that decides, computes or runs several statements is the decomposition
you want: it costs nothing and the path runs on through it. A helper two
methods share, or a public one, is an abstraction and ends the path.

## Duplication

Copies of one thing collapse into one finding with every site, and the advice
says what varies between them:

<!-- example: duplication app --kind duplication -->
```console
Findings (1):
  duplication: 3 similar fragments (mass 38) — differs only in literal values — extract a method, pass them as arguments.
      · reports/orders.rb:4-8
      · reports/payouts.rb:4-8
      · reports/refunds.rb:4-8
```

Candidates are every run of one to twelve sibling statements, and every method,
`rescue` clause and `when` arm whole. Exact copies match by shape. Near misses
— a renamed variable, an extra line — are compared only between whole methods,
clauses and arms, and need two things: their node types must share at least 80%
of a longest common subsequence, and the names they use (calls, constants, and
the words in their strings and symbols) at least half. Two methods of one shape
that call different things or say different things are not clones. Candidates
are indexed by their rarest node types; a crowded bucket is split by MinHash
bands over those names rather than skipped.

What is not counted:

- **Lists and declarations.** A run of identically shaped statements (requires,
  routes, registrations), a `case` of three or more same-shaped arms, a class
  body of macros with literal arguments (`has_many`, `validates`, `attribute`),
  constants holding literals or frozen lists of constants, and a constructor
  that only stores its arguments.
- **Error reporting.** A log line (a Logger severity sent to something named
  `log` or `logger`) and a call that hands on the rescued error
  (`rescue => e; Sentry.capture_exception(e)`) weigh nothing as a lone statement,
  and a `rescue` clause that only reports its error weighs nothing wherever it
  sits. A report that builds its own context outside a rescue is code.
- **Calls into an abstraction you already have.** `def patch(path, body) =
  request(:patch, path, body)` beside `def post` is already factored: a method
  whose body is one call to a method the project defines, and whose copies
  differ only in what they hand it, block included (`meanwhile(email, name) {
  boost(message) }`). A test block (`test "..." do`, `it`, `specify`) counts
  as such a method, its name included in what may differ. What the block holds
  is still compared on its own, so copies inside it are a clone.
- **Inverse pairs.** `lock!`/`unlock!`, `enable_x`/`disable_x` share a shape by
  design.

A smaller clone inside a bigger one is reported only when two of its sites lie
outside it. The mass floor rises as a shape gets more common and when two sites
share nothing but their shape. A fragment ten or more files repeat with shared
names is one low-confidence `convention` finding. With git, a clone whose files
both change more than the typical file is called out: one copy gets fixed, the
other drifts.

## Design smells

RuboCop measures one method at a time; these are about how objects treat each
other. Each is reported only where its advice applies to code the project owns.
None clears the precision bar on independent labels, so all of them are opt-in
(see [which kinds are on by default](#which-kinds-are-on-by-default)).

<!-- example: smells lib/app --kind smells -->
```console
Findings (3):
  data_class: Item holds 'base', 'tax', 'quantity' and does nothing else (item.rb:1). Move the code that works on these fields into the class, or declare it a Data value.
      · base
      · tax
      · quantity
  feature_envy: Cart#price refers to 'item' more than to self, 3 to 1 (cart.rb:7). The behavior may belong on Item.
      · item (line 7)
      · self (line 7)
  control_parameter: Cart#print is steered by 'quoted' (cart.rb:9). Split the method, or pass a strategy instead of a flag.
      · quoted (line 9)
```

- **feature_envy** — a method refers to another object more than to itself.
  The advice is to move it onto that object's class, so hashira must be able to
  name the class and see that it owns it: from a constructor (`Widget.build`,
  `Widget.new { |w| }`), a rescue clause, a type test, or the variable's name or
  last words (`item` is an `Item`, `base_dir_config` a `Config`), never the
  method's own class and never a core class (`range`, `set`). That class, with
  its owned superclasses and mixins, must declare every message the method
  sends. A parser node, a source range or an array is not envied. Comparators,
  mappers that only copy fields into a hash or a constructor, and methods that
  fill a role peers share stay quiet.
- **control_parameter** — an argument used only to pick a path, where some
  caller passes it as a literal flag (`true`, `false`, a symbol) by position or
  keyword. An argument that callers compute, a configured style, an argument a
  branch only maps to a value (`flag ? "on" : "off"`), and one compared with
  another value are data. Only a method callers outside the class can reach
  counts: a private or protected helper's flag sits behind the explicit public
  methods that call it.
- **data_clump** — the same three or more parameters travel together through
  three or more methods, one handing the group to another.
- **repeated_call** — the identical call made twice in one method; name the
  result. Identity is by value: a local counts by its binding, a literal block is
  part of the call, a reassignment between makes two values. Left alone: calls
  that mint a fresh value (`dup`, `rand`, `SecureRandom.hex`), a command whose
  result is thrown away, two reads no single run reaches both of, a read after a
  command on the receiver, a reading measured by distance or order against a
  stored copy of its own earlier result (`started = clock.now; ...; clock.now -
  started`, a deadline loop), and a plain read of self, a local or an instance
  variable — no arguments, or literal keys — made at most twice in any one run,
  which is style. A chain (`order.customer.address`), a helper method's result,
  a constant's query (`Time.now` twice is two times) or three reads in one run
  are reported.
- **repeated_conditional** — one class testing the same condition in three or
  more places: a comparison with a fixed value (`@mode == :draft`), a type test
  (`is_a?`), or the subject of a `case`; polymorphism is overdue. A plain truth
  test (`signed_in?`, `@closed`) asks about state rather than dispatching on
  it, and stays quiet.
- **state_sprawl** — a class whose fields weigh more than four. A field the
  constructor takes straight from an argument (`@size = size`, or
  `@w, @h = w, h`) is an input, a component's props or a job's arguments, and
  weighs nothing. Any other field the constructor (or a helper it calls, or a
  callback the class registers such as a `before_action`) sets weighs one. One
  set elsewhere and taken up by another method or a reader is parked between
  calls and weighs two; one set elsewhere that no method reads is handed on —
  to a template, to a caller — and weighs nothing. Memo caches (`@x ||=`,
  `@_x`, `defined?` guards) are not state, and a class whose methods use all
  its constructor fields together is one handle.
- **assumed_state** — an instance variable read that nothing the class can reach
  ever assigns: a typo, or a fragile base class waiting for subclasses to install
  its state.
- **utility_function** — a public method of a class that touches no instance
  state. A module's methods (a mixin, a concern, a view helper) lend behavior
  and stay quiet. A method that fills a role its kin define (`perform` on every job, a hook a
  library calls, a fake's side of a protocol) is exempt.
- **manual_dispatch** — a `respond_to?` probe, or a `case`/`is_a?` ladder over
  two or more of the codebase's own classes or the object's own status. The
  probe must be on self or on an object whose owned class can be named, and ask
  for a message the codebase defines. Ruby's protocols (`:each`, `:to_hash`, …),
  `respond_to_missing?` and the `method_missing` it pairs with are exempt.
- **nil_check** — `nil?`, `== nil`, `when nil`, `blank?`, and, on a value the
  code itself leaves nil, `&.`, `unless x` and `x || default`. Reported only
  where the nil is the codebase's own: its state, a nil it assigns, its own
  method's result, a private method's argument, a literal it built,
  a record fetched from an owned class, or an attribute an owned class declares.
  A public method's argument, a payload read from outside and a library's
  answer (a node's absent receiver, a URI's missing scheme) are someone else's
  contract. A validator's guard on an attribute a presence validation already
  reports, a check replaced by its default, a check whose branch raises (the
  guard asserts against the nil), and a one-line predicate that answers a nil
  test (`def adapter_set? = !@adapter.nil?`) stay quiet. A parameter defaulting
  to nil is the caller's option, not the codebase's nil. A predicate that fetches
  a record only to test it for nil is told to ask `exists?`.
- **boundary_sprawl** — twelve or more methods across three or more files
  type-testing against one foreign root (`Prism`, `ActiveRecord`): a missing
  adapter. A program that interprets a foreign model on purpose can declare it
  (see [CI](#ci)).
- **module_initialize** — `initialize` in a mixin: constructor state carried
  into every includer.

The next six judge how classes are built. They need the class to be the
project's own, so a framework's base classes stay out of all of them.

- **concrete_inheritance** — a class extends an owned class that the project
  also builds on its own (`Report.new` somewhere, or a bare `new` in the
  parent's class methods): the subclass is coupled to a working
  implementation, not to an abstraction. The places that build the parent are
  the evidence. Left alone: a parent that says it is abstract (named `Base` or
  `Abstract…`, a method that raises `NotImplementedError`, `abstract_class` or
  `abstract!`), a parent nothing builds directly, and any hierarchy whose owned
  root extends something the project does not own (`ApplicationRecord <
  ActiveRecord::Base`, `MyError < StandardError`, `Struct.new(…)`): STI and
  exception trees are how those frameworks are meant to be extended.
- **refused_bequest** — a subclass overrides a method an owned ancestor
  implements, only to raise or to do nothing (an empty body or a bare `nil`).
  Left alone: overriding a hook the ancestor itself leaves empty or
  unimplemented (that is filling a template, not refusing it), an override
  that calls `super` or does anything else, and a library parent's methods,
  whose contract is not the project's to redesign.
- **low_cohesion** — LCOM4: a class of six or more methods (constructor aside)
  whose methods fall into two or more groups that share no instance variable
  and never call each other, each group holding two or more methods and a field
  some method reads. Readers, writers and `def_delegators :@field` count as
  touching their field; `send(:name)` and `method(:name)` count as calls. The
  constructor joins what it ties together statement by statement: a field it
  derives from another group's method (`@rules = load_rules`) or from the same
  argument as another field. Left alone: a field only written (handed to a
  template), a lone stateless method (that is `utility_function`'s business),
  modules, and classes under a framework base, whose controllers and mailers
  split into independent actions by design.
- **message_chain** — the Law of Demeter, on one chain: `order.customer.address`
  calls a method on what an owned object's reader returned. Every link must be
  typed and owned: the start (a parameter, local, instance variable or own
  reader) is named for an owned class, that class declares the reader, the
  reader is named for another owned class, and that class declares the next
  message. The evidence shows the classes crossed (`Order → Customer`). Left
  alone: a library's objects (`node.loc.selector`), core collections
  (`items.first`), a hop with arguments or a block (builders, queries), a hop
  back to the same class (fluent APIs), a Struct or Data value's readers, and
  messages every object answers (`to_s`, `==`). This is separate from
  `repeated_call`, which reports a chain read twice whatever its types.
- **data_class** — a class with two or more fields and nothing but attribute
  macros, hand-written readers and writers, and a constructor that only stores
  its arguments. Left alone: `Struct` and `Data` (a value declared as one),
  a class with a superclass or a subclass (an error carrying a code, a base
  others extend), and any method, mixin, class method or constant.
- **middle_man** — a class whose public methods mostly (more than half, and at
  least three) only forward to one field: one call on an instance variable or
  its reader, passing the method's own arguments, and its block if it takes
  one, through unchanged. A call given a block of its own
  (`@mutex.synchronize { @count += 1 }`) is doing the method's work there, not
  forwarding it. A single forwarder is left alone, since it is exactly what
  `message_chain` asks for.
  Left alone too: a class that declares its delegation (`def_delegators`,
  `delegate … to:`, `SimpleDelegator`, `DelegateClass`) — the declaration is
  the design, a wrapper that narrows an interface on purpose, and removing the
  middle man would mean giving that up — forwarding to a collection's own
  protocol (`each`, `size`, `<<`: an encapsulated collection), a facade
  spread over several collaborators, and a method that fills a role its kin
  share.

Class-level kinds judge a class across every file that reopens it.

## Hotspots

The rollup charges each file its methods' cognitive complexity and the distinct
nodes its clone sites cover, and multiplies by how many commits touched it:

<!-- example: duplication app --kind duplication -->
```console
Hotspots — cost × churn (where refactoring pays the most):

file                Cog  Dup  Churn  Rank
-----------------------------------------
reports/orders.rb     0   38      0    38
reports/payouts.rb    0   38      0    38
reports/refunds.rb    0   38      0    38
```

Read it as a work queue. The rank counts churn as at least one, so a
repository without history ranks by cost alone. It is deliberately not a grade: a letter on a healthy
codebase is the same letter on every row.

## CI

`--fail-on` fails the build when findings of a kind exist at all (`cycles`,
`sdp` and `dupe` are shorthands; `smells` is every smell kind). It suits a
codebase that starts clean. The **ratchet** suits every other one: record what
is true now, and fail when it grows.

```sh
hashira --update-baseline        # record today's edges and findings
hashira --ratchet                # fail if either set grew, or a finding got worse
```

A finding with a size — cognitive score, clone mass, sprawl count — is recorded
with it, so a baselined method that gets more complex fails:

<!-- example: ratchet lib/shop --ratchet -->
```console
WORSE FINDING (was 9, now 11):
  complexity: Shop::Pricing#total — cognitive 11, 14 calls (pricing.rb:3). flatten the branching — guard clauses, early returns, or polymorphism.
...
Ratchet FAILED. Either fix what regressed, or — if it is deliberate —
record the decision: update the baseline, or accept it with a reason.
```

and a new one prints in full:

<!-- example: fresh app --ratchet -->
```console
NEW FINDING:
  duplication: 3 similar fragments (mass 38) — differs only in literal values — extract a method, pass them as arguments.
      · reports/orders.rb:4-8
      · reports/payouts.rb:4-8
      · reports/refunds.rb:4-8
```

The baseline also records a trace of each finding (its file and wording,
without line numbers), so a renamed method keeps its finding instead of
reporting one resolved and one new. It records which kinds the recording
hashira knew: after an upgrade adds a kind, its findings are listed as not
ratcheted until the baseline is refreshed, instead of failing the build.
Baselines from earlier versions read compatibly, kinds renamed since included.

`--only FILES --ratchet` asks, from an editor or a pre-commit hook, whether the
files you touched got worse. The whole project is still read — half of what
hashira knows is cross-file — and only the report is narrowed; edges and
removals are left to the full run.

Exit codes: `0` clean, `1` findings or a regression, `2` misuse (bad flags, a
missing directory, an unusable baseline), `3` an improvement the baseline has
not recorded yet, `70` an internal error.

**Accepting by design.** A deliberate finding goes in the baseline with a
reason, and leaves reports and gates:

```json
"accepted": [
  {"kind": "complexity", "package": "Legacy::Importer#run", "reason": "vendored, rewrite scheduled"},
  {"kind": "duplication", "digest": "8bbddea787bc", "reason": "generated adapters, regenerated together"}
]
```

A clone is named by the `digest` of its shape (read it from `--json`), which
survives the lines above it moving.

**Declaring an interpreted model.** A compiler interprets an AST; a serializer a
schema. Instead of accepting a `boundary_sprawl`, declare the boundary, and
hashira checks the declaration: the root must be called, and only through the
named entrypoint.

```json
"boundaries": [
  {"root": "Prism", "role": "interpreted_model", "entrypoint": "lib/my_tool/trees.rb", "reason": "the Prism AST is the input model"}
]
```

## Other formats

```sh
hashira --json            # every finding and row; --top N caps the lists
hashira --json --compact  # one line, for piping
hashira --format dot      # Graphviz
hashira --format mermaid  # Mermaid
```

The JSON opens with `version`, `packaging`, `targets` and `files`, then
`findings` (each with its `digest` and `confidence`), `kinds` (count and files
per kind), `suppressed`, `unused_suppressions`, `accepted`, `packages`, `edges`,
`folds`, `complexity`, `duplication` and `hotspots`. A package with no edges
reports `"i": null`. Confidence is `high` for measurements (complexity, the
structural kinds, clones differing in a literal, receiver or constant), `medium`
for smells, fragmentation, indirection and looser clones, and `low` where
hashira hedges (clones whose control flow differs).

## Design choices

- **Cognitive complexity, not call counts.** Older Ruby metrics charge a point
  per message send, so a flat method calling twenty collaborators outranks a
  knotty one, and a Rails model's column of `has_many` lines tops the list.
  Cognitive complexity makes straight-line code free and nesting expensive.
- **No abstractness, no main-sequence distance.** Those assume formal
  interfaces; idiomatic Ruby decouples by duck typing, so the measure pins to
  zero and restates instability.
- **Ruby files only.** Templates are out of scope. Comments are read only for
  `hashira:` directives.
- **Text is read as UTF-8.** A file is decoded from the encoding its magic
  comment declares, and bytes no encoding reads (a binary file's high bytes, a
  stray byte, a literal's `"\xFF"`) read as U+FFFD, so one odd file never stops
  a run.

## Contributing

Bug reports and pull requests are welcome at
[github.com/giacope/hashira](https://github.com/giacope/hashira). See
[CONTRIBUTING.md](CONTRIBUTING.md) and the [code of conduct](CODE_OF_CONDUCT.md).
`eval/run --hashira PATH` scores a checkout against the evaluation suite in
`eval/`.

## License

[MIT](LICENSE.txt)
