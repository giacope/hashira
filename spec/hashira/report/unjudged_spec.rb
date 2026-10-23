# frozen_string_literal: true

RSpec.describe(Hashira::Report::Unjudged, :aggregate_failures) do
  def shallow = Hashira::Churn::Depth.new(commits: 1, shallow: true, deep: false)

  def verdicts
    [[], %w[change_coupling]].product([true, false]).map do |kinds, judged|
      described_class.new(kinds:, depth: shallow, judged:).verdict
    end
  end

  it "keeps the healthy line only when every kind asked for was judged, and names the rest with the reason" do
    expect(verdicts).to(
      eq(
        [
          "none ✓ — structure is healthy", "none ✓ — structure is healthy",
          "none ✓ for the kinds judged; change_coupling not judged (shallow git history (1 commit))",
          "none — change_coupling could not judge: shallow git history (1 commit)"
        ]
      )
    )
  end

  it "lists each unjudged kind with its reason, and none by default" do
    told = described_class.new(kinds: %w[change_coupling], depth: shallow, judged: false).to_a
    expect([told, described_class::NONE.to_a])
      .to(eq([[{ kind: "change_coupling", reason: "shallow git history (1 commit)" }], []]))
  end
end
