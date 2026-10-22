# frozen_string_literal: true

RSpec.describe(Hashira::Dependencies, :aggregate_failures) do
  def lock
    <<~LOCK
      GIT
        remote: https://github.com/mongodb/mongoid.git
        specs:
          mongoid (9.0.10)
            activemodel (>= 5.1)

      PATH
        remote: .
        specs:
          rubocop-shop (1.0.0)
            rubocop (>= 1.0)

      GEM
        remote: https://rubygems.org/
        specs:
          devise (4.9.4)
            warden (~> 1.2.3)
          dfe-analytics (1.0)
          good_job (4.0)
          rubocop (1.80.0)

      DEPENDENCIES
        api-pagination
        devise

      CHECKSUMS
        sinatra (4.0) sha256=abc
    LOCK
  end

  def files
    {
      "Gemfile.lock" => lock,
      "Gemfile" => "source \"https://rubygems.org\"\ngem \"rails\"\ngem('kaminari', '~> 1')\n  # gem \"commented\"\n",
      "plugin.gemspec" => "Gem::Specification.new do |s|\n  s.add_dependency \"thor\"\nend\n",
      "nested/shop-billing.gemspec" =>
        "Gem::Specification.new do |s|\n  s.add_runtime_dependency(\"faraday\")\n  " \
        "s.add_development_dependency 'rspec'\nend\n"
    }
  end

  def verdicts(names) = within(files) { return names.map { described_class.new(".").foreign?(it) } }

  it "reads every gem a lockfile, a Gemfile or a gemspec names as foreign, by the root of its camelized name" do
    names = %w[Devise DfE GoodJob Mongoid RuboCop Rails Kaminari Thor Faraday RSpec]
    expect(verdicts(names)).to(all(be(true)))
  end

  it "keeps the project's own gems, local paths and unnamed roots out of the foreign ones" do
    names = %w[Plugin Shop Sinatra Api Activemodel Commented ApiPagination Warden]
    expect(verdicts(names)).to(all(be(false)))
  end

  def owns(paths) = within(files) { return paths.map { described_class.new(".").own?(it) } }

  it "owns what sits under one of the project's own gems, even under a dependency's root" do
    paths = [%w[RuboCop Shop Cop], %w[RuboCop Cop], %w[Shop Billing], %w[Plugin], %w[Shop]]
    expect(owns(paths)).to(eq([true, false, true, true, false]))
  end

  it "reads nothing where the project names no dependency" do
    expect(within({ "lib/a.rb" => "" }) { described_class.new(".").foreign?("Devise") }).to(be(false))
  end
end
