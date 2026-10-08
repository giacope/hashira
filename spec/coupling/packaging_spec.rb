# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Census, "#charge") do
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

  it "charges top-level code to the root package" do
    files = Fixtures::RAILS_FILES.merge("app/models/boot.rb" => "Billing::Invoice.new\n")
    analyze(files, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(include("(root) -> Billing"))
      expect(graph.packages).to(include("(root)"))
    end
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
      payments("Rails::Engine.include(Billing::Invoice)\n") do |graph|
        expect(graph.edges.map(&:to_s)).to(include("(root) -> Billing"))
      end
      payments("module Payments\n  Rails::Engine.include(Billing::Invoice)\nend\n") do |graph|
        expect(graph.edges.map(&:to_s)).to(include("Payments -> Billing"))
      end
    end
  end

  describe "Rails awareness" do
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
          "module ApplicationCable\n  class Connection\n    def id = 1\n  end\nend\n",
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

    def shop(extra = {}, packaging: :namespace, &)
      analyze(storefront.merge(extra), directories: ["app"], packaging:, &)
    end

    def edges(graph) = graph.edges.map(&:to_s)

    it "keeps a serializer named for a domain out of that domain" do
      resources = {
        "app/resources/order_resource.rb" =>
          "class OrderResource < ApplicationResource\n  def total = Order.new\nend\n",
        "app/resources/current_resource.rb" =>
          "class CurrentResource < ApplicationResource\n  def owner = [Current.user, Billing::Invoice]\nend\n"
      }
      shop(resources) do |_project, census, graph|
        expect(census.folds).to(be_empty)
        expect(census.packages).to(include("(web)"))
        expect(census.packages).not_to(include("OrderResource", "CurrentResource"))
        expect(edges(graph)).to(include("(web) -> Order", "(web) -> Current", "(web) -> Billing"))
        expect(edges(graph)).not_to(include("Current -> Billing"))
      end
    end

    it "does not fold a controller into the namespace of its base controller" do
      controllers = {
        "app/controllers/app/base_controller.rb" =>
          "module App\n  class BaseController < ApplicationController\n    def a = 1\n  end\nend\n",
        "app/models/app/settings.rb" => "module App\n  class Settings\n    def s = 1\n  end\nend\n",
        "app/controllers/things_controller.rb" =>
          "class ThingsController < App::BaseController\n  def index = Order\nend\n"
      }
      shop(controllers) do |_project, census, graph|
        expect(census.folds).to(be_empty)
        expect(census.types["App"]).to(eq(1))
        expect(edges(graph)).to(include("(web) -> Order"))
        expect(edges(graph)).not_to(include("App -> Order"))
      end
    end

    it "keeps a namespace made only of controllers from becoming a package" do
      namespaced = "module Admin\n  class OrdersController < ApplicationController\n    def index = Order\n  end\nend\n"
      shop({ "app/controllers/admin/orders_controller.rb" => namespaced }) do |_project, census, graph|
        expect(census.packages).not_to(include("Admin"))
        expect(census.resolve(%w[Admin OrdersController])).to(eq("(web)"))
        expect(edges(graph)).to(eq(["(web) -> Order", "Order -> Billing"]))
      end
    end

    it "keeps a controller nested in a domain namespace out of that domain" do
      orders = {
        "app/controllers/shipping/labels_controller.rb" =>
          "module Shipping\n  class LabelsController < ApplicationController\n    def create = LabelJob\n  end\nend\n",
        "app/jobs/shipping/label_job.rb" =>
          "module Shipping\n  class LabelJob\n    def perform = Billing::Invoice\n  end\nend\n"
      }
      shop(orders) do |_project, census, graph|
        expect(census.types).to(include("Shipping" => 1, "(web)" => 1))
        expect(census.resolve(%w[Shipping])).to(eq("Shipping"))
        expect(edges(graph)).to(include("(web) -> Shipping", "Shipping -> Billing"))
      end
    end

    it "charges a controller concern to the presentation package" do
      concern = "module Authentication\n  def current = Current.user\nend\n"
      shop({ "app/controllers/concerns/authentication.rb" => concern }) do |_project, census, graph|
        expect(census.packages).not_to(include("Authentication"))
        expect(edges(graph)).to(include("(web) -> Current"))
      end
    end

    it "counts presentation as one client: never in a cycle, never an SDP violation, never a wide edge" do
      web = {
        "app/controllers/orders_controller.rb" =>
          "class OrdersController < ApplicationController\n  def index = [Order, Billing::Invoice]\nend\n",
        "app/controllers/invoices_controller.rb" =>
          "class InvoicesController < ApplicationController\n  def index = Billing::Invoice\nend\n",
        "app/models/billing/charge.rb" =>
          "module Billing\n  class Charge\n    def back = [OrdersController, Order]\n  end\nend\n",
        "app/serializers/order_serializer.rb" =>
          "class OrderSerializer\n  def x = [Billing::A, Billing::B, Billing::C, Billing::D]\nend\n"
      }
      shop(web) do |_project, _census, graph|
        expect(edges(graph)).to(include("(web) -> Billing", "(web) -> Order", "Billing -> (web)"))
        expect(graph.cycles.knots).to(eq([%w[Billing Order]]))
        expect(graph.metric("Billing").to_h).to(eq(tc: 2, ca: 2, ce: 1, i: 1.0 / 3))
        expect(graph.metric("(web)").to_h).to(eq(tc: 3, ca: 0, ce: 2, i: 1.0))
        expect(graph.usage("Billing").keys).to(eq(["(web)", "Order"]))
        expect(graph.violations).to(be_empty)
        expect(graph.domain.map(&:to_s)).to(eq(["Billing -> Order", "Order -> Billing"]))
      end
    end

    it "keeps the layer view under folder packaging" do
      namespaced = "module Admin\n  class OrdersController < ApplicationController\n    def index = Order\n  end\nend\n"
      controllers = { "app/controllers/admin/orders_controller.rb" => namespaced }
      shop(controllers, packaging: :folder) do |_project, census, graph|
        expect(census.packages).not_to(include("(web)"))
        expect(edges(graph)).to(include("controllers -> models"))
      end
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
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(census.packages).to(include("Foo"))
        expect(census.packages).not_to(include("FooPolicy"))
        expect(census.types["Foo"]).to(eq(2))
        expect(graph.edges.map(&:to_s)).to(include("Bar -> Foo"))
      end
    end

    it "folds decorators into their domain, not an app-defined ApplicationDecorator" do
      decorator = ->(name) { "class #{name}Decorator < ApplicationDecorator\n  def x = 1\nend\n" }
      files = Fixtures::RAILS_FILES.merge(
        "app/decorators/application_decorator.rb" => "class ApplicationDecorator\n  def s = 1\nend\n",
        "app/decorators/billing_decorator.rb" => decorator.call("Billing"),
        "app/decorators/user_decorator.rb" => decorator.call("User")
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.packages).not_to(include("BillingDecorator", "UserDecorator"))
        expect(census.folds).to(
          include(
            { from: "BillingDecorator", to: "Billing", via: "suffix" },
            { from: "UserDecorator", to: "User", via: "suffix" }
          )
        )
      end
    end

    it "keeps a class whose superclass matches a nested namesake only by suffix" do
      files = Fixtures::RAILS_FILES.merge(
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
        files = Fixtures::RAILS_FILES.merge(
          Fixtures::NOTIFY_FILES,
          "app/#{folder}/account_notification.rb" => "class AccountNotification\n  def extra = 1\nend\n"
        )
        analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
          expect(census.packages).not_to(include("AccountNotification"))
          expect(census.types["Notification"]).to(eq(3))
        end
      end
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
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(census.folds).to(include({ from: "Orders", to: "Order", via: "plural" }))
        expect(census.types["Order"]).to(eq(2))
        expect(graph.edges.map(&:to_s)).to(include("Shop -> Order"))
        expect(graph.cycles.knots).to(be_empty)
      end
    end

    it "folds -es and -ies plurals too, and keeps a plural with no singular namesake" do
      plural = ->(name) { "module #{name}\n  class Item\n    def i = 1\n  end\nend\n" }
      single = ->(name) { "class #{name}\n  def s = 1\nend\n" }
      files = Fixtures::RAILS_FILES.merge(
        "app/models/box.rb" => single.call("Box"), "app/models/boxes/item.rb" => plural.call("Boxes"),
        "app/models/category.rb" => single.call("Category"),
        "app/models/categories/item.rb" => plural.call("Categories"),
        "app/models/settings/item.rb" => plural.call("Settings")
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, _graph|
        expect(census.folds).to(
          contain_exactly(
            { from: "Boxes", to: "Box", via: "plural" }, { from: "Categories", to: "Category", via: "plural" }
          )
        )
        expect(census.packages).to(include("Settings"))
      end
    end

    it "folds a module that only extends or includes another into the module it adopts" do
      files = Fixtures::RAILS_FILES.merge(
        "app/models/notifier.rb" => "module Notifier\n  def notify = Billing::Invoice\nend\n",
        "app/events/order_shipped.rb" => "module OrderShipped\n  extend ActiveSupport::Concern, Notifier\nend\n",
        "app/events/order_paid.rb" => "module OrderPaid\n  include Notifier\nend\n",
        "app/models/user.rb" => "class User\n  def ship = [OrderShipped, OrderPaid]\nend\n"
      )
      analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
        expect(census.folds).to(
          contain_exactly(
            { from: "OrderPaid", to: "Notifier", via: "mixin" }, { from: "OrderShipped", to: "Notifier", via: "mixin" }
          )
        )
        expect(graph.edges.map(&:to_s)).to(include("User -> Notifier"))
        expect(graph.metric("Notifier").to_h).to(include(ca: 1))
      end
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
