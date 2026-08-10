# frozen_string_literal: true

require_relative "flags"

module Hashira::CLI::Usage
  PAGES = %i[help version].freeze

  HEADER = <<~TEXT
    Usage: hashira [DIRECTORY ...] [options]

    Coupling, cognitive-complexity, duplication, and code-smell metrics
    for Ruby, via Prism, rolled up per file as a ranked list of hotspots.
    With no directory, auto-detects lib/<gem>.

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
  TEXT

  module_function

  def help = emit(HEADER + options + FOOTER)

  def version = emit("hashira #{Hashira::VERSION}")

  def options = Hashira::CLI::FLAGS.map { rows(it) }.join

  def rows(flag)
    first, *rest = flag.text
    ["  #{flag.label.ljust(21)}#{first}\n", *rest.map { "#{" " * 23}#{it}\n" }].join
  end

  def emit(output)
    puts(output)
    0
  end
end
