# Contributing to hashira

Thanks for helping out! Bug reports, fixes, docs, and feature ideas are all
welcome.

## Getting set up

```sh
git clone https://github.com/giacope/hashira
cd hashira
bundle install
```

Requires Ruby 3.4+.

## Running the checks

```sh
bin/ci
```

That's exactly what CI runs: rubocop, rspec (with a coverage floor), and
hashira on itself with `--fail-on all`: every kind its `.hashira.yml` checks,
with no baseline, so any finding fails the build. Each check can also be run alone,
e.g. `bundle exec rspec`.

CI also runs the evaluation's fixed-answer suites, which check hashira's
answers against known ones; any failed check fails the build:

```sh
eval/run --hashira . --suites complexity,coupling,duplication,smells,cli --label ci
```

The full evaluation (corpus, precision sample, blind and human labels) is a
pre-release step; [eval/results/README.md](eval/results/README.md) says how to
run it.

Pull requests also get a mutation gate: [kimera](https://github.com/giacope/kimera)
mutates the lines you changed, and any mutant the specs don't run or don't kill
fails the build. To run it before pushing:

```sh
bundle exec kimera ci --since origin/main
```

`bundle exec kimera skill` explains how to triage a survivor.

There is deliberately no quality score to clear and no baseline to grow: hashira
reports nothing on its own code, so a change that adds a finding fixes it (or,
when hashira misreads the code, fixes hashira).

Lint is [rubocop-kata](https://github.com/giacope/rubocop-kata) with its
defaults and nothing else: `.rubocop.yml` names the plugin, the Ruby version
and the paths that are not the project's code, and holds no cop settings, no
todo file and no disable comments. Among kata's rules, `Kata/IoDiscipline`
keeps printers writing through their injected IO, and `Kata/NoComments` allows
no comments in `lib/` beyond the ones a machine reads.

The reasoning a comment would have carried belongs in the code — in the name of
a method, a constant standing in for a literal, a class small enough that what
it does is evident. A comment is a second copy of the truth that nothing checks,
and it rots the moment the code beneath it moves.

When kata misreads hashira's code, fix kata rather than configuring around it.

## Submitting changes

1. Fork and create a branch.
2. Add or adjust specs for your change.
3. Make sure `rspec` and `rubocop` are green.
4. Open a pull request describing what changed and why.

For anything substantial, open an issue first so we can discuss the approach.

## Code of conduct

By participating you agree to the [code of conduct](CODE_OF_CONDUCT.md).
