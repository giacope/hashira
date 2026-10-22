# frozen_string_literal: true

RSpec.describe(Hashira::Smells::MessageChain, :aggregate_failures) do
  def chained(body, extra = "")
    sniffed({ "lib/app/shop.rb" => shop(extra), "lib/app/desk.rb" => desk(body) }, "message_chain")
  end

  def shop(extra) = <<~RUBY
    module Shop
      class Address
        def city = "Oslo"
        def to_s = city
      end

      class Customer
        attr_accessor :address
        def customer = self
      end

      class Order
        attr_reader :customer
        def total = 1
      end
      #{extra}
    end
  RUBY

  def desk(body) = <<~RUBY
    module Shop
      class Desk
        attr_reader :order

        def run(order, customer)
          #{body}
        end
      end
    end
  RUBY

  it "flags a call on what an owned object's reader returned, typed by name, with the classes it passed" do
    finding = chained("order.customer.address").first
    expect([finding.package, finding.detail, finding.evidence]).to(
      eq(
        [
          "Shop::Desk#run", { site: "desk.rb:5", through: %w[Order Customer] },
          ["order.customer.address (line 6: Order → Customer)"]
        ]
      )
    )
  end

  it "says which object it reached through and what to do" do
    said = "Shop::Desk#run reaches through Order into Customer (desk.rb:5). " \
      "Ask Order for what you need, or hand the Customer in."
    expect(message(chained("order.customer.address").first)).to(eq(said))
  end

  it "reports the longest chain once, through every owned class it crosses" do
    evidence = chained("order.customer.address.city").first.evidence
    expect(evidence).to(eq(["order.customer.address.city (line 6: Order → Customer → Address)"]))
  end

  it "starts from a parameter, an instance variable, its own reader, or self's reader" do
    bases = [
      "@order.customer.address", "order.customer.address", "self.order.customer.address",
      "customer.address.city"
    ]
    expect(bases.map { chained(it).size }).to(eq([1, 1, 1, 1]))
  end

  it "counts a writer the far class declares" do
    expect(chained("order.customer.address = nil").size).to(eq(1))
  end

  it "leaves alone one hop, a hop with arguments or a block, and a message the far class does not declare" do
    bodies = [
      "order.customer", "order.total(1).customer.address", "order.customer { 1 }.address",
      "order.customer.name"
    ]
    expect(bodies.map { chained(it) }).to(all(be_empty))
  end

  it "leaves alone a reader the near class does not declare, and an untyped or library base" do
    bodies = ["order.client.address", "node.customer.address", "Order.customer.address", "order.customer(1).address"]
    expect(bodies.map { chained(it) }).to(all(be_empty))
  end

  it "leaves alone a fluent hop back to the same class, and messages every object answers" do
    expect([chained("customer.customer.address"), chained("order.customer.address.to_s")].map(&:size)).to(eq([0, 1]))
  end

  it "leaves alone a reader that returns a Struct or Data value" do
    values = ["Point = Data.define(:x) do", "Point = Struct.new(:x) do", "class Point < Data.define(:x)", "class Point"]
    reader = "\n    def label = 1\n  end\n  class Order\n    attr_reader :point\n  end"
    expect(values.map { chained("order.point.label", "#{it}#{reader}").size }).to(eq([0, 0, 0, 1]))
  end
end
