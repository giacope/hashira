# frozen_string_literal: true

RSpec.describe(Hashira::Report::Phrases) do
  it "voices every finding kind the pipeline can emit, and no phantom kinds" do
    kinds = Hashira::CLI::FailOn::KINDS.values.flatten.uniq.sort
    voices = described_class.singleton_methods.grep(/\Aon_/).map { it.to_s.delete_prefix("on_") }.sort
    expect(voices).to(eq(kinds))
  end
end
