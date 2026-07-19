# frozen_string_literal: true

module Hashira
  class CLI
    module Usage
      TEXT = <<~HELP
        Usage: hashira [DIRECTORY ...] [options]

        Package coupling metrics for Ruby, via Prism. With no directory,
        auto-detects lib/<gem>.

        Options:
          --format FORMAT      text (default), json, dot, or mermaid
          --json               shorthand for --format json
          --fail-on KINDS      exit 1 if findings exist; comma-separated
                               kinds: cycles, sdp
          --ratchet            fail when edges appear that the baseline lacks
          --update-baseline    write the current edge set as the baseline
          --baseline PATH      baseline file (default: hashira_baseline.json)
          -h, --help           print this help
          --version            print the version

        Findings accepted by design can be recorded in the baseline as
          "accepted": [{"kind": "...", "package": "...", "reason": "..."}]
        — they leave reports and gates, keeping a one-line reminder each.
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
