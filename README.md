# hashira

🏛️ **Coupling, cognitive-complexity, duplication and code-smell metrics for Ruby, read straight from the AST via [Prism](https://github.com/ruby/prism).**

hashira tells you which file to open first. It reads a Ruby codebase four ways —
which packages depend on which, how hard each method is to follow, what has been
copy-pasted, and which objects handle each other's data — then ranks every file by
what it costs you against how often you actually change it. Every finding names the file and line behind it, and a committed
baseline ratchets the whole set in CI, so the build fails on what *this commit* made
worse rather than on a score nobody agrees on.

- **Zero runtime dependencies.** Prism ships with Ruby 3.4+; nothing else to install.
- **Reads the AST, never strings.** Every signal comes from the parse tree. Comments and string literals are invisible.
- **Four analyzers, opt-out.** Coupling, complexity, duplication, and smells run together by default; `--skip` drops any.
- **Ranked, not graded.** The hotspot rollup orders files by cost × churn — a work queue, not a letter that reads the same on every healthy repo.
- **Findings, not just a dashboard.** Cycles, SDP violations, complexity hotspots, and clone clusters — each backed by file-level evidence and a plain-language fix.
- **Made for CI.** Ratchet edges *and* findings against a baseline, so no clean slate is required. Or gate outright with `--fail-on`.

Let `billing` and `shipping` start referencing each other, and hashira points to
the cycle and to the cheapest edge to cut:

```console
$ hashira app
Package (folder) metrics for app  (2 packages, 2 files)

package   TC  Ca  Ce     I  Cyc
-------------------------------
billing    1   1   1  0.50  YES
shipping   1   1   1  0.50  YES

Findings (1):
  cycle: billing can reach itself: billing -> shipping -> billing — any change may ripple back around. The lightest edge on this cycle is billing -> shipping (1 ref).
      · billing/client.rb:5: Shipping::Rate
      · shipping/rate.rb:8: Billing::Client
```

A healthy project reports `Findings (0): none ✓ — structure is healthy`.

---

## Contents

[Install](#install) · [Getting started](#getting-started) · [Coupling: how to read the numbers](#coupling-how-to-read-the-numbers) · [Rails apps](#rails-apps) · [Cognitive complexity](#cognitive-complexity) · [Duplication](#duplication) · [Code smells](#code-smells) · [Hotspots](#hotspots) · [How it works](#how-it-works) · [CI](#ci) · [Other formats](#other-formats) · [Why cognitive complexity](#why-cognitive-complexity) · [Why no A, D, or zones](#why-no-a-d-or-zones)

## Install

hashira is a command-line tool. Install it globally:

```sh
gem install hashira
```

Or add it to a project and run it through Bundler:

```ruby
# Gemfile
gem "hashira", group: :development
```

```sh
bundle install
bundle exec hashira
```

Requires Ruby 3.4 or newer.

## Getting started

Point hashira at your code, or run it with no arguments to auto-detect `lib/<gem>`.
Single-folder wrapper chains are descended automatically, so `hashira`,
`hashira lib`, and `hashira lib/gem/core` land on the same package boundaries:

```sh
hashira                        # auto-detects lib/<gem>
hashira lib/myapp              # or point it at a directory
hashira app lib                # or several — one shared graph
hashira --skip complexity,duplication   # coupling + smells only
hashira --skip coupling                 # complexity + duplication + smells
hashira --top 50                        # longer tables and findings list
```

The full text report is the coupling tables, the complexity tables, the hotspot
rollup, and the findings (which include any duplication clusters). It is capped
so a large codebase stays readable — 25 packages and findings, 10 methods and
files — and every list says how many rows it withheld. `--top N` moves all of
them at once; `--json` is never capped.

The heading names the packaging that ran (`folder` or `namespace`), since the
baseline is recorded per mode. Anything hashira had to work around goes to
stderr, never stdout: a directory with no git history (churn reads as zero, so
hotspots rank by cost alone), and files Prism could not parse. On a terminal
you also get a progress line before the parse and a timing line after; piped or
in CI, stdout is byte-identical either way. Here it is on hashira's own source:

```console
$ hashira
Package (folder) metrics for lib/hashira  (11 packages, 129 files)

package      TC  Ca  Ce     I  Cyc
----------------------------------
diagram       3   1   0  0.00  -
hotspots      1   1   0  0.00  -
analysis      3   4   0  0.00  -
report       11   2   1  0.33  -
duplication  14   2   1  0.33  -
smells       24   1   1  0.50  -
ci            8   1   1  0.50  -
complexity    7   1   1  0.50  -
coupling     29   1   1  0.50  -
(root)        5   1   5  0.83  -
cli          11   0   4  1.00  -

Legend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),
        I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)

Dependencies (DependsUpon(refs) -> | <- UsedBy):
  (root)       -> complexity(1), coupling(2), duplication(1), hotspots(1), smells(3) <- cli
  analysis     -> (none)                           <- complexity, coupling, duplication, smells
  duplication  -> analysis(3)                      <- (root), report
  ...

Cognitive complexity — worst methods (Cog = how hard to read, Calls = message sends):

method                                      Cog  Calls  Loc
---------------------------------------------------------------------------------------
Hashira::Coupling::NamespacePrefix#wrapper    4      8  coupling/namespace_prefix.rb:19
Hashira::Analysis::Syntax#anchor              4     12  analysis/syntax.rb:26
Hashira::Smells::Conditions#branches          4     10  smells/conditions.rb:23
Hashira::Coupling::Roster#admit               4      6  coupling/roster.rb:22
...

Per-class rollup (Cog total survives extract-method; Peak is the worst method it hides):

class                           Cog  Methods  Peak
--------------------------------------------------
Hashira::Project                 13       15     3
Hashira::Smells::Conditions      11        9     4
Hashira::Smells::Foreign         11       27     1
...

Hotspots — cost × churn (where refactoring pays the most):

file                     Cog  Dup  Churn  Rank
----------------------------------------------
pipeline.rb               10    0     11   110
project.rb                13    0      5    65
report/text.rb             8    0      4    32
...

Findings (0):
  none ✓ — structure is healthy
```

## Coupling: how to read the numbers

Every folder under the target directory is a **package**. For each one:

- **TC** — how many classes/modules it defines.
- **Ca** — how many packages depend *on* it (afferent, incoming).
- **Ce** — how many packages it depends *upon* (efferent, outgoing).
- **I** — instability, `Ce / (Ce + Ca)`, from 0 to 1.

**I = 0**: everyone depends on it, it depends on no one. That's a foundation,
expensive to change. **I = 1**: nobody depends on it, so it's free to change.
Neither is good or bad on its own; a CLI layer *should* sit at 1.00, a core
domain layer near 0.00. The findings are about arrows pointing the wrong way:

- **SDP violation** — a stable package depends on a less stable one, against the
  Stable Dependencies Principle ("depend in the direction of stability"), one of
  Robert C. Martin's [package principles](https://en.wikipedia.org/wiki/Package_principles).
- **Cycle** — packages depending on each other in a loop.
- **Mixed audience** — the constants of one package split into parts with
  separate client bases: one set of packages leans on one slice, another set on
  a disjoint slice. Each part is a separate package in disguise; the finding
  names the seam, and — when most clients also share a few constants — the
  shared base layer to extract. Composition roots blur the picture only if they
  touch a constant some other client also touches, which facades avoid.
- **Wide edge** — one package reaches into another through five or more
  distinct constants. Every constant on the edge is a reason for the client to
  change; a facade narrows the interface to one.
- **Roll call** — the same list of three or more words (symbols, string keys)
  is maintained by hand in three or more files across packages. The list wants
  to be data with a single owner — a registry the other sites derive from.

Each finding comes with file-level evidence; for cycles, the shortest cycle
path and its lightest edge. What a finding means for your design is your call.

## Rails apps

Rails layer folders are framework layout, not architecture: models will always
touch jobs and mailers, so folder packages under `app/` report idioms as
findings. When the analyzed directory contains a `config/application.rb` (the
Rails root) or sits beside one (its `app` folder), hashira switches to
**namespace packaging**: types group by top-level constant
(`Billing`, `Ci`, `User`) across the layer folders, edges join domains, and the
findings answer the question a Rails monolith actually has — does `Billing`
reach into `Ci`?

```console
$ hashira app
Package (namespace) metrics for app  (442 packages, 3222 files)

package   TC  Ca  Ce     I  Cyc
-------------------------------
Account   26  21  18  0.46  YES
Billing  116  12  11  0.48  YES
Ci       107   9  16  0.64  YES
...
  cycle: Account can reach itself: Account -> User -> Account — any change
  may ripple back around. The lightest edge on this cycle is Account -> User (1 ref).
      · models/account.rb:36: User
      · models/user/signup.rb:32: Account
```

Under namespace packaging, references to app-defined `Application*` base
classes (`ApplicationRecord`, `ApplicationJob`, …) are skipped as framework
plumbing; `--package-by folder` keeps them, so the legacy layer view stays
complete. Constant resolution
follows Ruby's lexical nesting everywhere — a bare `Authentication` inside
`class User` is `User::Authentication`, not a top-level namesake in another
package — which matters most in Rails apps, where nested concerns routinely
shadow top-level names.

Either grouping can be forced anywhere:

```sh
hashira app --package-by folder      # layer view, even in a Rails app
hashira lib/gem --package-by namespace
```

## Cognitive complexity

hashira scores every method with **cognitive complexity**, not an ABC or call-count
metric. The point is to rank methods by how hard they are to *read*, not how many
messages they send:

- **Cog** — the cognitive-complexity score. A flat sequence of calls costs nothing;
  each level of nesting deepens the cost of what sits inside it; a `case` counts
  once regardless of arms; a run of one boolean operator counts once, and mixing
  `&&`/`||` costs more; `elsif`/`else` stay flat instead of compounding.
- **Calls** — the number of message sends, shown side by side. This is what
  call-count metrics rank on; when Cog and Calls disagree, Cog is the honest one.
- **Per-class rollup** — the total complexity of a class and its method count. A
  method-only score vanishes when you split one big method into five small ones;
  the class total doesn't, so the rollup catches that dodge.

Methods over the threshold become `complexity` findings, each with the breakdown of
where the points came from and a suggested refactoring:

```console
  complexity: Shop::Checkout::Pricing#total — cognitive 10, 12 calls
  (checkout/pricing.rb:4). flatten the branching — guard clauses, early returns, or polymorphism.
      · if +8 (lines 6, 7, 8, 12)
      · else +1 (line 9)
      · boolean +1 (line 12)
```

## Duplication

Leave the same code copied across three files and hashira finds the whole family
in one finding — not three pairs — and tells you what varies:

```console
Findings (1):
  duplication: 3 similar fragments (mass 45) — differs only in literal values —
  extract a method, pass them as arguments.
      · reports/orders.rb:1-11
      · reports/payouts.rb:1-11
      · reports/refunds.rb:1-11
```

It reads `.rb` only, so duplication that lives in templates is out of scope. What
it does inside Ruby:

- **Near-miss clones by default.** Every fragment is reduced to its sequence of
  node types, indexed by its rarest types, and candidate pairs are verified with
  a real longest-common-subsequence check. That finds the Type-3 clones — copies
  with a renamed variable or an extra line — that exact structural hashing
  misses. It is always on, and the match carries a score rather than a label.
- **Sliding windows, down to a single statement.** Every contiguous run of
  statements is considered, so a duplicated stretch buried inside a larger method
  is caught, not only whole bodies. Two sibling controllers that drifted apart
  line by line match here and nowhere else: no single subtree of either one is a
  clone of the other. And one statement can be a clone by itself — the block body
  a view helper repeats verbatim is a single expression.
- **Whole methods, `when` arms and `rescue` clauses too.** A one-line method has
  no run of statements at all; without these it would be invisible.
- **Lists aren't clones.** A run of identically shaped statements — a require
  block, a routes file, a column of registrations — is skipped, so windows cut
  out of one don't report a match at every offset.
- **Declarations aren't clones either.** A fragment built only from directives —
  receiverless macro calls with literal arguments, the `has_many` /
  `validates` / `attribute` spine of a model or a serializer — is a schema, not
  copied logic; extracting it only hides what the class declares. Two models
  that open the same way are two models. As soon as a fragment carries logic —
  a block, a method, a variable, a receiver, a branch — it counts again.
- **Clusters, not pairs.** All copies of one thing collapse into a single
  finding with N sites, so the report reads as "fix this once," not a wall of
  pairwise matches.
- **It tells you how to fix it.** hashira diffs the copies and classifies what
  varies: only literals → extract a method and pass them as arguments; only the
  receiver → extract a method taking it, or use polymorphism; a constant →
  parameterize it; the control flow itself → extract the common core, but verify
  by hand (flagged lower-confidence).
- **Noise control, from the repo itself.** A shape that recurs everywhere is a
  Ruby idiom, not duplication, so the mass floor rises as a shape gets more
  common, and rare token types drive matching while common ones don't. The floor
  rises again when two sites share nothing but their shape: `each_cons(2).min_by
  { }` and `combination(2).select { }` are the same tree by coincidence, and a
  match with no name in common has to be much bigger to mean anything.
- **Churn overlay.** When git is available, clones whose files both change often
  are called out — that's where one copy gets fixed and the other silently
  drifts. Silent when git isn't there; no configuration either way.

## Code smells

RuboCop counts lines and branches inside one method; design smells are about how
objects treat each other, and no line count sees that. hashira ships the twelve
smells that carry that design signal — the object-relationship kinds, not the
naming, size, and style checks a linter already argues about — read from the
same parse trees the other analyzers already built:

```console
Findings (2):
  feature_envy: Cart#price refers to 'item' more than to self (cart.rb:12). The behavior may belong on item.
      · item (lines 13, 14)
  control_parameter: Report#write is steered by 'quoted' (report.rb:31). Split the method, or pass a strategy instead of a flag.
      · quoted (line 32)
```

What each one catches:

- **feature_envy** — a method refers to another object more than to itself; the
  behavior probably belongs over there. Stays quiet when the method's own body
  proves the envied thing is foreign — type-guarded (or table-dispatched) only
  against constants the codebase never defines, read purely through literal
  keys (`msg["id"]`), built from a literal or derived from a foreign call in
  the method itself, rescued from a foreign error class, or consumed by a
  stateless converter that ends by building a typed object — because "move
  the method" needs a destination you own.
- **boundary_sprawl** — 12+ methods across 3+ files each type-guard against the
  same foreign root (`Prism`, `ActiveRecord`, ...). One method inspecting a
  foreign type is a fact of life; a sprawl of them is a missing adapter.
- **utility_function** — a public instance method that touches no instance state;
  it isn't really a method of this class. Private stateless helpers are fine, and
  `module_function` modules are exempt — that's what they're for.
- **control_parameter** — an argument used only to pick an execution path; the
  caller already knew which branch it wanted.
- **data_clump** — the same two-plus parameters travel through three or more
  methods; a value object is missing.
- **duplicate_method_call** — the identical receiver-and-arguments call repeated
  inside one method; name the result once. Quiet wherever naming it would be
  wrong: calls that mint a fresh value every time (`"".b`, `rand`, `dup`,
  `SecureRandom.hex`) are meant to differ, and a repeat no single run can reach
  twice — the two arms of an `if`, two `when` branches, a body and its `rescue`
  — has nothing to hoist.
- **repeated_conditional** — one class testing the same condition in three or
  more places; polymorphism is overdue.
- **too_many_instance_variables** — more than four per class. Memoization
  (`@x ||=`) doesn't count as state.
- **instance_variable_assumption** — an ivar read that nothing the class can
  reach ever assigns: not `initialize`, not another of its own methods, not an
  `attr_writer`, not a reopening of the class, not a module it mixes in or a
  class it inherits. Usually a typo, or state some other object is expected to
  install. Silent when the class inherits or includes something the codebase
  can't see, because the assignment may live in there.
- **manual_dispatch** — `respond_to?` then send: a type check wearing a duck
  costume.
- **module_initialize** — `initialize` in a mixin; construction order becomes
  anyone's guess.
- **nil_check** — `nil?`, `== nil`, `when nil`: simulated polymorphism on the
  cheapest type there is.

Smell findings gate and ratchet like every other kind — `--fail-on smells` covers
all twelve, or name one (`--fail-on feature_envy`); `--skip smells` drops the
analyzer entirely.

## Hotspots

Each analyzer answers a different question. The hotspot rollup joins the cost
signals — complexity and duplication — per file and adds the one signal that isn't in the AST — how often the file actually
changes — because cost you never pay isn't worth paying down:

```console
Hotspots — cost × churn (where refactoring pays the most):

file                                      Cog  Dup  Churn  Rank
---------------------------------------------------------------
controllers/orders/refunds_controller.rb    0   67      4   268
controllers/orders/returns_controller.rb    0   67      4   268
models/invoice.rb                           8   34      3   126
models/shipping/label.rb                    9  100      1   109
controllers/orders_controller.rb            8    0      7    56
```

Read it as a work queue: the top row is where a day of refactoring buys the most.
A file carrying a clone is charged per site, so one holding both copies pays
twice. Churn floors at one, so a repo with no git history still ranks by cost.

Deliberately not a rating. A letter grade on a healthy codebase is the same
letter repeated — it tells you nothing about what to open first.

## How it works

**Coupling.** A dependency edge A→B exists when a file in package A references a
constant declared by package B. Declarations are read from the AST; strings and
comments are invisible. A type counts toward TC only if it defines a method
directly in its body; pure namespace wrappers don't count. The namespace prefix
shared by the packages is inferred (`App`, or `App::Core` when analyzing a nested
subtree), so `App::Alpha` and `Alpha` resolve to the same package. Resolution is
by longest constant path, so a namespace mirrored across packages
(`Admin::Account` in models, `Admin::AccountsController` in controllers) sends
each reference to the right side; a bare name declared in exactly one package
resolves there, and a name several packages claim resolves to nothing rather
than to a guess. Each edge carries a **weight**: the number of constant
references backing it. A root-level file `x.rb` folds into package `x` when a
sibling folder `x/` exists; everything else at the top level lands in `(root)`.

**Complexity.** Every method body is walked once and scored against the
cognitive-complexity rules above.

**Duplication.** Candidates are every window of one to twelve sibling statements,
plus every method, `when` arm and `rescue` clause taken whole. Runs of identically
shaped statements are skipped as lists. Each candidate is hashed structurally and
matched both exactly and by near-miss — a linear-time bound on the longest common
subsequence rejects a pair before the real comparison runs — then unioned into
clusters and reduced to the maximal, non-overlapping ones. All three analyzers
share a single parse of your source, so running them together costs no more than
parsing once.

**Hotspots.** Each file is charged the cognitive complexity of its methods and
the mass of every clone site it holds, then multiplied by how many commits touched
it. Git is asked once, lazily, and only if something needs churn.

## CI

`--fail-on` is the blunt instrument: fail the build when findings of a kind exist
at all. It only works on a codebase that starts clean.

```sh
hashira --fail-on cycles,sdp,mixed_audience,wide_edge,roll_call,smells   # any subset
```

Kinds are named as the reports name them, plus three shorthands: `cycles` for
`cycle`, `sdp` for `sdp_violation`, and `dupe` for `duplication`. `smells`
expands to every smell kind; a single smell can be named on its own
(`--fail-on feature_envy`). An unknown kind lists the valid ones rather than
guessing.

The ratchet is the one you can adopt today. Commit a baseline of what's true now
— which edges exist, which findings stand — and the build fails when that set
*grows*. It never asks whether the code is good, only whether this commit made it
worse, which is the question a build can actually answer:

```sh
hashira --update-baseline        # record today's edges and findings
hashira --ratchet                # fail if either set grew
hashira --ratchet --baseline PATH
```

The baseline records more than which findings exist: where a finding has a
magnitude — cognitive complexity, clone mass, sprawl count — it records that too.
So a method already in the baseline going from 10 to 54 is a regression, not
"unchanged". On a legacy codebase, where most hot methods are baselined on day
one, that is where the work actually happens:

```console
$ hashira --ratchet
WORSE FINDING (was 13, now 24):
  complexity: App::Core::Knot#tangle — cognitive 24, 1 calls (core/knot.rb:4).
  flatten the branching — guard clauses, early returns, or polymorphism.
```

Baselines written by earlier versions still work: they record identity only, so
they ratchet on appearance until the next `--update-baseline` records magnitudes.

It also records a *trace* of each finding — the file it sits in and what it says,
with the line numbers left out. A finding is keyed by what it names
(`Class#method`), so renaming a class, or adding a `?` to four predicates, would
otherwise report every finding under it as resolved and new in the same breath.
When a key disappears and another appears carrying the same trace, the ratchet
reads them as one finding that changed name. The match is one for one: a rename
that *brought* a new finding with it still fails, and a renamed method that also
got more complex still reports WORSE. Moving the file changes the trace, because
that is a relocation rather than a rename — re-record it. Baselines without
traces behave exactly as they did before.

A regression prints in full, with the evidence that introduced it:

```console
$ hashira --ratchet
NEW FINDING:
  duplication: 2 similar fragments (mass 44) — extract the shared shape and pass what differs as parameters.
      · billing/refund.rb:1-11
      · orders/checkout.rb:1-11

Ratchet FAILED. Either fix what regressed, or — if it is deliberate —
record the decision: update the baseline, or accept it with a reason.
```

Improvements fail the build too, and say so cheerfully — an unrecorded gain is one
the next commit can quietly undo. Re-run `--update-baseline` to lock it in.

### Hooks: ratchet the files you just touched

`--only` narrows the findings to the files you name, so an editor hook, a
pre-commit hook, or an agent finishing an edit can ask the one question that
matters there: *did these files get worse?*

```sh
hashira --only lib/billing/refund.rb,lib/orders/checkout.rb --ratchet
hashira --only "$(git diff --cached --name-only -- '*.rb' | paste -sd, -)" --ratchet
```

The whole project is still parsed — that is the point. Half of what hashira knows
is cross-file (which constants are yours, which methods pick apart a neighbour's
internals, which fragments are clones of each other), so a file read alone would
answer differently. `--only` narrows the *report*, never the analysis. On this
repository a full run is under a second for 129 files; smells alone, a quarter of
that.

Two things a focused run cannot judge, and so stays quiet about: package edges,
which belong to no single file, and findings that *disappeared*, which you would
have to read the whole project to be sure of. It reports what your files
introduced or made worse, and nothing else. Run the unfocused `--ratchet` in CI —
that is where removals get celebrated and the baseline gets relocked.

`--only` refuses to combine with `--update-baseline` (which would record a
baseline missing everything you did not name) or with the diagram formats (which
draw the graph, not the findings). Paths outside the analyzed directories are
ignored, so a hook can hand it every changed file without filtering first.

### Exit codes

A build step should be able to tell a regression from a typo without grepping
English, so the codes are distinct:

| code | meaning |
| ---- | ------- |
| `0`  | clean — nothing found, or nothing worse than the baseline |
| `1`  | findings, or the ratchet found a regression |
| `2`  | misuse — bad flags, missing directory, unusable baseline |
| `3`  | an improvement the baseline has not recorded yet |
| `70` | internal error, worth reporting |

`3` is the one worth wiring specially: it means the code got better and only the
baseline is stale. Failing on `1` while treating `3` as a nudge lets a build
block regressions without blocking progress.

### Accepting by design

Anything deliberate goes in the baseline with a reason. It leaves reports and
gates, keeping a one-line reminder of why it's allowed:

```json
"accepted": [
  {"kind": "sdp_violation", "package": "models", "reason": "config is generated, churn is harmless"},
  {"kind": "complexity", "package": "Legacy::Importer#run", "reason": "vendored, rewrite scheduled"},
  {"kind": "duplication", "digest": "8bbddea787bc", "reason": "generated adapters, regenerated together"}
]
```

Cycles, SDP violations and complexity name a `package` — a package name or a
method, both stable. A clone has no stable name: its canonical site is a line
number, and a line number moves whenever anything above it does. So clones are
accepted by `digest` instead, a fingerprint of the shape itself — read it out of
`hashira --json`. It survives the clone moving down the file, and stops matching
when the clone actually changes.

That sentence of reason is the part no tool can compute. A ratchet with no escape
valve gets switched off the first Friday it blocks a release; one that costs a
sentence turns every exception into a decision somebody reviewed.

## Other formats

```sh
hashira --json            # machine format, never capped by --top
hashira --json --compact  # the same on one line, for piping
hashira --format dot      # Graphviz digraph
hashira --format mermaid  # Mermaid diagram
```

`--json` opens with what produced it — `version` (the schema, bumped when the
shape changes), `packaging`, `targets`, `files` — then `findings` (each with its
`digest`), `accepted`, `packages`, `edges`, `folds` (single-type classes joined
to a base or domain, `{from, to, via}`), `complexity`, `duplication`, and
`hotspots`. A package with no edges at all reports `"i": null` rather than
pretending 0/0 is maximally stable.

Both diagrams declare every package before the arrows, so a package nothing
depends on still appears. Mermaid node ids are generated (`p0`, `p1`, …) with
the real name in the label, so `my-pkg` and `my_pkg` stay two nodes and a
package called `end` does not break the graph.

## Why cognitive complexity

The older Ruby complexity metrics charge roughly one point per message send and
multiply by nesting depth, so the score tracks *how many methods you call* more
than how hard the code is to follow. A flat method that calls twenty collaborators
outranks a genuinely knotty one with deep conditionals and mixed boolean logic.
Cognitive complexity was designed the other way around: straight-line code is free
no matter how long, nesting compounds, and flat structures like `case` are cheap
because a jump table is easy to read. hashira shows the call count next to the
score precisely so you can see where the two disagree.

The gap is widest on Rails. Rank a Rails app by message sends and the top hits are
class bodies — `Invoice`, `Order::Pagination`, `Membership` — because a column of
`has_many` and `validates` declarations is a column of message sends. Class bodies
are not methods, so cognitive complexity scores them zero and ranks the code that
actually branches. The per-class rollup then keeps a hotspot visible after it is
split into five tiny methods, without letting a wall of DSL calls dominate the
total.

## Why no A, D, or zones

Classic package-metrics tools also measure abstractness (A),
distance-from-main-sequence (D), and the Pain/Uselessness zones. Those assume
formal interfaces are how you decouple. Idiomatic Ruby decouples via duck
typing, so any abstractness proxy pins to ~0 and the "zone" verdict just
restates I. Deliberately skipped.

## Contributing

Bug reports and pull requests are welcome at
[github.com/giacope/hashira](https://github.com/giacope/hashira). See
[CONTRIBUTING.md](CONTRIBUTING.md) and the [code of conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE.txt)
