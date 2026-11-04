# frozen_string_literal: true

RSpec.describe(Hashira::CLI::Sieve) do
  it "keeps only the findings of the kinds it was given, and every finding when given none" do
    found = %w[cycle nil_check cycle].map { handmade(it, "App") }
    everywhere = Hashira::CLI::Scope.new([], [], [], :auto)
    kept = [%w[cycle], []].map { described_class.new(everywhere, it, []).narrow(found) }
    expect(kept).to(eq([found.values_at(0, 2), found]))
  end
end
