## Suites

| suite | before |
| --- | --- |
| complexity | 55/66 (83.3%) |
| coupling | 17/25 (68.0%) |
| duplication | 6/10 (60.0%) |
| smells | 10/18 (55.6%) |
| cli | 7/29 (24.1%) |
| corpus | 5/6 (83.3%) |

## Failing checks (before)

| suite | check | expected | actual |
| --- | --- | --- | --- |
| complexity | whitepaper lambda nesting (Conformance::Case3#my_method2) | `2` | `1` |
| complexity | parenthesized like operators (Conformance::Case45#run) | `1` | `2` |
| complexity | parenthesized or (Conformance::Case46#run) | `1` | `2` |
| complexity | lambda literal (Conformance::Case53#run) | `2` | `1` |
| complexity | lambda in an if (Conformance::Case57#run) | `4` | `3` |
| complexity | direct recursion (Conformance::Case59#fact) | `2` | `1` |
| complexity | recursion through self (Conformance::Case60#walk) | `1` | `0` |
| complexity | singleton recursion (Conformance::Case61.count) | `2` | `1` |
| complexity | indirect recursion (Conformance::Case62#even?) | `2` | `1` |
| complexity | indirect recursion (Conformance::Case62#odd?) | `2` | `1` |
| complexity | define_method (Conformance::Case64#run) | `1` | `nil` |
| coupling | associations: edges | `["Author -> Post", "Author -> Profile", "Category -> Post", "Lab -> Analysis", "Lab -> Cactus", "Post -> Author", "Post -> Category", "Post -> Remark", "Post -> Status", "Team -> Person"]` | `["Post -> Remark"]` |
| coupling | associations: cycles | `[["Author", "Category", "Post"]]` | `[]` |
| coupling | compact_scope: edges | `["billing -> shipping"]` | `["billing -> shipping", "shipping -> billing"]` |
| coupling | compact_scope: edge shipping -> billing | `:absent` | `:present` |
| coupling | compact_scope: cycles | `[]` | `[["billing", "shipping"]]` |
| coupling | ring: cut of alpha,beta,delta,epsilon,gamma leaves the knot | `:acyclic` | `:cyclic` |
| coupling | ring: cut of alpha,beta,delta,epsilon,gamma is a minimum feedback arc set | `3` | `2` |
| coupling | shared_edge: cut of orders,pricing,promo,tax is a minimum feedback arc set | `3` | `4` |
| duplication | crowded_bucket: report.rb:3 + payout.rb:3 | `:together` | `:apart` |
| duplication | log_lines: findings | `0` | `1` |
| duplication | near_miss_messages: roster.rb:3 + ledger.rb:3 | `:apart` | `:together` |
| duplication | near_miss_messages: roster.rb:3 + stock.rb:3 | `:apart` | `:together` |
| smells | evidence: every nil_check finding names its evidence | `[]` | `["App::Renderer#render"]` |
| smells | evidence: every manual_dispatch finding names its evidence | `[]` | `["App::Renderer#render"]` |
| smells | indirection: indirection App::Importer#run | `:present` | `:absent` |
| smells | sprawl: state_sprawl App::Session says "weighing 6" | `:said` | `"App::Session holds 5 instance variables (app/session.rb:2). Split the class, or gather related fields into value objects."` |
| smells | sprawl: state_sprawl App::Session says "more than 4" | `:said` | `"App::Session holds 5 instance variables (app/session.rb:2). Split the class, or gather related fields into value objects."` |
| smells | timers: repeated_call App::Stopwatch#measure | `:absent` | `:present` |
| smells | timers: repeated_call App::Stopwatch#lap | `:absent` | `:present` |
| smells | timers: repeated_call App::Stopwatch#wait | `:absent` | `:present` |
| cli | another project's baseline is not applied: exit status | `0` | `2` |
| cli | another project's baseline is not applied: "boundary Prism" | `:unsaid` | `:said` |
| cli | the analyzed project's own baseline is applied from elsewhere: json accepted.size | `1` | `0` |
| cli | the analyzed project's config is read from elsewhere: json kinds.utility_function | `nil` | `{"count" => 1, "files" => 1}` |
| cli | a suppression with a reason silences the finding on the next line: exit status | `0` | `1` |
| cli | suppressions are listed in the report: "Suppressed (1)" | `:said` | `:unsaid` |
| cli | suppressions are listed in the report: "a generated state table" | `:said` | `:unsaid` |
| cli | suppressions are listed in --json: json suppressed.size | `1` | `nil` |
| cli | suppressions are listed in --json: json suppressed.0.kind | `"complexity"` | `nil` |
| cli | suppressions are listed in --json: json suppressed.0.reason | `"a generated state table"` | `nil` |
| cli | suppressions are listed in --json: json kinds.complexity | `nil` | `{"count" => 1, "files" => 1}` |
| cli | a suppression without a reason is refused: exit status | `2` | `0` |
| cli | a suppression without a reason is refused: "reason" | `:said` | `:unsaid` |
| cli | a suppression of an unknown kind is refused: exit status | `2` | `0` |
| cli | a suppression of an unknown kind is refused: "envy" | `:said` | `:unsaid` |
| cli | a config threshold moves the complexity bar: exit status | `0` | `2` |
| cli | a config threshold moves the complexity bar: json kinds.complexity.count | `1` | `:unparsed` |
| cli | a config switch turns a kind off: exit status | `0` | `2` |
| cli | a config switch turns a kind off: json kinds.utility_function | `nil` | `:unparsed` |
| cli | a baseline from before a kind was renamed still ratchets clean: exit status | `0` | `1` |
| cli | --update-baseline from elsewhere writes the project's baseline: writes project/hashira_baseline.json | `true` | `false` |
| cli | --update-baseline from elsewhere writes the project's baseline: writes elsewhere/hashira_baseline.json | `false` | `true` |
| corpus | faraday: cut of 7-package knot is minimum | `13` | `5` |

## Corpus

### rubocop

|  | before |
| --- | --- |
| files | 880 |
| kloc | 82.9 |
| seconds | 39.93 |
| megabytes | 461.4 |
| assumed_state | 1 (0.01/kLOC) |
| complexity | 38 (0.46/kLOC) |
| control_parameter | 88 (1.06/kLOC) |
| cycle | 1 (0.01/kLOC) |
| data_clump | 52 (0.63/kLOC) |
| duplication | 251 (3.03/kLOC) |
| feature_envy | 202 (2.44/kLOC) |
| manual_dispatch | 123 (1.48/kLOC) |
| module_initialize | 1 (0.01/kLOC) |
| nil_check | 156 (1.88/kLOC) |
| repeated_call | 791 (9.54/kLOC) |
| repeated_conditional | 21 (0.25/kLOC) |
| state_sprawl | 25 (0.3/kLOC) |
| utility_function | 41 (0.49/kLOC) |

### faraday

|  | before |
| --- | --- |
| files | 32 |
| kloc | 3.17 |
| seconds | 1.98 |
| megabytes | 51.7 |
| complexity | 4 (1.26/kLOC) |
| control_parameter | 1 (0.32/kLOC) |
| cycle | 1 (0.32/kLOC) |
| data_clump | 2 (0.63/kLOC) |
| duplication | 14 (4.42/kLOC) |
| feature_envy | 4 (1.26/kLOC) |
| manual_dispatch | 11 (3.47/kLOC) |
| mixed_audience | 1 (0.32/kLOC) |
| nil_check | 29 (9.15/kLOC) |
| repeated_call | 25 (7.89/kLOC) |
| repeated_conditional | 3 (0.95/kLOC) |
| state_sprawl | 1 (0.32/kLOC) |
| utility_function | 5 (1.58/kLOC) |
| wide_edge | 1 (0.32/kLOC) |

### rubygems.org

|  | before |
| --- | --- |
| files | 558 |
| kloc | 20.73 |
| seconds | 14.81 |
| megabytes | 202.4 |
| complexity | 18 (0.87/kLOC) |
| control_parameter | 16 (0.77/kLOC) |
| cycle | 2 (0.1/kLOC) |
| duplication | 136 (6.56/kLOC) |
| feature_envy | 20 (0.96/kLOC) |
| manual_dispatch | 13 (0.63/kLOC) |
| nil_check | 90 (4.34/kLOC) |
| repeated_call | 165 (7.96/kLOC) |
| repeated_conditional | 9 (0.43/kLOC) |
| roll_call | 3 (0.14/kLOC) |
| sdp_violation | 1 (0.05/kLOC) |
| state_sprawl | 20 (0.96/kLOC) |
| utility_function | 24 (1.16/kLOC) |
| wide_edge | 2 (0.1/kLOC) |

## Precision (labeled sample)

| kind | before |
| --- | --- |
| repeated_call | 9/25 = 0.36 [0.202, 0.555] of 981 |
| feature_envy | 3/25 = 0.12 [0.042, 0.3] of 226 |
| nil_check | 4/25 = 0.16 [0.064, 0.347] of 275 |
| manual_dispatch | 5/25 = 0.2 [0.089, 0.391] of 147 |
| duplication | 16/25 = 0.64 [0.445, 0.798] of 401 |
| control_parameter | 5/15 = 0.333 [0.152, 0.583] of 105 |
| utility_function | 15/15 = 1.0 [0.796, 1.0] of 70 |
| data_clump | 12/15 = 0.8 [0.548, 0.93] of 54 |
| state_sprawl | 8/15 = 0.533 [0.301, 0.752] of 46 |
| repeated_conditional | 12/15 = 0.8 [0.548, 0.93] of 33 |
| indirection | — |
