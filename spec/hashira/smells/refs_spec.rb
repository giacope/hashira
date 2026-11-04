# frozen_string_literal: true

require "prism"

RSpec.describe(Hashira::Smells::Refs, :aggregate_failures) do
  let(:definition) do
    Prism.parse(<<~RUBY).value.statements.body.first
      def ship(order)
        @count += 1
        order.lines.each { |line| line.pack && order.close }
        [1].map { |other| other }
      end
    RUBY
  end

  let(:calls) { Hashira::Analysis::NodeWalk.new(definition).collect.grep(Prism::CallNode) }

  let(:blocks) { calls.filter_map(&:block) }

  it "counts a method's own references and each holder's, by line" do
    words = Hashira::Smells::Words.new([Prism.parse("class Order\n  def lines = 1\nend\n").value])
    refs = described_class.new(definition, words)
    order = described_class::Local.new(:order, definition)
    expect([refs.lines, refs.lines(order), refs.sends(order).map(&:name)]).to(eq([[2], [3], %i[lines close]]))
  end

  it "tells a local by its name and the scope that binds it, and never equals another kind of object" do
    local = described_class::Local.new(:line, blocks.first)
    expect([local, local.to_sym]).to(eq([described_class::Local.new(:line, blocks.first), :line]))
    expect([local == described_class::Local.new(:line, blocks.last), local == :line]).to(eq([false, false]))
    expect({ local => 1 }.fetch(described_class::Local.new(:line, blocks.first))).to(eq(1))
  end

  it "sets a local beside another only when the same block binds both" do
    line = described_class::Local.new(:line, blocks.first)
    other = described_class::Local.new(:line, blocks.last)
    orders = [described_class::Local.new(:order, definition), described_class::Local.new(:order, definition)]
    expect([line.beside?(line), line.beside?(other), orders.first.beside?(orders.last)]).to(eq([true, false, false]))
  end

  it "finds the calls that yield a local only when their block binds it" do
    found = %i[line order].map { described_class::Local.new(it, blocks.first).yielders(calls) }
    expect(found).to(eq([[calls.find { it.block.equal?(blocks.first) }], []]))
    expect(described_class::Local.new(:order, nil).yielders(calls)).to(be_empty)
  end
end
