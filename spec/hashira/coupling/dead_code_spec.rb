# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::DeadCode) do
  def shop
    <<~RUBY
      module App
        class Shop
          LIMIT = 3
          UNUSED = 4
          SECRET = 5
          private_constant :SECRET

          def self.open = new.total
          def total = LIMIT + helper
          def stale = 1
          def call = 1
          def to_s = "shop"
          def written=(value) = @written = value
          def outside_only = 1
          def on_paid = 1
          def pinged = :pong
          def quoted = 1
          def setter_seen = 1
          def memo = @memo
          def ping_all = send("pinged")

          private

          def upcase = 1
          def helper = 1
          def unused_helper = 2
          def marked = 3
          private :marked
        end
      end
    RUBY
  end

  def user
    <<~RUBY
      module App
        class User
          def notify(shop, event) = shop.public_send("on_\#{event}")

          def buy(shop)
            shop.written = 1
            [method(:pinged), "quoted", shop.setter_seen, shop.memo ||= 1]
          end
        end

        class Orphan
          NESTED = 1
        end
      end
    RUBY
  end

  def files = { "lib/app/shop.rb" => shop, "lib/app/user.rb" => user, "spec/shop_spec.rb" => "it { outside_only }\n" }

  def dead(tree = files, roots: nil, directories: ["lib/app"])
    within(tree) do
      raw = { "dead_code" => roots ? { "roots" => roots } : true }
      project = Hashira::Project.new(directories, rules: Hashira::Config::Rules.parse(raw, Hashira::Pipeline::KINDS))
      return Hashira::Pipeline.new(project).findings.select { it.kind == "dead_code" }.map(&:package)
    end
  end

  it "reports only private methods and private constants of a library, whose public surface is its users' API" do
    expect(dead).to(eq(%w[App::Shop::SECRET App::Shop#unused_helper App::Shop#marked]))
  end

  it "reports the public code nothing calls once roots name the API, whatever calls it by name, symbol or string" do
    expect(dead(roots: ["App::User"])).to(
      eq(
        %w[
          App::Shop::UNUSED App::Shop::SECRET App::Shop.open App::Shop#stale App::Shop#ping_all App::Shop#unused_helper
          App::Shop#marked App::Orphan
        ]
      )
    )
  end

  it "says what is never used and what to do" do
    said = %w[App::Shop#stale App::Orphan].map { |name| message(finding(name)) }
    expect(said).to(
      eq(
        [
          "App::Shop#stale is never called in the project (shop.rb:10). Delete it, or name it in dead_code roots if " \
            "code outside the project uses it.",
          "App::Orphan is never referred to in the project (user.rb:11). Delete it, or name it in dead_code roots if " \
            "code outside the project uses it."
        ]
      )
    )
  end

  def finding(name)
    within(files) do
      rules = Hashira::Config::Rules.parse({ "dead_code" => { "roots" => ["App::User"] } }, Hashira::Pipeline::KINDS)
      return Hashira::Pipeline.new(Hashira::Project.new(["lib/app"], rules:)).findings.find { it.package == name }
    end
  end

  def rails
    {
      "config/application.rb" => "module Shop\n  class Application < Rails::Application\n  end\nend\n",
      "app/models/application_record.rb" => "class ApplicationRecord < ActiveRecord::Base\nend\n",
      "app/models/order.rb" => <<~RUBY,
        class Order < ApplicationRecord
          include Totals
          include Searchable
          def to_label = "order"
          private
          def stale_scope = 1
        end
      RUBY
      "app/models/totals.rb" => "module Totals\n  def grand_total = 1\nend\n",
      "app/models/concerns/searchable.rb" => "module Searchable\n  module ClassMethods; def search_all = 1; end\nend",
      "app/controllers/orders_controller.rb" =>
        "class OrdersController\n  include Paging\n  def index = Order\nend\n",
      "lib/paging.rb" => "module Paging\n  def page_size = 25\nend\n",
      "lib/pricing.rb" => "class Pricing\n  def quote = 1\n  def self.rate = 2\nend\n",
      "app/views/orders/index.html.erb" => "<%= order.to_label %>\n"
    }
  end

  it "takes the framework's entry points and the classes it hosts for roots in a Rails app" do
    expect(dead(rails, directories: %w[app lib])).to(eq(%w[Order#stale_scope Pricing Pricing#quote Pricing.rate]))
  end

  it "leaves a class the project reopens to its owner, Ruby or a library, and still judges the methods it adds" do
    reopened = rails.merge(
      "lib/rails_ext/string.rb" => "class String\n  def shout = upcase\n  def whisper = downcase\nend\n",
      "lib/rails_ext/filters.rb" => "class ActionText::Content::Filters\n  def initialize(*all) = @all = all\nend\n",
      "app/helpers/notes_helper.rb" =>
        "module NotesHelper\n  FILTERS = ActionText::Content::Filters.new\n  def loud(text) = text.shout\nend\n"
    )
    expect(dead(reopened, directories: %w[app lib])).to(
      eq(%w[Order#stale_scope Pricing Pricing#quote Pricing.rate String#whisper])
    )
  end

  it "reads a ::-rooted class inside a module as the top-level class it reopens, not a nested one" do
    rooted = rails.merge(
      "app/models/drops.rb" => <<~RUBY
        module Drops
          class ::MatchData
            def to_liquid = :drop
          end

          class ::ActiveRecord::Relation
            def to_liquid = :relation
          end

          def self.wrap(match) = match.to_liquid
        end
      RUBY
    )
    expect(dead(rooted, directories: %w[app lib]))
      .to(eq(%w[Drops Drops.wrap Order#stale_scope Pricing Pricing#quote Pricing.rate]))
  end

  it "counts a constant read through a module that includes its owner as used, and that module too" do
    included = rails.merge(
      "app/models/keys.rb" => "module Keys\n  MUTEX = 1\n  STALE = 2\nend\n",
      "app/models/store.rb" => "module Store\n  include Keys\nend\n",
      "app/models/job.rb" => "class Job < ApplicationRecord\n  def key = Store::MUTEX\nend\n"
    )
    expect(dead(included, directories: %w[app lib]))
      .to(eq(%w[Keys::STALE Order#stale_scope Pricing Pricing#quote Pricing.rate]))
  end

  it "adds the roots a Rails app names to the framework's" do
    expect(dead(rails, roots: %w[lib/pricing.rb], directories: %w[app lib])).to(eq(%w[Order#stale_scope]))
  end

  def reach
    <<~RUBY
      module App
        class Rule
          def self.inherited(kind) = kinds << kind
        end

        class Loud < Rule; end
        class Mid < Rule; end
        class Leaf < Mid; end
        class Base2; end
        class Child2 < Base2; end
        class Ext < ::Plugin; end
        class Plugin; end

        module Ping
          include Pong
          def ping_unused = 1
        end

        module Pong
          include Ping
        end

        module Tools
          def tool_unused = 1
        end

        class Host < ActiveRecord::Base
          include factory::Tools
        end

        class Widget
          register Plugins::Thing
          def widget_unused = 1
        end
        class Check; end
        class Plain < Check; end
        class Rooted < ::App::Check; end

        class Base < Struct.new(:a)
          def refill = super
        end

        module Helpers
          module ClassMethods
            def finder = 1
          end
        end

        class Router
          def route(name) = send(name)
          def go_home = 1
        end

        module Mix; end
        class Top; include Mix; end
        class Low < Top; include Mix; end

        class Kept
          include Comparable
          def keep_me = 1
          def drop_me = 1
        end
      end
    RUBY
  end

  def runner = "module App\n  class Run\n    def go(shop) = [#{calls}]\n  end\nend\n"

  def calls = "Check.subclasses, Base2.new, \"\#{shop}_x\", shop.count ||= 1"

  def plugin = "class Plugin\n  def self.inherited(kind) = kind\nend\n"

  def reaching
    { "lib/app/reach.rb" => reach, "lib/app/run.rb" => runner, "lib/app/plugin.rb" => plugin }
      .merge("lib/app/legacy/loose.rb" => "class Loose; def x = 1; end\n")
  end

  it "keeps what a registry, an override, a dynamic send or a declared root reaches" do
    roots = ["App::Run", "App::Kept#keep_me", "lib/app/legacy"]
    expect(dead(reaching, roots:)).to(
      eq(
        %w[
          App::Child2 App::Plugin App::Ping#ping_unused App::Tools App::Tools#tool_unused App::Widget
          App::Widget#widget_unused App::Base App::Helpers
          App::Helpers.finder App::Router App::Low App::Kept App::Kept#drop_me
        ]
      )
    )
  end
end
