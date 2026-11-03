# frozen_string_literal: true

require "prism"

RSpec.describe(Hashira::Complexity::Charges, :aggregate_failures) do
  let(:node) { Prism.parse("\nfoo").value.statements.body.first }

  let(:marked) { described_class.mark(node, 2, "if") }

  it "adds nothing for an empty charge, and answers the other charge itself" do
    call = described_class.call
    sums = [described_class.none + call, call + described_class.none, marked + described_class.none]
    expect(sums.zip([call, call, marked]).map { |sum, kept| sum.equal?(kept) }).to(eq([true, true, true]))
  end

  it "sums the increments and the calls of two charges that both carry some" do
    total = marked + described_class.call + described_class.call
    expect([total.total, total.count, total.to_a.size, total.evidence]).to(eq([2, 2, 1, ["if +2 (line 2)"]]))
  end
end
