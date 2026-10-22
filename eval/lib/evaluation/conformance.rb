# frozen_string_literal: true

class Evaluation::Conformance
  SUITE = "complexity"

  ARGUMENTS = %w[lib/conformance --json --skip coupling,duplication,smells].freeze

  DEFINITION = /def (self\.)?([a-z_]\w*[?!]?)/

  def self.build(tool) = new(tool, YAML.safe_load_file(File.join(Evaluation::CASES, "complexity.yml")))

  def initialize(tool, cases)
    @tool = tool
    @cases = cases
  end

  def checks
    Evaluation::Sandbox.new(files).open do |root|
      scored = scores(@tool.call(root, ARGUMENTS))
      @cases.each_with_index.flat_map { |item, index| verdicts(item, index, scored) }
    end
  end

  private

  def files = @cases.each_index.to_h { ["lib/conformance/case#{it}.rb", source(it)] }

  def source(index)
    "module Conformance\n  class Case#{index}\n#{@cases[index]["source"].lines.map { "    #{it}" }.join}  end\nend\n"
  end

  def scores(outcome) = outcome.json.dig("complexity", "methods").to_h { [it["subject"], it["cognitive"]] }

  def verdicts(item, index, scored)
    expected(item).map do |name, score|
      subject = "Conformance::Case#{index}#{name}"
      Evaluation::Check.of(SUITE, "#{item["name"]} (#{subject})", score, scored[subject])
    end
  end

  def expected(item)
    wanted = item["expected"]
    wanted.is_a?(Hash) ? wanted.transform_keys { label(it) } : { label(defined(item["source"])) => wanted }
  end

  def defined(source)
    found = source.match(DEFINITION)
    found[1] ? ".#{found[2]}" : found[2]
  end

  def label(name) = name.start_with?(".") ? name : "##{name}"
end
