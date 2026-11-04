# frozen_string_literal: true

RSpec.describe(Hashira::CI::Marks, :aggregate_failures) do
  it "keeps the trace a signature was first scored with, and its largest magnitude" do
    marks = described_class.new.call("smell:a", 1, ["first"]).call("smell:a", 3, ["second"])
    expect(marks.to_h).to(eq(findings: { "smell:a" => 3 }, traces: { "smell:a" => "first" }))
  end

  it "takes a recorded finding as seen when the run scores its signature or holds its trace, and not otherwise" do
    recorded = described_class.new({ "a" => 1, "b" => 1, "c" => 1 }, { "a" => "ta", "b" => "tb" })
    current = described_class.new({ "c" => 2, "d" => 1 }, { "d" => "ta" })
    expect(recorded.within(current).to_h).to(eq(findings: { "a" => 1, "c" => 1 }, traces: { "a" => "ta" }))
  end
end
