# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Repertoire, :aggregate_failures) do
  def answers(source, *segments) = described_class.new([Prism.parse(source).value]).of(segments).to_a.sort

  it "knows what a class declares: methods, readers, macros' names and aliases, never its singleton methods" do
    source = <<~RUBY
      class Order
        attr_accessor :total
        has_many :lines
        private def seal = 1
        alias tag seal
        def self.build = new
        class << self
          def made = new
        end
        Rails.logger.tap(:noise)
        included { def hooked = 1 }
      end
    RUBY
    expect(answers(source, "Order")).to(eq(%w[hooked lines seal tag total]))
  end

  it "adds what owned superclasses and mixins declare, under any suffix of their name, and survives a loop" do
    source = <<~RUBY
      module Shop
        module Priced
          def price = 1
        end

        class Base
          def id = 1
        end

        class Order < Base
          include Priced
        end

        class Loop < Loop
        end
      end
    RUBY
    expect([%w[Shop Order], %w[Order], %w[Loop]].map { answers(source, *it) }).to(eq([%w[id price], %w[id price], []]))
  end

  it "answers for the class at the path it is asked about, not for a same-named class in another namespace" do
    source = <<~RUBY
      class Taxon
        attr_accessor :title
      end

      module Tree
        class Taxon
          attr_reader :name
        end
      end
    RUBY
    expect([%w[Taxon], %w[Tree Taxon]].map { answers(source, *it) }).to(eq([%w[title], %w[name]]))
  end

  it "reads the members and block methods of Struct, Data and Class.new constants" do
    source = <<~RUBY
      module Shop
        Point = Struct.new(:x, :y)
        Line = Data.define(:from) do
          def length = 1
        end
        Bare = Data.define(:to) {}
        Boom = Class.new(Point) { def code = 1 }
        Plain = 1
        Empty = Class.new
        Made = build(:x)
      end
    RUBY
    expected = [%w[x y], %w[from length], %w[to], %w[code x y], [], [], []]
    expect(%w[Point Line Bare Boom Plain Empty Made].map { answers(source, it) }).to(eq(expected))
  end
end
