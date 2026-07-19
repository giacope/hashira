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

That's exactly what CI runs: rubocop, reek, rspec (with a coverage floor),
rubycritic (with a minimum score), and hashira's own gate and ratchet on
itself. Each check can also be run alone, e.g. `bundle exec rspec`.

## Submitting changes

1. Fork and create a branch.
2. Add or adjust specs for your change.
3. Make sure `rspec` and `rubocop` are green.
4. Open a pull request describing what changed and why.

For anything substantial, open an issue first so we can discuss the approach.

## Code of conduct

By participating you agree to the [code of conduct](CODE_OF_CONDUCT.md).
