# frozen_string_literal: true

require_relative "../../support/readme_examples"

RSpec.describe(Hashira::CLI::Session, :aggregate_failures) do
  def readme = File.read("#{__dir__}/../../../README.md", encoding: Encoding::UTF_8)

  def examples = readme.scan(/<!-- example: (\S+) (.*?) -->\n```console\n(.*?)^```/m)

  def printed(name, arguments)
    within(ReadmeExamples.files(name)) { capture { described_class.new(arguments.split).status } }.lines(chomp: true)
  end

  def shown(block) = block.lines(chomp: true).reject { it.empty? || it == "..." || it.start_with?("$ ") }

  def missing(lines, output)
    cursor = -1
    lines.find do |line|
      offset = output[(cursor + 1)..].index(line)
      offset ? (cursor += offset + 1) && false : true
    end
  end

  it "prints every line each console example shows, in the order shown" do
    gaps = examples.map { |name, arguments, block| [name, arguments, missing(shown(block), printed(name, arguments))] }
    expect(gaps.select(&:last)).to(be_empty)
  end

  it "runs each example as the command it shows" do
    commands = examples.select { |_, _, block| block.start_with?("$ ") }
    expect(commands.reject { |_, arguments, block| block.lines.first.chomp == "$ hashira #{arguments}" }).to(be_empty)
  end

  it "backs every console block with an example" do
    expect(readme.scan("```console").size).to(eq(examples.size))
  end

  it "reports the healthy-project line the README promises" do
    promised = readme[/A healthy project reports `([^`]+)`/, 1]
    expect(printed("healthy", "app").join(" ").gsub(/\s+/, " ")).to(include(promised))
  end
end
