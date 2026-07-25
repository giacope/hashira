# frozen_string_literal: true

module Hashira
  class CLI
    module Usage
      TEXT = <<~HELP
        Usage: hashira [DIRECTORY ...] [options]

        Coupling, cognitive-complexity, and duplication metrics for Ruby, via
        Prism, rolled up per file as a ranked list of hotspots. With no
        directory, auto-detects lib/<gem>.

        Options:
          --format FORMAT      text (default), json, dot, or mermaid
          --json               shorthand for --format json
          --fail-on KINDS      exit 1 if findings exist; comma-separated
                               kinds: cycles, sdp, complexity, duplication
          --skip ANALYZERS     drop an analyzer; comma-separated: coupling, complexity, duplication
          --ratchet            fail when edges or findings appear that the
                               baseline lacks
          --update-baseline    record the current edges and findings
          --baseline PATH      baseline file (default: hashira_baseline.json)
          -h, --help           print this help
          --version            print the version

        Findings accepted by design can be recorded in the baseline as
          "accepted": [{"kind": "...", "package": "...", "reason": "..."}]
        — they leave reports and gates, keeping a one-line reminder each.
        Clones are named by "digest" instead of "package", so an acceptance
        survives the lines above it moving. Read digests from --json.
      HELP

      module_function

      def help = emit(TEXT)

      def version = emit("hashira #{VERSION}")

      def emit(output)
        puts output
        0
      end
    end
  end
end
