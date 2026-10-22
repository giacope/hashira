# frozen_string_literal: true

require_relative "flags"

class Hashira::CLI::Usage
  PAGES = %i[help version].freeze

  HEADER = <<~TEXT
    Usage: hashira [DIRECTORY ...] [options]

    Coupling, cognitive-complexity, duplication, and code-smell metrics
    for Ruby, via Prism, rolled up per file as a ranked list of hotspots.
    With no directory, auto-detects every lib/<gem> (with its entry file),
    or app and lib in a Rails root.

    Options:
  TEXT

  FOOTER = <<~TEXT

    Exit codes: 0 clean · 1 findings or a regression · 2 misuse
    (bad flags, missing directory, unusable baseline) · 3 an
    improvement the baseline has not recorded · 70 internal error.

    Findings accepted by design can be recorded in the baseline as
      "accepted": [{"kind": "...", "package": "...", "reason": "..."}]
    — they leave reports and gates, keeping a one-line reminder each.
    Clones are named by "digest" instead of "package", so an acceptance
    survives the lines above it moving. Read digests from --json.

    A .hashira.yml in the project's root sets default options, each key a
    flag without its dashes (fail-on, skip, kind, top, package-by,
    baseline) plus directories, and checks: turns a kind on or off or
    sets its threshold (checks: all turns on the opt-in kinds too). A
    flag typed on the command line wins, and a setting the command
    line rules out (fail-on under --json) sits that run out.

    A "# hashira:disable KIND -- REASON" comment silences a finding on
    its line (disable-next-line: the line below); the reason is required,
    and every suppression is listed in the report.
  TEXT

  def initialize(io = $stdout)
    @io = io
  end

  def help = emit(HEADER + options + FOOTER)

  def version = emit("hashira #{Hashira::VERSION}")

  private

  def options = Hashira::CLI::FLAGS.map { rows(it) }.join

  def rows(flag)
    first, *rest = flag.text
    ["  #{flag.label.ljust(21)}#{first}\n", *rest.map { "#{" " * 23}#{it}\n" }].join
  end

  def emit(output)
    @io.puts(output)
    0
  end
end
