# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Census, "#charge", :aggregate_failures) do
  around { |example| within({}) { example.run } }

  # The census and graph of the files, written to the example's own folder.
  def charted(files, directories: ["app"], packaging: :namespace)
    files.each do |path, source|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, source)
    end
    pipeline(directories, packaging:).drop(1)
  end

  def edges(graph) = graph.edges.map(&:to_s)

  it "groups types by top-level namespace across layer folders" do
    analyze(Fixtures::RAILS_FILES, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
      expect(census.packages).to(contain_exactly("ApplicationRecord", "Billing", "Ci", "User"))
      expect(census.types["Billing"]).to(eq(1))
    end
  end

  it "draws edges between namespaces, not folders" do
    analyze(Fixtures::RAILS_FILES, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["Billing -> Ci", "User -> Billing"]))
    end
  end

  it "strips the gem wrapper namespace and skips the wrapper itself" do
    analyze(Fixtures::CYCLIC_FILES, packaging: :namespace) do |_project, census, graph|
      expect(census.packages).to(contain_exactly("Alpha", "Beta", "Core"))
      expect(graph.edges.map(&:to_s)).to(eq(["Alpha -> Beta", "Alpha -> Core", "Beta -> Alpha"]))
    end
  end

  it "skips every wrapper above a deep prefix, even one that defines methods" do
    files = Fixtures::NESTED_FILES.merge("lib/app/core/boot.rb" => "module App\n  def self.boot = 1\nend\n")
    analyze(files, packaging: :namespace) do |_project, census, _graph|
      expect(census.packages).to(contain_exactly("Search", "Walk"))
      expect(census.types).to(eq("Search" => 1, "Walk" => 1))
    end
  end

  it "keeps an engine class and a namespace's value constants in the root package, not packages of their own" do
    hub = "  class Hub\n    def adapters = ADAPTERS\n  end\n"
    files = {
      "lib/app/rails.rb" => "module App\n  class Engine < ::Rails::Engine\n  end\nend\n",
      "lib/app/setup.rb" => "module App\n  ADAPTERS = {}\n  Point = Data.define(:x)\n#{hub}end\n"
    }
    census, graph = charted(Fixtures::CYCLIC_FILES.merge(files), directories: ["lib/app"])
    expect([census.packages, edges(graph)]).to(
      match([contain_exactly("Alpha", "Beta", "Core", "Hub", "Point", "(root)"), include("Hub -> (root)")])
    )
  end

  it "charges top-level code to the root package" do
    files = Fixtures::RAILS_FILES.merge("app/models/boot.rb" => "Billing::Invoice.new\n")
    analyze(files, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(include("(root) -> Billing"))
      expect(graph.packages).to(include("(root)"))
    end
  end

  def policy(name) = "class #{name}Policy < ApplicationPolicy\n  def edit? = show?\nend\n\n#{name}Policy.prepend_mod\n"

  it "charges top-level code in a file that defines a type to that type's package, not to the root" do
    files = %w[Account Article Category Company Contact].to_h { ["app/policies/#{it.downcase}.rb", policy(it)] }
    base = { "app/policies/application_policy.rb" => "class ApplicationPolicy\n  def show? = true\nend\n" }
    _census, graph = charted(Fixtures::RAILS_FILES.merge(files, base))
    expect([graph.packages, edges(graph).grep(/Policy/)]).to(match([exclude("(root)"), be_empty]))
  end

  def entry(inside)
    "module Shop\n  class DuplicateError < StandardError; end\n#{hook if inside}end\n#{hook unless inside}"
  end

  def gem(inside)
    {
      "lib/shop.rb" => entry(inside), "lib/shop/engine.rb" => "module Shop\n  class Engine < Rails::Engine; end\nend\n",
      "lib/shop/taggable.rb" => "module Shop\n  module Taggable\n    def tag(name) = Tag.new(name)\n  end\nend\n",
      "lib/shop/tag.rb" => "module Shop\n  class Tag\n    def save = raise(DuplicateError)\n  end\nend\n"
    }
  end

  def hook = "ActiveSupport.on_load(:active_record) do\n  extend Shop::Taggable\nend\n"

  def hooked = "module Shop\n  class Tag\n    def save = 1\n  end\nend\nActiveSupport.run_load_hooks(:tag, Shop::Tag)\n"

  it "charges top-level code after a namespace to the root, not to the first class the namespace holds" do
    found = [false, true].map { edges(charted(gem(it), directories: ["lib"]).last).grep(/-> Taggable/) }
    expect(found).to(eq([["(root) -> Taggable"]] * 2))
  end

  def label = "class Shop::Label\n  def text = 1\nend\nShop::Label.configure(Shop::Taggable)\n"

  it "keeps a top-level statement that names a type the file defines that type's own, the rest the top-level class's" do
    files = gem(false).merge("lib/shop/tag.rb" => hooked, "lib/shop/label.rb" => label)
    _census, graph = charted(files, directories: ["lib"])
    expect(edges(graph).grep(/-> Tag\z|Label/)).to(eq(["Label -> Taggable", "Taggable -> Tag"]))
  end

  describe "top-level statements that write a namespaced constant" do
    def payments(source)
      files = Fixtures::RAILS_FILES.merge(
        "app/models/payments/ledger.rb" => "module Payments\n  class Ledger\n    def l = 1\n  end\nend\n",
        "app/models/payments/rate.rb" => source
      )
      analyze(files, directories: ["app"], packaging: :namespace) { |_project, _census, graph| yield(graph) }
    end

    it "charges a top-level constant write to the constant it writes, not to (root)" do
      payments("Payments::Rate = Data.define(:amount) do\n  def bill = Billing::Invoice\nend\n") do |graph|
        expect(graph.edges.map(&:to_s)).to(include("Payments -> Billing"))
        expect(graph.edges.map(&:to_s)).not_to(include("(root) -> Payments", "(root) -> Billing"))
      end
    end

    it "charges what a constant write holds to that constant, even inside another namespace" do
      held = "module Billing\n  Payments::Rate = Data.define(:amount) do\n    def run = Ci::Runner\n  end\nend\n"
      payments(held) do |graph|
        expect(graph.edges.map(&:to_s)).to(include("Payments -> Ci"))
        expect(graph.edges.map(&:to_s)).not_to(include("Billing -> Payments"))
      end
    end

    it "charges every compound write the same way" do
      ["||=", "&&=", "+="].each do |operator|
        payments("Payments::Rate #{operator} Billing::Invoice\n") do |graph|
          expect(graph.edges.map(&:to_s)).to(eq(["Billing -> Ci", "Payments -> Billing", "User -> Billing"]))
        end
      end
    end

    it "charges a declaration sent to a namespaced constant to that constant" do
      %w[private_constant public_constant include extend prepend].each do |declaration|
        payments("Payments::Ledger.#{declaration}(Billing::Invoice)\n") do |graph|
          expect(graph.edges.map(&:to_s)).to(eq(["Billing -> Ci", "Payments -> Billing", "User -> Billing"]))
        end
      end
    end

    it "keeps an ordinary call on a constant charged to where it is made" do
      payments("Payments::Ledger.register(Billing::Invoice)\n") do |graph|
        expect(graph.edges.map(&:to_s)).to(include("(root) -> Billing", "(root) -> Payments"))
      end
    end

    it "keeps a declaration sent to an expression charged to where it is made" do
      payments("ledger.include(Billing::Invoice)\n") do |graph|
        expect(graph.edges.map(&:to_s)).to(include("(root) -> Billing"))
      end
    end

    it "falls back to the enclosing package when the written constant is not the project's" do
      sources = ["Rails::Engine.include(Billing::Invoice)\n", "module Payments\n  Rails::Engine.include(Billing::Invoice)\nend\n"]
      expect(sources.map { payments(it) { |graph| edges(graph) } }).to(
        match([include("(root) -> Billing"), include("Payments -> Billing")])
      )
    end
  end

  describe "Rails awareness" do
    it "takes a top-level class for a framework adapter only if it extends an outside class the app's classes extend" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/billing/base.rb" => "module Billing\n  class Base < ActiveRecord::Base\n  end\nend\n",
        "app/models/billing/charge.rb" => "module Billing\n  class Charge < Base\n  end\nend\n",
        "app/models/solo.rb" => "class Solo < ActiveRecord::Base\nend\n",
        "app/services/report.rb" => "class Report\n  def r = [Billing::Charge, Solo, ApplicationRecord]\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
        expect(graph.edges.map(&:to_s).grep(/\AReport/)).to(contain_exactly("Report -> Billing", "Report -> Solo"))
      end
    end

    it "takes a class built on a computed parent for a framework adapter, and a class with no parent for the app's" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/shop_record.rb" => "class ShopRecord < Shop.model_parent.constantize\nend\n",
        "app/models/charge.rb" => "class Charge < ShopRecord\nend\n",
        "app/models/plain.rb" => "class Plain\nend\n",
        "app/models/leaf.rb" => "class Leaf < Plain\nend\n",
        "app/services/report.rb" => "class Report\n  def r = [Charge, ShopRecord, Leaf]\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(graph.edges.map(&:to_s).grep(/\AReport/)).to(contain_exactly("Report -> Charge", "Report -> Plain"))
        expect(census.folds.map { it[:from] }).to(eq(%w[Leaf]))
      end
    end

    it "keeps a record on ActiveRecord::Base that its subclasses extend unless it says it is abstract" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/notification.rb" => "class Notification < ActiveRecord::Base\nend\n",
        "app/models/message.rb" => "class Message < Notification\nend\n",
        "app/models/base_record.rb" => "class BaseRecord < ::ActiveRecord::Base\n  primary_abstract_class\nend\n",
        "app/models/ledger.rb" => "class Ledger < BaseRecord\nend\n",
        "app/services/report.rb" => "class Report\n  def r = [Message, Notification, Ledger, BaseRecord]\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(edges(graph).grep(/\AReport/)).to(contain_exactly("Report -> Ledger", "Report -> Notification"))
        expect(census.folds.map { it[:from] }).to(eq(%w[Message]))
      end
    end

    it "takes an engine's adapter for one however its heirs spell it, so no model folds into it" do
      shop = ->(name, parent) { "module Shop\n  class #{name} < #{parent}\n  end\nend\n" }
      files = {
        "shop.gemspec" => "",
        "lib/shop/engine.rb" => shop.call("Engine", "::Rails::Engine"),
        "app/models/shop/application_record.rb" => shop.call("ApplicationRecord", "ActiveRecord::Base"),
        "app/models/shop/charge.rb" => shop.call("Charge", "Shop::ApplicationRecord"),
        "app/models/shop/refund.rb" => shop.call("Refund", "Shop::ApplicationRecord"),
        "app/models/shop/stripe/charge.rb" => shop.call("Stripe::Charge", "Shop::Charge"),
        "app/models/shop/stripe/refund.rb" => shop.call("Stripe::Refund", "Shop::Refund")
      }
      analyze(files, directories: %w[app lib], packaging: :namespace) do |_project, census, graph|
        expect([census.folds, edges(graph)]).to(eq([[], ["Stripe -> Charge", "Stripe -> Refund"]]))
      end
    end

    it "resolves an adapter's superclass where it is written, so a namespace mirroring a library's owns nothing" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/extensions/audit/active_record/base.rb" =>
          "module Extensions::Audit::ActiveRecord::Base\n  def a = 1\nend\n",
        "app/models/solo.rb" => "class Solo < ::ActiveRecord::Base\nend\n",
        "app/models/ledger.rb" => "class Ledger < ApplicationRecord\nend\n",
        "app/services/report.rb" => "class Report\n  def r = [Solo, Ledger, ApplicationRecord]\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(graph.edges.map(&:to_s).grep(/\AReport/)).to(contain_exactly("Report -> Ledger", "Report -> Solo"))
        expect(census.folds.map(&:from)).not_to(include("Ledger"))
      end
    end

    def lexical(parent)
      files = {
        "app/models/extensions/active_record/base.rb" => "module Extensions::ActiveRecord::Base\nend\n",
        "app/models/extensions/record.rb" =>
          "module Extensions\n  class ::Record < #{parent}\n    self.abstract_class = true\n  end\nend\n",
        "app/models/ledger.rb" => "class Ledger < Record\nend\n",
        "app/services/report.rb" => "class Report\n  def r = Record\nend\n"
      }
      analyze(Fixtures::RAILS_FILES.merge(files), directories: ["app"], packaging: :namespace) do |*, graph|
        graph.edges.map(&:to_s).grep(/\AReport/)
      end
    end

    it "resolves an unrooted superclass lexically and a rooted one from the top, wherever the class is written" do
      expect(["::ActiveRecord::Base", "ActiveRecord::Base"].map { lexical(it) }).to(eq([[], ["Report -> Record"]]))
    end

    it "detects a Rails app by the config/application.rb beside the analyzed directory" do
      within(Fixtures::RAILS_FILES) { expect(Hashira::Project.new(["app"]).rails?).to(be(true)) }
      within(Fixtures::CYCLIC_FILES) { expect(Hashira::Project.new(["lib/app"]).rails?).to(be(false)) }
    end

    it "detects a Rails app when the analyzed directory is the Rails root itself" do
      within(Fixtures::RAILS_FILES) { expect(Hashira::Project.new(["."]).rails?).to(be(true)) }
    end

    it "keeps Application* references under an explicit folder packaging" do
      files = Fixtures::RAILS_FILES.merge(
        "app/services/report.rb" => "class Report\n  def render = ApplicationRecord.abstract\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :folder) do |_project, _census, graph|
        expect(graph.edges.map(&:to_s)).to(include("services -> models"))
      end
    end

    it "ignores references to Application* base classes in a Rails app" do
      analyze(Fixtures::RAILS_FILES, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
        expect(graph.edges.map(&:to_s)).not_to(include("User -> ApplicationRecord"))
      end
    end

    it "ignores references into Application* namespaces in a Rails app" do
      files = Fixtures::RAILS_FILES.merge(
        "app/channels/application_cable/connection.rb" =>
          "module ApplicationCable\n  class Connection < ActionCable::Connection::Base\n    def id = 1\n  end\nend\n",
        "app/channels/application_cable/channel.rb" =>
          "module ApplicationCable\n  class Channel < ActionCable::Channel::Base\n  end\nend\n",
        "app/channels/exec_channel.rb" => "class ExecChannel < ApplicationCable::Channel\n  def sub = 1\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(census.packages).to(include("ExecChannel"))
        expect(graph.edges.map(&:to_s)).not_to(include("ExecChannel -> ApplicationCable"))
      end
    end

    it "keeps Application* references outside a Rails app" do
      files = Fixtures::RAILS_FILES.except("config/application.rb")
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.resolve(%w[ApplicationRecord])).to(eq("ApplicationRecord"))
      end
    end
  end

  describe "layer awareness" do
    def storefront
      {
        "config/application.rb" => "module Shop; class Application; end; end\n",
        "app/models/order.rb" => "class Order < ApplicationRecord\n  def bill = Billing::Invoice.new\nend\n",
        "app/models/current.rb" => "class Current\n  def self.user = 1\nend\n",
        "app/models/billing/invoice.rb" => "module Billing\n  class Invoice\n    def pay = 1\n  end\nend\n"
      }
    end

    def shop(extra = {}, packaging: :namespace) = charted(storefront.merge(extra), packaging:)

    it "keeps a serializer named for a domain out of that domain" do
      resources = {
        "app/resources/order_resource.rb" =>
          "class OrderResource < ApplicationResource\n  def total = Order.new\nend\n",
        "app/resources/current_resource.rb" =>
          "class CurrentResource < ApplicationResource\n  def owner = [Current.user, Billing::Invoice]\nend\n"
      }
      census, graph = shop(resources)
      expect([census.folds, census.packages]).to(
        match([be_empty, include("(web)").and(exclude("OrderResource", "CurrentResource"))])
      )
      expect(edges(graph)).to(
        include("(web) -> Order", "(web) -> Current", "(web) -> Billing").and(exclude("Current -> Billing"))
      )
    end

    it "does not fold a controller into the namespace of its base controller" do
      controllers = {
        "app/controllers/app/base_controller.rb" =>
          "module App\n  class BaseController < ApplicationController\n    def a = 1\n  end\nend\n",
        "app/models/app/settings.rb" => "module App\n  class Settings\n    def s = 1\n  end\nend\n",
        "app/controllers/things_controller.rb" =>
          "class ThingsController < App::BaseController\n  def index = Order\nend\n"
      }
      census, graph = shop(controllers)
      expect([census.folds, census.types["App"]]).to(eq([[], 1]))
      expect(edges(graph)).to(include("(web) -> Order").and(exclude("App -> Order")))
    end

    it "keeps a namespace made only of controllers from becoming a package" do
      namespaced = "module Admin\n  class OrdersController < ApplicationController\n    def index = Order\n  end\nend\n"
      census, graph = shop({ "app/controllers/admin/orders_controller.rb" => namespaced })
      expect([census.packages, census.resolve(%w[Admin OrdersController])]).to(match([exclude("Admin"), eq("(web)")]))
      expect(edges(graph)).to(eq(["(web) -> Order", "Order -> Billing"]))
    end

    it "keeps a controller nested in a domain namespace out of that domain" do
      orders = {
        "app/controllers/shipping/labels_controller.rb" =>
          "module Shipping\n  class LabelsController < ApplicationController\n    def create = LabelJob\n  end\nend\n",
        "app/jobs/shipping/label_job.rb" =>
          "module Shipping\n  class LabelJob\n    def perform = Billing::Invoice\n  end\nend\n"
      }
      census, graph = shop(orders)
      expect([census.types, census.resolve(%w[Shipping])])
        .to(match([include("Shipping" => 1, "(web)" => 1), eq("Shipping")]))
      expect(edges(graph)).to(include("(web) -> Shipping", "Shipping -> Billing"))
    end

    it "charges a controller concern to the presentation package" do
      concern = "module Authentication\n  def current = Current.user\nend\n"
      census, graph = shop({ "app/controllers/concerns/authentication.rb" => concern })
      expect([census.packages, edges(graph)]).to(match([exclude("Authentication"), include("(web) -> Current")]))
    end

    def presentation
      {
        "app/controllers/orders_controller.rb" =>
          "class OrdersController < ApplicationController\n  def index = [Order, Billing::Invoice]\nend\n",
        "app/controllers/invoices_controller.rb" =>
          "class InvoicesController < ApplicationController\n  def index = Billing::Invoice\nend\n",
        "app/models/billing/charge.rb" =>
          "module Billing\n  class Charge\n    def back = [OrdersController, Order]\n  end\nend\n",
        "app/serializers/order_serializer.rb" =>
          "class OrderSerializer\n  def x = [Billing::A, Billing::B, Billing::C, Billing::D]\nend\n"
      }
    end

    it "counts presentation as one client: never in a cycle, never an SDP violation, never a wide edge" do
      _census, graph = shop(presentation)
      expect(edges(graph)).to(include("(web) -> Billing", "(web) -> Order", "Billing -> (web)"))
      expect([graph.cycles.knots, graph.violations, graph.domain.map(&:to_s)]).to(
        eq([[%w[Billing Order]], [], ["Billing -> Order", "Order -> Billing"]])
      )
      expect([graph.metric("Billing").to_h, graph.metric("(web)").to_h, graph.usage("Billing").keys]).to(
        eq([{ tc: 2, ca: 2, ce: 1, i: 1.0 / 3 }, { tc: 3, ca: 0, ce: 2, i: 1.0 }, ["(web)", "Order"]])
      )
    end

    def tests
      {
        "test/test_helper.rb" => "class ActiveSupport::TestCase\n  def signed = Current.user\nend\n",
        "test/helpers/invoice_helper.rb" => "module InvoiceHelper\n  def build = Billing::Invoice.new\nend\n",
        "test/models/order_test.rb" => "class OrderTest < ActiveSupport::TestCase\n  def test_bill = Order.new\nend\n",
        "test/models/billing/invoice_test.rb" =>
          "class Billing::InvoiceTest < ActiveSupport::TestCase\n  include InvoiceHelper\n  def t = Order\nend\n",
        "test/controllers/orders_controller_test.rb" =>
          "class OrdersControllerTest < ActionDispatch::IntegrationTest\n  def test_index = Order\nend\n"
      }
    end

    it "puts tests in one (test) package, a test in a domain's namespace included" do
      census, _graph = charted(storefront.merge(tests), directories: %w[app test])
      expect(census.packages).to(
        include("(test)").and(exclude("InvoiceHelper", "OrderTest", "OrdersControllerTest", "(web)"))
      )
      resolved = [%w[InvoiceHelper], %w[OrderTest], %w[Billing InvoiceTest]].map { census.resolve(it) }
      expect(resolved).to(eq(["(test)"] * 3))
    end

    it "never counts the (test) package as a client, so a test never joins a domain's cycles" do
      _census, graph = charted(storefront.merge(tests), directories: %w[app test])
      expect(edges(graph)).to(include("(test) -> Billing", "(test) -> Current", "(test) -> Order"))
      expect([graph.cycles.knots, graph.usage("Billing").keys, graph.domain.map(&:to_s)]).to(
        eq([[], ["Order"], ["Order -> Billing"]])
      )
      expect([graph.metric("Order").to_h, graph.metric("(test)").to_h])
        .to(eq([{ tc: 1, ca: 0, ce: 1, i: 1.0 }, { tc: 5, ca: 0, ce: 0, i: nil }]))
    end

    it "keeps the layer view under folder packaging" do
      namespaced = "module Admin\n  class OrdersController < ApplicationController\n    def index = Order\n  end\nend\n"
      census, graph = shop({ "app/controllers/admin/orders_controller.rb" => namespaced }, packaging: :folder)
      expect([census.packages, edges(graph)]).to(match([exclude("(web)"), include("controllers -> models")]))
    end

    it "keeps controllers in their namespace outside a Rails app" do
      files = {
        "app/controllers/admin/orders_controller.rb" =>
          "module Admin\n  class OrdersController\n    def index = Order\n  end\nend\n",
        "app/models/order.rb" => "class Order\n  def o = 1\nend\n"
      }
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(census.packages).to(contain_exactly("Admin", "Order"))
        expect(edges(graph)).to(eq(["Admin -> Order"]))
      end
    end
  end

  describe "subclass folding" do
    it "folds a singleton subclass into its base's package, transitively" do
      files = Fixtures::RAILS_FILES.merge(Fixtures::NOTIFY_FILES)
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).not_to(include("AccountNotification", "GraceNotification"))
        expect(census.types["Notification"]).to(eq(3))
      end
    end

    it "charges and resolves through the fold" do
      alert = "module Billing\n  class Alert\n    def ping = GraceNotification\n  end\nend\n"
      files = Fixtures::RAILS_FILES.merge(Fixtures::NOTIFY_FILES, "app/models/billing/alert.rb" => alert)
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
        expect(graph.edges.map(&:to_s)).to(include("Notification -> Billing", "Billing -> Notification"))
      end
    end

    it "folds a suffix-named singleton into its domain package" do
      files = Fixtures::RAILS_FILES.merge(Fixtures::SANDBOX_FILES)
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).not_to(include("SandboxPolicy"))
        expect(census.types["Sandbox"]).to(eq(3))
      end
    end

    it "keeps a suffix-named class whose domain package does not exist" do
      policy = "class UsageSummaryPolicy < ApplicationPolicy\n  def show? = true\nend\n"
      files = Fixtures::RAILS_FILES.merge("app/policies/usage_summary_policy.rb" => policy)
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).to(include("UsageSummaryPolicy"))
      end
    end

    it "keeps suffix-named classes outside a Rails app" do
      files = Fixtures::RAILS_FILES.merge(Fixtures::SANDBOX_FILES).except("config/application.rb")
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).to(include("SandboxPolicy"))
      end
    end

    it "merges a mutually-linked base and suffix fold instead of swapping them" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/foo.rb" => "class Foo < FooPolicy\n  def a = 1\nend\n",
        "app/policies/foo_policy.rb" => "class FooPolicy\n  def p = 1\nend\n",
        "app/models/bar.rb" => "class Bar\n  def b = Foo.new\nend\n"
      )
      census, graph = charted(files)
      expect([census.packages, census.types["Foo"]]).to(match([include("Foo").and(exclude("FooPolicy")), eq(2)]))
      expect(edges(graph)).to(include("Bar -> Foo"))
    end

    def decorator(name) = "class #{name}Decorator < ApplicationDecorator\n  def x = 1\nend\n"

    it "folds decorators into their domain, not an app-defined ApplicationDecorator" do
      census, _graph = charted(
        Fixtures::RAILS_FILES.merge(
          "app/decorators/application_decorator.rb" =>
            "class ApplicationDecorator < Draper::Decorator\n  def s = 1\nend\n",
          "app/decorators/billing_decorator.rb" => decorator("Billing"),
          "app/decorators/user_decorator.rb" => decorator("User")
        )
      )
      expect(census.packages).not_to(include("BillingDecorator", "UserDecorator"))
      expect(census.folds).to(
        include(
          { from: "BillingDecorator", to: "Billing", via: "suffix" },
          { from: "UserDecorator", to: "User", via: "suffix" }
        )
      )
    end

    it "keeps a class whose superclass matches a nested namesake only by suffix" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/admin/base.rb" => "module Admin\n  class Base\n    def b = 1\n  end\nend\n",
        "app/widgets/widget.rb" => "class Widget < Base\n  def w = Billing::Invoice.new\nend\n"
      )
      census, graph = charted(files)
      expect([census.packages, edges(graph)]).to(
        match([include("Widget"), include("Widget -> Billing").and(exclude("Admin -> Billing"))])
      )
    end

    def reopened(folder)
      files = Fixtures::RAILS_FILES.merge(
        Fixtures::NOTIFY_FILES,
        "app/#{folder}/account_notification.rb" => "class AccountNotification\n  def extra = 1\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        [census.packages.include?("AccountNotification"), census.types["Notification"]]
      end
    end

    it "keeps the base fold whichever file order reopens a lone subclass" do
      expect(%w[aext zext].map { reopened(it) }).to(eq([[false, 3], [false, 3]]))
    end

    it "does not fold a package into itself via its own nested superclass" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/sandbox.rb" => "class Sandbox < Sandbox::Base\n  def run = 1\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.folds).to(be_empty)
        expect(census.packages).to(include("Sandbox"))
      end
    end

    it "folds a plural namespace into its singular namesake, so one aggregate is one package" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/order.rb" => "class Order\n  def refund = Orders::RefundJob\nend\n",
        "app/jobs/orders/refund_job.rb" => "module Orders\n  class RefundJob\n    def perform = Order\n  end\nend\n",
        "app/models/shop.rb" => "class Shop\n  def run = Orders::RefundJob\nend\n"
      )
      census, graph = charted(files)
      expect([census.folds, census.types["Order"]])
        .to(match([include({ from: "Orders", to: "Order", via: "plural" }), eq(2)]))
      expect([edges(graph), graph.cycles.knots]).to(match([include("Shop -> Order"), be_empty]))
    end

    def plural(name) = "module #{name}\n  class Item\n    def i = 1\n  end\nend\n"

    def single(name) = "class #{name}\n  def s = 1\nend\n"

    def plurals
      Fixtures::RAILS_FILES.merge(
        "app/models/box.rb" => single("Box"), "app/models/boxes/item.rb" => plural("Boxes"),
        "app/models/category.rb" => single("Category"), "app/models/categories/item.rb" => plural("Categories"),
        "app/models/settings/item.rb" => plural("Settings")
      )
    end

    it "folds -es and -ies plurals too, and keeps a plural with no singular namesake" do
      census, _graph = charted(plurals)
      expect(census.folds).to(
        contain_exactly(
          { from: "Boxes", to: "Box", via: "plural" }, { from: "Categories", to: "Category", via: "plural" }
        )
      )
      expect(census.packages).to(include("Settings"))
    end

    it "folds a module that only extends or includes another into the module it adopts" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/notifier.rb" => "module Notifier\n  def notify = Billing::Invoice\nend\n",
        "app/events/order_shipped.rb" => "module OrderShipped\n  extend ActiveSupport::Concern, Notifier\nend\n",
        "app/events/order_paid.rb" => "module OrderPaid\n  include Notifier\nend\n",
        "app/models/user.rb" => "class User\n  def ship = [OrderShipped, OrderPaid]\nend\n"
      )
      census, graph = charted(files)
      expect(census.folds).to(
        contain_exactly(
          { from: "OrderPaid", to: "Notifier", via: "mixin" }, { from: "OrderShipped", to: "Notifier", via: "mixin" }
        )
      )
      expect([edges(graph), graph.metric("Notifier").to_h]).to(match([include("User -> Notifier"), include(ca: 1)]))
    end

    it "keeps a module that does more than adopt another, or adopts nothing the project defines" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/notifier.rb" => "module Notifier\n  def notify = 1\nend\n",
        "app/events/order_shipped.rb" => "module OrderShipped\n  extend Notifier\n  def self.payload = 1\nend\n",
        "app/events/order_paid.rb" => "module OrderPaid\n  User.extend Notifier\nend\n",
        "app/events/order_held.rb" => "module OrderHeld\n  include\nend\n",
        "app/events/order_kept.rb" => "module OrderKept\n  extend ActiveSupport::Concern\nend\n",
        "app/events/order_lost.rb" => "module OrderLost\n  extend Notifier\nend\n",
        "app/events/order_lost/reason.rb" => "module OrderLost\n  class Reason\n    def r = 1\n  end\nend\n",
        "app/events/order_found.rb" => "module OrderFound\n  extend Notifier\nend\n",
        "app/models/order_found.rb" => "module OrderFound\n  def found = 1\nend\n",
        "app/events/order_sent.rb" => "class OrderSent\n  include Notifier\nend\n",
        "app/events/order_gone.rb" => "module OrderGone\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.folds).to(be_empty)
      end
    end

    it "discloses every fold with its kind" do
      files = Fixtures::RAILS_FILES.merge(Fixtures::SANDBOX_FILES, Fixtures::NOTIFY_FILES)
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.folds).to(
          include(
            { from: "SandboxPolicy", to: "Sandbox", via: "suffix" },
            { from: "GraceNotification", to: "Notification", via: "base" }
          )
        )
      end
    end

    it "keeps a subclass that anchors its own namespace" do
      files = Fixtures::RAILS_FILES.merge(
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
      within(Fixtures::RAILS_FILES) do
        pipeline = Hashira::Pipeline.new(Hashira::Project.new(["app"]))
        expect(pipeline.graph.edges.map(&:to_s)).to(eq(["Billing -> Ci", "User -> Billing"]))
      end
    end

    it "honors an explicit folder packaging override" do
      within(Fixtures::RAILS_FILES) do
        pipeline = Hashira::Pipeline.new(Hashira::Project.new(["app"]), packaging: :folder)
        expect(pipeline.graph.edges.map(&:to_s)).to(eq(["models -> jobs"]))
      end
    end
  end
end
