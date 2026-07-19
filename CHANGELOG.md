# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/giacope/hashira/releases/tag/v0.1.0
