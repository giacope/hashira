# frozen_string_literal: true

RSpec.describe Hashira::Churn do
  it "tallies file paths from git log output, ignoring blank lines" do
    expect(described_class.tally("a.rb\nb.rb\n\na.rb\n")).to eq("a.rb" => 2, "b.rb" => 1)
  end

  it "counts hits by matching a display path against the git-path suffix" do
    churn = described_class.new("lib/app/foo.rb" => 3, "lib/app/bar.rb" => 1)

    expect(churn.hits("foo.rb")).to eq(3)
    expect(churn.hits("missing.rb")).to eq(0)
  end

  it "is hot only when at least two sites sit in changed files" do
    churn = described_class.new("a.rb" => 5, "b.rb" => 2)
    sites = [instance_double(Hashira::Duplication::Fragment, file: "a.rb"),
             instance_double(Hashira::Duplication::Fragment, file: "b.rb")]

    expect(churn.hot?(sites)).to be(true)
    expect(described_class.new("a.rb" => 5).hot?(sites)).to be(false)
  end
end
