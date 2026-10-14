# frozen_string_literal: true

class Evaluation::Behaviour
  SUITE = "cli"

  SAID = { true => :said, false => :unsaid }.freeze

  def self.build(tool) = new(tool, YAML.safe_load_file(File.join(Evaluation::CASES, "cli.yml")))

  def initialize(tool, cases)
    @tool = tool
    @cases = cases
  end

  def checks = @cases.flat_map { verdicts(it) }

  private

  def verdicts(item)
    Evaluation::Sandbox.open(item.fetch("files")) do |root|
      outcome = @tool.call(File.join(root, item.fetch("cwd", ".")), item["args"])
      [
        status(item, outcome), *said(item, outcome, "includes", :said), *said(item, outcome, "excludes", :unsaid),
        *probes(item, outcome), *written(item, root)
      ]
    end
  end

  def check(item, label, expected, actual) = Evaluation::Check.of(SUITE, "#{item["name"]}: #{label}", expected, actual)

  def status(item, outcome) = check(item, "exit status", item["status"], outcome.status)

  def said(item, outcome, key, wanted)
    item.fetch(key, []).map { check(item, it.inspect, wanted, SAID.fetch(outcome.text.include?(it))) }
  end

  def probes(item, outcome)
    item.fetch("json", {}).map { |path, wanted| check(item, "json #{path}", wanted, dig(outcome, path)) }
  end

  def written(item, root)
    item.fetch("writes", {}).map do
      |path, wanted|
  check(item, "writes #{path}", wanted, File.exist?(File.join(root, path)))
end
  end

  def dig(outcome, path)
    return :unparsed unless outcome.json
    path.split(".").reduce(outcome.json) { |value, key| step(value, key) }
  end

  def step(value, key)
    return value.size if key == "size" && value.respond_to?(:size)
    value.is_a?(Array) ? value[Integer(key)] : value&.fetch(key, nil)
  end
end
