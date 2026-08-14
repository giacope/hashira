# frozen_string_literal: true

RSpec.describe(Hashira::CLI) do
  it "prints every line the headline example shows, in the order shown" do
    shown = readme[/```console\n\$ hashira app\n(.*?)^```/m, 1].lines(chomp: true).reject(&:empty?)
    printed = within(tangled) { capture { described_class.new(["app"]).status } }.lines(chomp: true)
    cursor = -1
    shown.each do |line|
      offset = printed[(cursor + 1)..].index(line)
      expect(offset).to(be_an(Integer), "README shows a line hashira does not print (or not in this order): #{line}")
      cursor += offset + 1
    end
  end

  it "reports the healthy-project line the README promises" do
    promised = readme[/A healthy project reports `([^`]+)`/, 1]
    printed = within(healthy) { capture { described_class.new(["app"]).status } }
    expect(printed.gsub(/\s+/, " ")).to(include(promised.gsub(/\s+/, " ")))
  end

  def readme = File.read("#{__dir__}/../README.md")

  def tangled = { "app/billing/client.rb" => client, "app/shipping/rate.rb" => rate }

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
end
