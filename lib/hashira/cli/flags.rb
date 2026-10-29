# frozen_string_literal: true

require_relative "../checks"
require_relative "choice"
require_relative "fail_on"
require_relative "flag"
require_relative "kinds"
require_relative "only"
require_relative "skip"
require_relative "top"

module Hashira::CLI
  FLAGS = [
    Flag.new(
      ["text (default), json, dot, or mermaid"],
      Flag::Value.new("--format", "FORMAT", Choice.new("--format", %i[text json dot mermaid])), %i[parsed]
    ),
    Flag.new(["shorthand for --format json"], Flag::Switch.new("--json"), %i[json]),
    Flag.new(["emit JSON on one line, without the indentation", "meant for reading"], Flag::Switch.new("--compact")),
    Flag.new(
      [
        "exit 1 if findings exist; comma-separated",
        "kinds: cycles, sdp, mixed_audience, wide_edge,",
        "roll_call, complexity, duplication, smells (all",
        "of them), or one smell kind such as feature_envy;",
        "all gates every kind the run checks"
      ],
      Flag::Value.new("--fail-on", "KINDS", Kinds.new("--fail-on", FailOn.new.names)), %i[fail_on]
    ),
    Flag.new(
      ["drop an analyzer; comma-separated: coupling,", "complexity, duplication, smells"],
      Flag::Value.new("--skip", "ANALYZERS", Skip.new("--skip"))
    ),
    Flag.new(
      [
        "keep only the findings that name these files",
        "(a directory stands for every file under it);",
        "comma-separated. The whole project is still read,",
        "so cross-file signals stay right. Meant for hooks:",
        "hashira --only $CHANGED --ratchet"
      ],
      Flag::Value.new("--only", "PATHS", Only.new("--only"))
    ),
    Flag.new(
      [
        "keep only the findings of these kinds, named",
        "as for --fail-on; comma-separated. The tables",
        "and the graph stay whole"
      ],
      Flag::Value.new("--kind", "KINDS", Kinds.new("--kind", Hashira::Checks.new.names))
    ),
    Flag.new(
      [
        "show at most N rows in each table and N",
        "findings (default: 25 packages and findings,",
        "10 methods and files). JSON is uncapped",
        "unless --top is given"
      ],
      Flag::Value.new("--top", "N", Top.new("--top"))
    ),
    Flag.new(
      [
        "turn on the strict set: stateful_mixin and the",
        "stricter readings of nil_check, concrete_inheritance,",
        "data_class and low_cohesion (as strict: true in",
        ".hashira.yml); off, even under checks: all"
      ],
      Flag::Switch.new("--strict")
    ),
    Flag.new(
      [
        "group coupling by: auto, folder, or namespace",
        "(top-level constant). Default auto: namespace for",
        "Rails apps (config/application.rb in or beside the",
        "analyzed directory), folder otherwise"
      ],
      Flag::Value.new("--package-by", "WHAT", Choice.new("--package-by", %i[auto folder namespace], :auto))
    ),
    Flag.new(
      ["fail when edges or findings appear that the", "baseline lacks"], Flag::Switch.new("--ratchet"), %i[ratchet]
    ),
    Flag.new(["record the current edges and findings"], Flag::Switch.new("--update-baseline"), %i[update]),
    Flag.new(
      [
        "baseline file (default: hashira_baseline.json in",
        "the analyzed project's root: the nearest folder",
        "above the first directory holding .hashira.yml",
        "or a baseline, else where hashira runs)"
      ],
      Flag::Value.new("--baseline", "PATH")
    ),
    Flag.new(
      [
        "read default options from PATH (default:",
        ".hashira.yml in the project's root, when there",
        "is one); a flag on the command line wins"
      ],
      Flag::Value.new("--config", "PATH")
    ),
    Flag.new(["ignore .hashira.yml"], Flag::Switch.new("--no-config"))
  ].freeze

  PAGES = [
    Page.new("-h, --help", :help, ["print this help"]),
    Page.new("--version", :version, ["print the version"])
  ].freeze

  private_constant :FLAGS, :PAGES

  class Flags
    include Enumerable

    def initialize(table = FLAGS, pages = PAGES)
      @table = table
      @pages = pages
    end

    def each(&) = [*@table, *@pages].each(&)

    def page(arguments) = @pages.lazy.select { it.seen?(arguments) }.first(1)

    def parse(arguments) = Hashira::CLI::Parsed.new(@table.to_h { [it, it.read(arguments)] })
  end
end
