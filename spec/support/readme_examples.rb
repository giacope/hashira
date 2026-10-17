# frozen_string_literal: true

module ReadmeExamples
  module_function

  def files(name) = public_send(name)

  def cycle = { "app/billing/client.rb" => client, "app/shipping/rate.rb" => rate }

  def healthy = { "app/billing/client.rb" => settled, "app/shipping/rate.rb" => rate }

  def client
    <<~RUBY
      module Billing
        class Client
          def initialize(order) = @order = order

          def rate = Shipping::Rate.new(@order)
        end
      end
    RUBY
  end

  def rate
    <<~RUBY
      module Shipping
        class Rate
          def initialize(order)
            @order = order
            @distance = order.distance
          end

          def bill = Billing::Client.new(@order)

          def express? = @distance > 100
        end
      end
    RUBY
  end

  def settled
    <<~RUBY
      module Billing
        class Client
          def initialize(order) = @order = order

          def total = @order.total
        end
      end
    RUBY
  end

  def rails
    {
      "config/application.rb" => "module Shop\n  class Application < Rails::Application\n  end\nend\n",
      "app/models/application_record.rb" => "class ApplicationRecord < ActiveRecord::Base\nend\n",
      "app/models/user.rb" => user,
      "app/models/billing/invoice.rb" => invoice,
      "app/controllers/invoices_controller.rb" => controller
    }
  end

  def user
    <<~RUBY
      class User < ApplicationRecord
        has_many :invoices, class_name: "Billing::Invoice"

        def plan = :free
      end
    RUBY
  end

  def invoice
    <<~RUBY
      module Billing
        class Invoice < ApplicationRecord
          belongs_to :user

          def total = 1
        end
      end
    RUBY
  end

  def controller = "class InvoicesController < ApplicationController\n  def show = Billing::Invoice.find(1)\nend\n"

  def complexity = { "lib/shop/pricing.rb" => pricing }

  def suppressed = { "lib/shop/pricing.rb" => pricing.sub("    def total", "    #{directive}\n    def total") }

  def directive = "# hashira:disable-next-line complexity -- legacy rules, rewrite scheduled"

  def pricing
    <<~RUBY
      module Shop
        class Pricing
          def total(order)
            if order.items.any?
              if order.coupon
                if order.coupon.expired?
                  order.subtotal
                elsif order.member?
                  order.subtotal * 0.8
                else
                  order.subtotal * 0.9
                end
              end
            elsif order.gift? && (order.wrapped? || order.boxed?)
              0
            end
          end
        end
      end
    RUBY
  end

  def layers
    {
      ".hashira.yml" => "layers: [web, billing, core]\n",
      "app/web/invoices_page.rb" => "module Web\n  class InvoicesPage\n    def rows = Billing::Ledger\n  end\nend\n",
      "app/billing/ledger.rb" => ledger,
      "app/core/money.rb" => "module Core\n  class Money\n    def self.zero = 0\n  end\nend\n"
    }
  end

  def ledger
    <<~RUBY
      module Billing
        class Ledger
          def entries = Core::Money.zero

          def link = Web::InvoicesPage.name
        end
      end
    RUBY
  end

  def dead = { "lib/app/invoice.rb" => legacy }

  def legacy
    <<~RUBY
      class Invoice
        def total = lines.sum

        private

        def lines = [1, 2]

        def legacy_total = lines.sum * 1.2
      end
    RUBY
  end

  def fragmentation = { "lib/app/report.rb" => scattered }

  def scattered
    <<~RUBY
      class Report
        def initialize(rows) = @rows = rows

        def render = [title, body].join("\\n")

        private

        def title = "\#{label}: \#{count}"

        def label = name.upcase

        def name = "report"

        def count = @rows.size

        def body = lines.join("\\n")

        def lines = @rows.map { line(it) }

        def line(row) = "\#{row.name} \#{row.total}"
      end
    RUBY
  end

  def indirection = { "lib/app/importer.rb" => importer }

  def importer
    <<~RUBY
      class Importer
        def initialize(store) = @store = store

        def run(rows) = import(rows)

        private

        def import(rows) = persist(rows.compact)

        def persist(rows) = write(rows)

        def write(rows)
          rows.each { |row| row[:id] ? @store.put(row) : @store.skip(row) }
        rescue IOError
          @store.rollback
        end
      end
    RUBY
  end

  def duplication = %w[orders payouts refunds].to_h { ["app/reports/#{it}.rb", report(it)] }

  def report(name)
    <<~RUBY
      class #{name.capitalize}Report
        def initialize(scope) = @scope = scope

        def rows
          @scope.where(state: "#{name}_settled").order(created_at: :desc).limit(500).map do |record|
            [record.id, record.amount.round(2), record.created_at.strftime("%Y-%m-%d"), "#{name}"]
          end
        end
      end
    RUBY
  end

  def smells = { "lib/app/cart.rb" => cart, "lib/app/item.rb" => item, "lib/app/checkout.rb" => checkout }

  def cart
    <<~RUBY
      class Cart
        def initialize(rate, io)
          @rate = rate
          @io = io
        end

        def price(item) = (item.base + item.tax) * item.quantity * @rate

        def print(quoted) = quoted ? @io.write("'cart'") : @io.write("cart")
      end
    RUBY
  end

  def item = "class Item\n  attr_reader :base, :tax, :quantity\nend\n"

  def checkout = "class Checkout\n  def initialize(cart) = @cart = cart\n\n  def run = @cart.print(true)\nend\n"

  def ratchet
    complexity.merge(
      "hashira_baseline.json" => <<~JSON
        {"version": 7, "packaging": "folder", "analyzers": ["coupling", "complexity", "duplication", "smells"],
         "targets": ["lib/shop"], "edges": [],
         "findings": {"complexity:Shop::Pricing#total": 9, "utility_function:Shop::Pricing#total": null}}
      JSON
    )
  end

  def fresh
    duplication.merge(
      "hashira_baseline.json" => <<~JSON
        {"version": 7, "packaging": "folder", "analyzers": ["coupling", "complexity", "duplication", "smells"],
         "targets": ["app"], "edges": [], "findings": {}}
      JSON
    )
  end
end
