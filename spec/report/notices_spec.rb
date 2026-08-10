# frozen_string_literal: true

RSpec.describe(Hashira::Report::Notices) do
  def pipeline(counts)
    instance_double(
      Hashira::Pipeline,
      churn: Hashira::Churn.new(counts),
      project: instance_double(Hashira::Project, label: "lib/app")
    )
  end

  def warned(counts)
    buffer = StringIO.new
    described_class.new(pipeline(counts), io: buffer).print
    buffer.string
  end
  it "stays quiet when the analyzed repo has history" do
    expect(warned("lib/app/x.rb" => 3)).to(be_empty)
  end
  it "explains the zeroes when the analyzed directory has no history" do
    expect(warned({})).to(eq("hashira: no git history for lib/app — hotspots are ranked by cost alone\n"))
  end
end
