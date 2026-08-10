# frozen_string_literal: true

require_relative "fail_on"
require_relative "flag"
require_relative "format"
require_relative "package_by"
require_relative "skip"
require_relative "top"

class Hashira::CLI
  FLAGS = [
    Flag.new(
      name: "--format", arg: "FORMAT", parse: Format, mode: :parsed,
      text: ["text (default), json, dot, or mermaid"]
    ),
    Flag.new(name: "--json", mode: :json, text: ["shorthand for --format json"]),
    Flag.new(
      name: "--fail-on", arg: "KINDS", field: :fail_on, parse: FailOn, mode: :fail_on,
      text: [
        "exit 1 if findings exist; comma-separated",
        "kinds: cycles, sdp, mixed_audience, wide_edge,",
        "roll_call, complexity, duplication, smells (all",
        "of them), or one smell kind such as feature_envy"
      ]
    ),
    Flag.new(
      name: "--skip", arg: "ANALYZERS", field: :skip, parse: Skip,
      text: ["drop an analyzer; comma-separated: coupling,", "complexity, duplication, smells"]
    ),
    Flag.new(
      name: "--top", arg: "N", field: :top, parse: Top,
      text: [
        "show at most N rows in each table and N",
        "findings (default: 25 packages and findings,",
        "10 methods and files)"
      ]
    ),
    Flag.new(
      name: "--package-by", arg: "WHAT", field: :packaging, parse: PackageBy,
      text: [
        "group coupling by: auto, folder, or namespace",
        "(top-level constant). Default auto: namespace for",
        "Rails apps (config/application.rb in or beside the",
        "analyzed directory), folder otherwise"
      ]
    ),
    Flag.new(
      name: "--ratchet", mode: :ratchet,
      text: ["fail when edges or findings appear that the", "baseline lacks"]
    ),
    Flag.new(name: "--update-baseline", mode: :update, text: ["record the current edges and findings"]),
    Flag.new(
      name: "--baseline", arg: "PATH", field: :baseline, default: "hashira_baseline.json",
      text: ["baseline file (default: hashira_baseline.json)"]
    ),
    Flag.new(name: "-h, --help", mode: :help, text: ["print this help"]),
    Flag.new(name: "--version", mode: :version, text: ["print the version"])
  ].freeze
end
