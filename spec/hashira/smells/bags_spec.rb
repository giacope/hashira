# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Bags, :aggregate_failures) do
  def bagged(files) = sniffed(files, "data_class")

  def invoice(body) = <<~RUBY
    module Shop
      class Invoice
        def initialize(order, address) = (@order = order; @address = address)

        #{body}
      end
    end
  RUBY

  def shop = <<~RUBY
    module Shop
      Address = Struct.new(:street, :city, :zip)
      Point = Data.define(:left, :top)
      Blank = Data.define

      class ApplicationRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      class Order < ApplicationRecord
        belongs_to :customer
        scope :recent, -> { order(:id) }
      end
    end
  RUBY

  def found(body) = bagged("lib/app/shop.rb" => shop, "lib/app/invoice.rb" => invoice(body))

  it "flags a Struct value and a behaviorless record whose readers another class combines" do
    body = "def total = (@order.quantity * @order.unit_cents) + @order.shipping_cents\n  " \
      "def label = \"\#{@address.street}, \#{@address.zip} \#{@address.city}\""
    findings = found(body)
    expect(findings.to_h { [it.package, [it.detail[:fields], it.evidence]] }).to(
      eq(
        "Shop::Address" => [%w[street zip city], ["Shop::Invoice#label reads 'street', 'zip', 'city' (invoice.rb:6)"]],
        "Shop::Order" => [
          %w[quantity unit_cents shipping_cents],
          ["Shop::Invoice#total reads 'quantity', 'unit_cents', 'shipping_cents' (invoice.rb:5)"]
        ]
      )
    )
  end

  it "says the fields live away from the code that computes with them" do
    said = "Shop::Address holds 'street', 'city' and does nothing else, while 1 method elsewhere computes with " \
      "them (shop.rb:2). Move that code into the class, so the data and what it means live together."
    expect(message(found("def label(address) = address.street + address.city").first)).to(eq(said))
  end

  it "counts every method that computes with the value" do
    finding = found("def label = @address.street + @address.city\n  def code = @address.zip + @address.city").first
    expect(message(finding)).to(include("while 2 methods elsewhere compute with them"))
  end

  it "needs two readers of one object in one method, and leaves its persistence and universal messages out" do
    bodies = [
      "def label = @address.street", "def total = @order.save && @order.id && @order.to_s",
      "def label = [@address.street, other.city]", "def copy = Address.new(@address.street, @address.city)"
    ]
    expect(bodies.map { found(it) }).to(all(be_empty))
  end

  it "leaves a value with behavior, a record with behavior or callbacks, and a record nested in its reader alone" do
    shop = <<~RUBY
      module Shop
        Address = Struct.new(:street, :city) do
          def line = "\#{street}, \#{city}"
        end

        class Order < ActiveRecord::Base
          before_save :stamp
        end

        class Invoice
          Line = Data.define(:price, :count)

          def total(line) = line.price * line.count

          def label(address) = address.street + address.city

          def sum(order) = order.quantity * order.unit_cents
        end
      end
    RUBY
    expect(bagged("lib/app/shop.rb" => shop)).to(be_empty)
  end

  it "flags a class built on a bare Struct, and leaves the hand-written data class to its own rule" do
    shop = "module Shop\n  class Size < Struct.new(:width, :height)\n  end\nend\n"
    reader = "module Shop\n  class Box\n    def area(size) = size.width * size.height\n  end\nend\n"
    expect(bagged("lib/app/shop.rb" => shop, "lib/app/box.rb" => reader).map(&:package)).to(eq(["Shop::Size"]))
  end
end
