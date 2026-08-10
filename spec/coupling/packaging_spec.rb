# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Census, "#charge") do
  it "groups types by top-level namespace across layer folders" do
    analyze(FixtureHelper::RAILS_FILES, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
      expect(census.packages).to(contain_exactly("ApplicationRecord", "Billing", "Ci", "User"))
      expect(census.types["Billing"]).to(eq(1))
    end
  end

  it "draws edges between namespaces, not folders" do
    analyze(FixtureHelper::RAILS_FILES, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["Billing -> Ci", "User -> Billing"]))
    end
  end

  it "strips the gem wrapper namespace and skips the wrapper itself" do
    analyze(FixtureHelper::CYCLIC_FILES, packaging: :namespace) do |_project, census, graph|
      expect(census.packages).to(contain_exactly("Alpha", "Beta", "Core"))
      expect(graph.edges.map(&:to_s)).to(eq(["Alpha -> Beta", "Alpha -> Core", "Beta -> Alpha"]))
    end
  end

  it "charges top-level code to the root package" do
    files = FixtureHelper::RAILS_FILES.merge("app/models/boot.rb" => "Billing::Invoice.new\n")
    analyze(files, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(include("(root) -> Billing"))
      expect(graph.packages).to(include("(root)"))
    end
  end

  describe "Rails awareness" do
    it "detects a Rails app by the config/application.rb beside the analyzed directory" do
      within(FixtureHelper::RAILS_FILES) { expect(Hashira::Project.new(["app"]).rails?).to(be(true)) }
      within(FixtureHelper::CYCLIC_FILES) { expect(Hashira::Project.new(["lib/app"]).rails?).to(be(false)) }
    end

    it "detects a Rails app when the analyzed directory is the Rails root itself" do
      within(FixtureHelper::RAILS_FILES) { expect(Hashira::Project.new(["."]).rails?).to(be(true)) }
    end

    it "keeps Application* references under an explicit folder packaging" do
      files = FixtureHelper::RAILS_FILES.merge(
        "app/services/report.rb" => "class Report\n  def render = ApplicationRecord.abstract\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :folder) do |_project, _census, graph|
        expect(graph.edges.map(&:to_s)).to(include("services -> models"))
      end
    end

    it "ignores references to Application* base classes in a Rails app" do
      analyze(FixtureHelper::RAILS_FILES, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
        expect(graph.edges.map(&:to_s)).not_to(include("User -> ApplicationRecord"))
      end
    end

    it "ignores references into Application* namespaces in a Rails app" do
      files = FixtureHelper::RAILS_FILES.merge(
        "app/channels/application_cable/connection.rb" =>
          "module ApplicationCable\n  class Connection\n    def id = 1\n  end\nend\n",
        "app/channels/exec_channel.rb" => "class ExecChannel < ApplicationCable::Channel\n  def sub = 1\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(census.packages).to(include("ExecChannel"))
        expect(graph.edges.map(&:to_s)).not_to(include("ExecChannel -> ApplicationCable"))
      end
    end

    it "keeps Application* references outside a Rails app" do
      files = FixtureHelper::RAILS_FILES.except("config/application.rb")
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.resolve(%w[ApplicationRecord])).to(eq("ApplicationRecord"))
      end
    end
  end

  describe "subclass folding" do
    it "folds a singleton subclass into its base's package, transitively" do
      files = FixtureHelper::RAILS_FILES.merge(FixtureHelper::NOTIFY_FILES)
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).not_to(include("AccountNotification", "GraceNotification"))
        expect(census.types["Notification"]).to(eq(3))
      end
    end

    it "charges and resolves through the fold" do
      alert = "module Billing\n  class Alert\n    def ping = GraceNotification\n  end\nend\n"
      files = FixtureHelper::RAILS_FILES.merge(FixtureHelper::NOTIFY_FILES, "app/models/billing/alert.rb" => alert)
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
        expect(graph.edges.map(&:to_s)).to(include("Notification -> Billing", "Billing -> Notification"))
      end
    end

    it "folds a suffix-named singleton into its domain package" do
      files = FixtureHelper::RAILS_FILES.merge(FixtureHelper::SANDBOX_FILES)
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).not_to(include("SandboxResource"))
        expect(census.types["Sandbox"]).to(eq(3))
      end
    end

    it "keeps a suffix-named class whose domain package does not exist" do
      resource = "class UsageSummaryResource < ApplicationResource\n  attributes :a\nend\n"
      files = FixtureHelper::RAILS_FILES.merge("app/resources/usage_summary_resource.rb" => resource)
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).to(include("UsageSummaryResource"))
      end
    end

    it "keeps suffix-named classes outside a Rails app" do
      files = FixtureHelper::RAILS_FILES.merge(FixtureHelper::SANDBOX_FILES).except("config/application.rb")
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).to(include("SandboxResource"))
      end
    end

    it "merges a mutually-linked base and suffix fold instead of swapping them" do
      files = FixtureHelper::RAILS_FILES.merge(
        "app/models/foo.rb" => "class Foo < FooPolicy\n  def a = 1\nend\n",
        "app/policies/foo_policy.rb" => "class FooPolicy\n  def p = 1\nend\n",
        "app/models/bar.rb" => "class Bar\n  def b = Foo.new\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(census.packages).to(include("Foo"))
        expect(census.packages).not_to(include("FooPolicy"))
        expect(census.types["Foo"]).to(eq(2))
        expect(graph.edges.map(&:to_s)).to(include("Bar -> Foo"))
      end
    end

    it "folds serializers into their domain, not an app-defined ApplicationSerializer" do
      serializer = ->(name) { "class #{name}Serializer < ApplicationSerializer\n  def x = 1\nend\n" }
      files = FixtureHelper::RAILS_FILES.merge(
        "app/serializers/application_serializer.rb" => "class ApplicationSerializer\n  def s = 1\nend\n",
        "app/serializers/billing_serializer.rb" => serializer.call("Billing"),
        "app/serializers/user_serializer.rb" => serializer.call("User")
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).not_to(include("BillingSerializer", "UserSerializer"))
        expect(census.folds).to(
          include(
            { from: "BillingSerializer", to: "Billing", via: "suffix" },
            { from: "UserSerializer", to: "User", via: "suffix" }
          )
        )
      end
    end

    it "keeps a class whose superclass matches a nested namesake only by suffix" do
      files = FixtureHelper::RAILS_FILES.merge(
        "app/models/admin/base.rb" => "module Admin\n  class Base\n    def b = 1\n  end\nend\n",
        "app/widgets/widget.rb" => "class Widget < Base\n  def w = Billing::Invoice.new\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(census.packages).to(include("Widget"))
        expect(graph.edges.map(&:to_s)).to(include("Widget -> Billing"))
        expect(graph.edges.map(&:to_s)).not_to(include("Admin -> Billing"))
      end
    end

    it "keeps the base fold whichever file order reopens a lone subclass" do
      %w[aext zext].each do |folder|
        files = FixtureHelper::RAILS_FILES.merge(
          FixtureHelper::NOTIFY_FILES,
          "app/#{folder}/account_notification.rb" => "class AccountNotification\n  def extra = 1\nend\n"
        )
        analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
          expect(census.packages).not_to(include("AccountNotification"))
          expect(census.types["Notification"]).to(eq(3))
        end
      end
    end

    it "does not fold a package into itself via its own nested superclass" do
      files = FixtureHelper::RAILS_FILES.merge(
        "app/models/sandbox.rb" => "class Sandbox < Sandbox::Base\n  def run = 1\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.folds).to(be_empty)
        expect(census.packages).to(include("Sandbox"))
      end
    end

    it "discloses every fold with its kind" do
      files = FixtureHelper::RAILS_FILES.merge(FixtureHelper::SANDBOX_FILES, FixtureHelper::NOTIFY_FILES)
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.folds).to(
          include(
            { from: "SandboxResource", to: "Sandbox", via: "suffix" },
            { from: "GraceNotification", to: "Notification", via: "base" }
          )
        )
      end
    end

    it "keeps a subclass that anchors its own namespace" do
      files = FixtureHelper::RAILS_FILES.merge(
        "app/models/notification.rb" => "class Notification\n  def read = 1\nend\n",
        "app/models/sandbox.rb" => "class Sandbox < Notification\n  def run = 1\nend\n",
        "app/models/sandbox/lifecycle.rb" => "module Sandbox::Lifecycle\n  def cycle = 1\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).to(include("Sandbox"))
        expect(census.types["Sandbox"]).to(eq(2))
      end
    end

    it "defaults the pipeline to namespace packaging for Rails apps" do
      within(FixtureHelper::RAILS_FILES) do
        pipeline = Hashira::Pipeline.new(Hashira::Project.new(["app"]))
        expect(pipeline.graph.edges.map(&:to_s)).to(eq(["Billing -> Ci", "User -> Billing"]))
      end
    end

    it "honors an explicit folder packaging override" do
      within(FixtureHelper::RAILS_FILES) do
        pipeline = Hashira::Pipeline.new(Hashira::Project.new(["app"]), packaging: :folder)
        expect(pipeline.graph.edges.map(&:to_s)).to(eq(["models -> jobs"]))
      end
    end
  end
end
