# hashira

🏛️ **Coupling, cognitive-complexity and duplication metrics for Ruby, read straight from the AST via [Prism](https://github.com/ruby/prism).**

hashira tells you which file to open first. It reads a Ruby codebase three ways —
which packages depend on which, how hard each method is to follow, and what has been
copy-pasted — then ranks every file by what it costs you against how often you
actually change it. Every finding names the file and line behind it, and a committed
baseline ratchets the whole set in CI, so the build fails on what *this commit* made
worse rather than on a score nobody agrees on.

- **Zero runtime dependencies.** Prism ships with Ruby 3.4+; nothing else to install.
- **Reads the AST, never strings.** Every signal comes from the parse tree. Comments and string literals are invisible.
- **Three analyzers, opt-out.** Coupling, complexity, and duplication run together by default; `--skip` drops any.
- **Ranked, not graded.** The hotspot rollup orders files by cost × churn — a work queue, not a letter that reads the same on every healthy repo.
- **Findings, not just a dashboard.** Cycles, SDP violations, complexity hotspots, and clone clusters — each backed by file-level evidence and a plain-language fix.
- **Made for CI.** Ratchet edges *and* findings against a baseline, so no clean slate is required. Or gate outright with `--fail-on`.

Let `billing` and `shipping` start referencing each other, and hashira points to
the cycle and to the cheapest edge to cut:

```console
$ hashira app
package       TC  Ca  Ce     I  Cyc
----------------------------------------
billing        1   1   1  0.50  YES
shipping       1   1   1  0.50  YES

Findings (2):
  cycle: billing can reach itself: billing -> shipping -> billing — any change
  may ripple back around. The lightest edge on this cycle is billing -> shipping (1 ref).
      · billing/client.rb:3: Shipping::Rate
      · shipping/rate.rb:3: Billing::Client
```

A healthy project reports `Findings (0): none ✓ — structure is healthy`.

---

## Contents

[Install](#install) · [Getting started](#getting-started) · [Coupling: how to read the numbers](#coupling-how-to-read-the-numbers) · [Cognitive complexity](#cognitive-complexity) · [Duplication](#duplication) · [Hotspots](#hotspots) · [How it works](#how-it-works) · [CI](#ci) · [Other formats](#other-formats) · [Why cognitive complexity](#why-cognitive-complexity) · [Why no A, D, or zones](#why-no-a-d-or-zones)

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

Point hashira at your code, or run it with no arguments to auto-detect `lib/<gem>`:

```sh
hashira                        # auto-detects lib/<gem>
hashira lib/myapp              # or point it at a directory
hashira app lib                # or several — one shared graph
hashira --skip complexity,duplication   # coupling only
hashira --skip coupling                 # complexity + duplication
```

The full text report is the coupling tables, the complexity tables, the hotspot
rollup, and the findings (which include any duplication clusters). Here it is on
hashira's own source:

```console
$ hashira
Package (layer) metrics for lib/hashira  (9 packages, 75 files)

package       TC  Ca  Ce     I  Cyc
----------------------------------------
analysis      14   3   0  0.00  -
diagram        3   1   0  0.00  -
hotspots       1   1   0  0.00  -
duplication   14   2   1  0.33  -
report         8   2   1  0.33  -
complexity     7   1   1  0.50  -
(root)         3   2   4  0.67  -
ci             8   1   2  0.67  -
cli            6   0   4  1.00  -

Legend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),
        I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)

Dependencies (DependsUpon(refs) -> | <- UsedBy):
  (root)       -> analysis(4), complexity(1), duplication(1), hotspots(1) <- ci, cli
  duplication  -> analysis(3)                      <- (root), report
  ...

Cognitive complexity — worst methods (Cog = how hard to read, Calls = message sends):

method                                        Cog  Calls  Loc
-------------------------------------------------------------
Hashira::Report::Text#print                     3      7  report/text.rb:11
Hashira::Analysis::CycleSearch#cycle?           3      3  analysis/cycle_search.rb:19
Hashira::CLI::CommandLine#usage_options         3      5  cli/command_line.rb:20
Hashira::Duplication::Delta#kind                3      6  duplication/delta.rb:21
...

Per-class rollup (Cog total survives extract-method; Peak is the worst method it hides):

class                              Cog  Methods   Peak
------------------------------------------------------
Hashira::CLI::CommandLine           16       15      3
Hashira::Analysis::CycleSearch       8        5      3
...

Hotspots — cost × churn (where refactoring pays the most):

file                                             Cog   Dup  Churn    Rank
-------------------------------------------------------------------------
cli/run.rb                                         1    36      2      74
cli/command_line.rb                               16     0      3      48
pipeline.rb                                        7     0      3      21
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

Each finding comes with file-level evidence; for cycles, the shortest cycle
path and its lightest edge. What a finding means for your design is your call.

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

## Hotspots

The three analyzers each answer a different question. The rollup joins them per
file and adds the one signal that isn't in the AST — how often the file actually
changes — because cost you never pay isn't worth paying down:

```console
Hotspots — cost × churn (where refactoring pays the most):

file                                             Cog   Dup  Churn    Rank
-------------------------------------------------------------------------
controllers/orders/refunds_controller.rb           0    67      4     268
controllers/orders/returns_controller.rb           0    67      4     268
models/invoice.rb                                  8    34      3     126
models/shipping/label.rb                           9   100      1     109
controllers/orders_controller.rb                   8     0      7      56
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
directly in its body; pure namespace wrappers don't count. The root namespace is
inferred (the most common outermost constant), so `App::Alpha` and `Alpha` resolve
to the same package. Each edge carries a **weight**: the number of constant
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
hashira --fail-on cycles,sdp,complexity,duplication   # any subset, comma-separated
```

The ratchet is the one you can adopt today. Commit a baseline of what's true now
— which edges exist, which findings stand — and the build fails when that set
*grows*. It never asks whether the code is good, only whether this commit made it
worse, which is the question a build can actually answer:

```sh
hashira --update-baseline        # record today's edges and findings
hashira --ratchet                # fail if either set grew
hashira --ratchet --baseline PATH
```

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
hashira --json            # machine format: findings (with digests), accepted, packages,
                          # edges, complexity, duplication, hotspots
hashira --format dot      # Graphviz digraph
hashira --format mermaid  # Mermaid diagram
```

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
