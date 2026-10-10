# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "yaml"

module Evaluation
  ROOT = File.expand_path("..", __dir__)

  CASES = File.join(ROOT, "cases")
end

require_relative "evaluation/outcome"
require_relative "evaluation/tool"
require_relative "evaluation/sandbox"
require_relative "evaluation/check"
require_relative "evaluation/arcs"
require_relative "evaluation/conformance"
require_relative "evaluation/verdict"
require_relative "evaluation/graphs"
require_relative "evaluation/clones"
require_relative "evaluation/sniff"
require_relative "evaluation/smells"
require_relative "evaluation/behaviour"
require_relative "evaluation/sighting"
require_relative "evaluation/sample"
require_relative "evaluation/labels"
require_relative "evaluation/tally"
require_relative "evaluation/precision"
require_relative "evaluation/run"
require_relative "evaluation/corpus"
require_relative "evaluation/board"
require_relative "evaluation/comparison"
require_relative "evaluation/command"
