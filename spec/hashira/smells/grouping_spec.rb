# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Grouping) do
  def grouped(files, kind)
    within(files) do
      rules = Hashira::Config::Rules.parse({ kind => true }, Hashira::Pipeline::KINDS)
      return Hashira::Pipeline.new(Hashira::Project.new(["lib/app"], rules:)).findings.select { it.kind == kind }
    end
  end

  def shop = <<~RUBY
    module Shop
      class Address; def city = 1; end
      class Customer; attr_reader :address; end
      class Order; attr_reader :customer; end
    end
  RUBY

  def desk(name) = <<~RUBY
    module Shop
      class #{name}
        def run(order) = order.customer.address
        def go(order) = order.customer.address.city
      end
    end
  RUBY

  def desks = { "lib/app/shop.rb" => shop, "lib/app/desk.rb" => desk("Desk"), "lib/app/till.rb" => desk("Till") }

  def chain = grouped(desks, "message_chain").first

  it "reports one message chain per class edge, with each method that reaches through it" do
    sites = ["Shop::Desk#run (desk.rb:3)", "Shop::Desk#go (desk.rb:4)", "Shop::Till#run (till.rb:3)"]
    expect([chain.package, chain.detail[:places], chain.evidence.first(3)]).to(eq(["Order → Customer", 4, sites]))
  end

  it "says how many methods reach through the edge and what to do" do
    said = "Order → Customer — 4 methods reach through Order into Customer (desk.rb:3). " \
      "Ask Order for what you need, or hand the Customer in."
    expect(message(chain)).to(eq(said))
  end

  it "says a lone method reaches through the edge" do
    files = { "lib/app/shop.rb" => shop, "lib/app/desk.rb" => desk("Desk").sub(/^.*def go.*\n/, "") }
    said = "Order → Customer — 1 method reaches through Order into Customer"
    expect(message(grouped(files, "message_chain").first)).to(start_with(said))
  end

  def account = <<~RUBY
    module Shop
      class Account
        def initialize = @owner = nil
        def name = @owner.nil? ? "none" : @owner
        def mail = @owner.nil? ? "none" : @owner
        def total(rows)
          sum = nil
          sum.nil? ? rows : sum
        end
        def self.default = nil
        def self.pick = default.nil? ? "x" : default
        private
        def current = nil
        def label = current.nil? ? "x" : current
      end
    end
  RUBY

  def nils = grouped({ "lib/app/account.rb" => account }, "nil_check").to_h { [it.package, it] }

  it "reports one nil check per nil the class makes, and keeps a local's check on its method" do
    expect(nils.keys).to(
      contain_exactly("Shop::Account#total", "Shop::Account@owner", "Shop::Account#current", "Shop::Account.default")
    )
  end

  it "lists the methods that check a nil, and says to settle it where it is made" do
    owner = nils["Shop::Account@owner"]
    said = "Shop::Account@owner may be nil, and 2 methods check for it (account.rb:4). " \
      "Prefer a default, a null object, or polymorphism. Settle it where the nil is made."
    sites = ["Shop::Account#name (account.rb:4)", "Shop::Account#mail (account.rb:5)"]
    expect([owner.evidence, message(owner)]).to(eq([sites, said]))
  end

  def repeats = grouped({ "lib/app/till.rb" => counter }, "repeated_call").to_h { [it.package, it] }

  def counter
    <<~RUBY
      module Shop
        class Till
          def ring(io) = [io.tick(1), io.tick(1)]
          def open(io) = [io.tick(2), io.tick(2), io.read(3), io.read(3)]
          def self.boot(io) = [io.tick(4), io.tick(4)]
        end

        class Desk
          def ring(io) = [io.tick(1), io.tick(1)]
        end

        class Shelf
          def count(io) = [io.size, io.size, io.size]
        end
      end
    RUBY
  end

  it "reports one repeated-call finding per class, doubted only when every repeat in it is" do
    expect([repeats.keys.sort, repeats.values.select(&:doubted?).map(&:package)])
      .to(eq([%w[Shop::Desk Shop::Shelf Shop::Till], %w[Shop::Shelf]]))
  end

  it "lists each method's repeated calls as evidence and counts calls and methods" do
    till = repeats["Shop::Till"]
    said = "Shop::Till repeats 4 calls in 3 methods (till.rb:3). Name the result in a local variable."
    expect([till.evidence.first(2), message(till), message(repeats["Shop::Desk"])]).to(
      eq(
        [
          ["#ring: io.tick(1) × 2 (line 3)", "#open: io.tick(2) × 2 (line 4)"], said,
          "Shop::Desk repeats 1 call in 1 method (till.rb:9). Name the result in a local variable."
        ]
      )
    )
  end

  it "speaks of one checking method in the singular" do
    expect(message(nils["Shop::Account#current"])).to(include("may be nil, and 1 method checks for it"))
  end
end
