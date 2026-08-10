# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Census) do
  it "infers the majority outermost module as the namespace prefix" do
    analyze(FixtureHelper::CYCLIC_FILES) do |_project, census, _graph|
      expect(census.prefix).to(eq(["App"]))
    end
  end

  it "infers a deep prefix when every package shares a nested wrapper" do
    analyze(FixtureHelper::NESTED_FILES, directories: ["lib/app/core"]) do |_project, census, _graph|
      expect(census.prefix).to(eq(%w[App Core]))
    end
  end

  it "has an empty prefix when the tree defines no types" do
    analyze({ "lib/app/empty/notes.rb" => "# just a comment\n" }) do |_project, census, _graph|
      expect(census.prefix).to(eq([]))
    end
  end

  it "keeps a domain namespace that shares its folder with top-level classes" do
    files = {
      "app/models/billing_alert.rb" => "module Billing\n  class Alert\n    def a = 1\n  end\nend\n",
      "app/models/billing_charge.rb" => "module Billing\n  class Charge\n    def c = Alert.new\n  end\nend\n",
      "app/models/user.rb" => "class User\n  def u = Billing::Charge.new\nend\n",
      "app/models/order.rb" => "class Order\n  def o = 1\nend\n"
    }
    analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
      expect(census.packages).to(include("Billing", "User", "Order"))
      expect(graph.edges.map(&:to_s)).to(eq(["User -> Billing"]))
    end
  end

  it "counts a class reopened across files once" do
    files = {
      "app/models/user.rb" => "class User\n  def u = 1\nend\n",
      "app/concerns/user.rb" => "class User\nend\n"
    }
    analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
      expect(census.types["User"]).to(eq(1))
    end
  end

  it "counts a class whose body is only DSL calls" do
    files = FixtureHelper::CYCLIC_FILES.merge(
      "lib/app/alpha/styled.rb" => "module App; module Alpha; class Styled; register :thing; end; end; end\n"
    )
    analyze(files) do |_project, census, _graph|
      expect(census.types["alpha"]).to(eq(2))
    end
  end

  it "counts every class but only def-bearing modules as types" do
    files = {
      "lib/app/alpha/one.rb" => <<~RUBY,
        module App
          module Alpha
            class One
              def call = 1
            end

            class Two
              def call = 2
              def other = 3
            end

            module EmptyWrapper
            end
          end
        end
      RUBY
      "lib/app/beta/none.rb" => "module App; module Beta; end; end\n"
    }
    analyze(files) do |_project, census, _graph|
      expect(census.types).to(eq("alpha" => 2))
      expect(census.packages).to(contain_exactly("alpha", "beta"))
    end
  end

  it "records a depth-1 module with only direct methods (no nested types)" do
    files = { "lib/app/flat/flat.rb" => "module App; module Flat; def self.x = 1; end; end\n" }
    analyze(files) do |_project, census, _graph|
      expect(census.origins).to(eq("Flat" => "flat"))
    end
  end

  it "records the declaring package of each constant path" do
    analyze(FixtureHelper::CYCLIC_FILES) do |_project, census, _graph|
      expect(census.origins)
        .to(
          eq(
            "Alpha" => "alpha", "Alpha::One" => "alpha",
            "Beta" => "beta", "Beta::Two" => "beta",
            "Core" => "core", "Core::Util" => "core"
          )
        )
    end
  end

  it "records top-level constants outside the root namespace" do
    files = FixtureHelper::CYCLIC_FILES.merge(
      "lib/app/helpers/extra.rb" => "module AppHelpers; class Extra; def a = 1; end; end\n"
    )
    analyze(files) do |_project, census, _graph|
      expect(census.origins).to(include("AppHelpers" => "helpers"))
      expect(census.resolve(%w[AppHelpers Extra])).to(eq("helpers"))
    end
  end

  describe "#resolve" do
    it "resolves with and without the leading root namespace" do
      analyze(FixtureHelper::CYCLIC_FILES) do |_project, census, _graph|
        expect(census.resolve(%w[App Alpha One])).to(eq("alpha"))
        expect(census.resolve(%w[Alpha One])).to(eq("alpha"))
      end
    end

    it "resolves references under a deep namespace prefix at any depth" do
      analyze(FixtureHelper::NESTED_FILES, directories: ["lib/app/core"]) do |_project, census, _graph|
        expect(census.resolve(%w[Walk Stepper])).to(eq("walk"))
        expect(census.resolve(%w[Core Walk Stepper])).to(eq("walk"))
        expect(census.resolve(%w[App Core Walk Stepper])).to(eq("walk"))
        expect(census.resolve(%w[App Core])).to(be_nil)
      end
    end

    it "returns nil for external constants" do
      analyze(FixtureHelper::CYCLIC_FILES) do |_project, census, _graph|
        expect(census.resolve(%w[JSON])).to(be_nil)
        expect(census.resolve([])).to(be_nil)
      end
    end

    it "falls back to the namespace's package for an unknown member" do
      analyze(FixtureHelper::CYCLIC_FILES) do |_project, census, _graph|
        expect(census.resolve(%w[Alpha Unknown])).to(eq("alpha"))
      end
    end

    context "when a namespace spans several packages" do
      def mirror(&) = analyze(FixtureHelper::MIRROR_FILES, directories: ["app/controllers", "app/models"], &)

      it "resolves each constant path to its own package" do
        mirror do |_project, census, _graph|
          expect(census.resolve(%w[Admin Account])).to(eq("app/models/admin"))
          expect(census.resolve(%w[Admin AccountsController])).to(eq("app/controllers/admin"))
        end
      end

      it "resolves a bare name declared in exactly one package" do
        mirror { |_project, census, _graph| expect(census.resolve(%w[Skill])).to(eq("app/models/agent")) }
      end

      it "refuses to guess for contested names" do
        mirror do |_project, census, _graph|
          expect(census.resolve(%w[Admin])).to(be_nil)
          expect(census.resolve(%w[Admin Unknown])).to(be_nil)
          expect(census.resolve(%w[Settings])).to(be_nil)
        end
      end

      it "surfaces the reverse-layer edge instead of dropping it as a self-reference" do
        mirror do |_project, _census, graph|
          expect(graph.outgoing("app/models/admin")).to(eq(["app/controllers/admin"]))
          expect(graph.outgoing("app/controllers/agent")).to(eq(["app/models/agent"]))
        end
      end
    end
  end
end
