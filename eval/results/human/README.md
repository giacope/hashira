# Human labels

The precision numbers in [the results README](../README.md) rest on two AI
raters. This folder holds samples for a person to label, so that the raters
can be checked against one.

## human1

37 findings of the kinds hashira reports by default, drawn from the pinned
corpus (`eval/corpus.yml`) as hashira at `50f4b54` reports it, with the salt
`human1`. The draw leaves out every key in `labels/`, `blind/`, `blind2/` and
`holdout/`, so no rater has seen these findings: the sample is also an
untouched holdout.

| kind | items |
| --- | --- |
| duplication | 20 |
| complexity | 10 |
| cycle | 2 |
| wide_edge | 2 |
| fragmentation | 1 |
| mixed_audience | 1 |
| sdp_violation | 1 |

fragmentation, mixed_audience and sdp_violation have one finding each on the
corpus. roll_call is left out: its three rubygems.org findings share one key
(`rubygems.org|roll_call|(root)`), so a label could not tell them apart.

It was drawn with:

```sh
eval/run --hashira . --suites corpus --seed human1 \
  --samples duplication=20,complexity=10,cycle=2,wide_edge=2,sdp_violation=1,mixed_audience=1,fragmentation=1
mkdir -p eval/results/human/human1
ruby -ryaml -e 'Dir["eval/tmp/holdout/human1/*.yml"].each { |path| File.write(path.sub("tmp/holdout", "results/human"), YAML.dump(YAML.safe_load_file(path).map { { "key" => it["key"], "label" => "", "why" => "" }.merge(it) })) }'
```

## Rubric

A finding is **tp** when its claim is true, its remedy applies to code the
project owns, and a strict reviewer on a team aiming for clean code would ask
for the change. It is **fp** otherwise: library contracts (a parser node's
optional child, a source map's missing field), boundary input (a public
argument, a payload), optional style (a plain one-hop reader read twice),
coincidental shape, or a remedy with no owned destination.

For complexity and fragmentation, the change is simplifying or regrouping the
method; for cycle, wide_edge, sdp_violation and mixed_audience, it is the cut,
narrowing or split the message proposes.

## Filling it in

Each `<kind>.yml` is a list of findings. For each one, set `label` to `tp` or
`fp` and `why` to a one-line reason. Leave both empty to skip an item; a label
without a reason is refused.

`message` and `evidence` are what hashira reported, and `code` is an excerpt of
the source at each site, the view the AI raters had of earlier samples. cycle,
wide_edge, sdp_violation and mixed_audience have no excerpt: read their
evidence lines in the checkout that `eval/run --suites corpus` clones under
`eval/tmp/corpus/<project>` (rubocop's paths are under `lib/`).

Label before looking at hashira's code or any rater's labels. Expect about an
hour: a minute or two for each duplication or complexity item, longer for the
package-level ones.

## Scoring

```sh
eval/run --agree eval/results/human/human1
```

prints each kind's human precision with its 95% Wilson interval, then, on the
keys both labelled, the agreement with each AI rater and Cohen's κ. Rater 1 is
`blind/` and rater 2 `blind2/`; `--raters DIR,DIR` names other label folders.
No AI rater has labelled human1 yet, so for now it reports human precision
alone. To compare, have the raters label the same items blind into folders of
their own, in the same shape, and pass those with `--raters`.

`eval/run --agree eval/results/blind2 --raters eval/results/blind` scores the
two raters against each other and gives the 298 of 324 (κ 0.65) the results
README quotes.
