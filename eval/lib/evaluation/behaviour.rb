# frozen_string_literal: true

class Evaluation::Behaviour
  SUITE = "cli"

  SAID = { true => :said, false => :unsaid }.freeze

  def self.build(tool, cases = Evaluation::Home.new.cases("cli.yml")) = new(tool, YAML.safe_load_file(cases))

  def initialize(tool, cases)
    @tool = tool
    @cases = cases
  end

  def checks = @cases.flat_map { verdicts(it) }

  private

  def verdicts(item)
    Evaluation::Sandbox.new(item.fetch("files")).open do |root|
      outcome = @tool.call(File.join(root, item.fetch("cwd", ".")), item["args"])
      [
        status(item, outcome), *said(item, outcome, "includes", :said), *said(item, outcome, "excludes", :unsaid),
        *probes(item, outcome), *written(item, root)
      ]
    end
  end

  def check(item, label, expected, actual) = Evaluation::Check.of(SUITE, "#{item["name"]}: #{label}", expected, actual)

  def status(item, outcome)
    _, status = outcome.to_a
    check(item, "exit status", item["status"], status)
  end

  def said(item, outcome, key, wanted)
    text, = outcome.to_a
    item.fetch(key, []).map { check(item, it.inspect, wanted, SAID.fetch(text.include?(it))) }
  end

  def probes(item, outcome)
    item.fetch("json", {}).map { |path, wanted| check(item, "json #{path}", wanted, outcome.probe(path).first) }
  end

  def written(item, root)
    item.fetch("writes", {}).map do |path, wanted|
      check(item, "writes #{path}", wanted, File.exist?(File.join(root, path)))
    end
  end
end
