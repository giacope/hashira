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

That's exactly what CI runs: rubocop, reek, rspec (with a coverage floor), and
hashira's own gate and ratchet on itself. Each check can also be run alone,
e.g. `bundle exec rspec`.

There is deliberately no quality score to clear. The ratchet asks only whether a
change made things worse, so passing it means fixing what regressed or recording
why it stands — never padding a number.

Two cops in `.rubocop/cop/hashira/` enforce house rules. `Hashira/IoDiscipline`
keeps printers writing through their injected IO. `Hashira/NoComments` allows no
comments in `lib/` at all, beyond the ones a machine reads: magic comments and
linter directives. Not docblocks, not annotations, not a note above a constant.

The reasoning a comment would have carried belongs in the code — in the name of
a method, a constant standing in for a literal, a class small enough that what
it does is evident. A comment is a second copy of the truth that nothing checks,
and it rots the moment the code beneath it moves.

Both cops autocorrect. Specs are excluded, since an example is often clearest
with a line of prose in the middle of it.

## Submitting changes

1. Fork and create a branch.
2. Add or adjust specs for your change.
3. Make sure `rspec` and `rubocop` are green.
4. Open a pull request describing what changed and why.

For anything substantial, open an issue first so we can discuss the approach.

## Code of conduct

By participating you agree to the [code of conduct](CODE_OF_CONDUCT.md).
