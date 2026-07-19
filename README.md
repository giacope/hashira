# hashira

:classical_building: Package coupling metrics for Ruby, read from the AST via Prism.

## Installation

```ruby
gem "hashira"
```

Requires Ruby 3.4+.

## Getting Started

```sh
hashira                  # auto-detects lib/<gem>
hashira lib/myapp        # or point it at a directory
hashira app lib          # or several — one shared graph
```

You get a report like:

```
package       TC  Ca  Ce     I  Cyc
----------------------------------------
analysis      20   1   0  0.00  -
report         7   2   0  0.00  -
ci             4   1   2  0.67  -
cli            6   0   4  1.00  -
```

## How to Read the Numbers

Every folder under the target directory is a **package**. For each one:

- **TC** — how many classes/modules it defines.
- **Ca** — how many packages depend *on* it (afferent, incoming).
- **Ce** — how many packages it depends *upon* (efferent, outgoing).
- **I** — instability, `Ce / (Ce + Ca)`, from 0 to 1.

**I = 0**: everyone depends on it, it depends on no one — a foundation, expensive to change. **I = 1**: nobody depends on it — free to change. Neither is good or bad on its own; a CLI layer *should* be at 1.00, a core domain layer near 0.00. The findings are about arrows pointing the wrong way:

- **SDP violation** — a stable package depends on a less stable one.
- **Cycle** — packages depending on each other in a loop.

Each finding comes with file-level evidence; for cycles, the shortest cycle path and its lightest edge. What a finding means for your design is your call.

## How It Works

A dependency edge A→B exists when a file in package A references a constant declared by package B. Declarations are read from the AST; strings and comments are invisible. A type counts toward TC only if it defines a method directly in its body — pure namespace wrappers don't count. The root namespace is inferred (the most common outermost constant), so `App::Alpha` and `Alpha` resolve to the same package.

Each edge carries a **weight**: the number of constant references backing it. A root-level file `x.rb` folds into package `x` when a sibling folder `x/` exists; everything else at the top level lands in `(root)`.

## CI

Fail the build when specific finding kinds exist:

```sh
hashira --fail-on cycles,sdp     # kinds: cycles, sdp
```

Or ratchet: commit a baseline and only allow the edge set to shrink. New edges fail with the evidence that introduced them.

```sh
hashira --ratchet                # compares against hashira_baseline.json
hashira --update-baseline        # lock in improvements
hashira --ratchet --baseline PATH
```

Findings accepted by design can be recorded in the baseline with a reason — they leave reports and gates, keeping a one-line reminder each:

```json
"accepted": [
  {"kind": "sdp_violation", "package": "models", "reason": "config is generated, churn is harmless"}
]
```

## Other Formats

```sh
hashira --json            # machine format with full evidence + edge weights
hashira --format dot      # Graphviz digraph
hashira --format mermaid  # Mermaid diagram
```

## Why No A, D, or Zones

Classic package-metrics tools also measure abstractness (A), distance-from-main-sequence (D), and the Pain/Uselessness zones. Those assume formal interfaces are how you decouple. Idiomatic Ruby decouples via duck typing, so any abstractness proxy pins to ~0 and the "zone" verdict just restates I. Deliberately skipped.

## Contributing

Bug reports and pull requests are welcome at
[github.com/giacope/hashira](https://github.com/giacope/hashira). See
[CONTRIBUTING.md](CONTRIBUTING.md) and the [code of conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE.txt)
