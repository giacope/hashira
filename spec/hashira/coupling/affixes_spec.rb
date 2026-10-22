# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Affixes, :aggregate_failures) do
  def affixes(source) = described_class.new(Prism.parse(source).value.statements.body.first.parts).to_a

  it "keeps a lower-case stem or a namespace for a prefix, and a tail past two characters for a suffix" do
    sources = <<~'RUBY'.lines
      "on_#{x}_done"
      "Billing#{x}"
      "Billing::#{x}"
      "#{x}_y"
      "#{x}Presenter"
    RUBY
    expect(
      sources.map do
        affixes(it)
      end
    ).to(eq([%w[on_ _done], ["", ""], ["Billing::", ""], ["", ""], ["", "Presenter"]]))
  end
end
