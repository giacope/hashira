# frozen_string_literal: true

RSpec.describe(Hashira::Smells::FeatureEnvy) do
  def lexicon
    <<~RUBY
      module App
        module Zone
          class Lexicon
            attr_accessor :net, :tax, :fee, :load, :store, :sync, :name, :receiver, :arguments, :predicate,
                          :unescaped, :id, :size, :kind, :message, :backtrace, :cause, :trim, :sort, :pack,
                          :warm, :serve, :chomp, :strip, :merge, :delete, :fetch, :push
          end
        end
      end
    RUBY
  end

  def envy(source) = sniffed({ "lib/app/zone/thing.rb" => source, "lib/app/zone/words.rb" => lexicon }, "feature_envy")

  def said = "more than to self, 2 to 1 (zone/thing.rb:4). The behavior may belong on order."

  it "flags a method that talks to a parameter more than to self" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def total(order)
              @rate * order.net + order.tax
            end
          end
        end
      end
    RUBY
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(finding.package).to(eq("App::Zone::Thing#total"))
    expect(message(finding)).to(eq("#{finding.package} refers to 'order' #{said}"))
    expect(finding.evidence).to(eq(["order (line 5)", "self (line 5)"]))
  end

  it "does not read compound assignments as envy of the assigned name" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def bump(count)
              count += 1
              count += 2
              @log.push(count)
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "lists every equally envied receiver with plural line evidence" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def sync(left, right)
              @seen = true
              left.load
              left.store
              right.load
              right.store
            end
          end
        end
      end
    RUBY
    expect(message(findings.first)).to(
      include("'left', 'right' more than to self, 2 each to 1", "may belong on whichever of them it serves")
    )
    expect(findings.first.evidence).to(eq(["left (lines 6, 7)", "right (lines 8, 9)", "self (line 5)"]))
  end

  it "stays quiet when self is referenced at least as often" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def total(order)
              @rate * order.net + @fee
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "skips singleton methods, module functions, and methods with no self reference" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def self.build(order)
              order.net + order.tax + order.fee
            end
          end

          module Sniff
            module_function

            def scan(order)
              probe
              order.net + order.tax
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "counts self, super, and explicit self receivers as self references" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def meld(other)
              super
              self.merge(self)
              other.merge(other.load)
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "does not count constructor calls against the receiver" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def spawn(seed)
              @made = [seed.new, seed.new]
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "stays quiet about a name type-guarded against constants the codebase does not define" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def variants(node)
              return unless node.is_a?(Prism::CallNode)
              @seen = true
              node.name && node.receiver && node.arguments
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags a name guarded against a class the codebase defines, even by suffix" do
    findings = sniffed(
      {
        "lib/app/zone/thing.rb" => <<~RUBY,
          module App
            module Zone
              class Thing
                def widen(part)
                  return unless part.is_a?(Zone::Widget)
                  @seen = true
                  part.load && part.store && part.sync
                end
              end
            end
          end
        RUBY
        "lib/app/zone/widget.rb" => <<~RUBY,
          module App
            module Zone
              class Widget
              end
            end
          end
        RUBY
        "lib/app/zone/lexicon.rb" => lexicon
      },
      "feature_envy"
    )
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#widen"]))
  end

  it "reads case/when type dispatch as a guard too" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def visit(node)
              @seen = true
              case node
              when Prism::IfNode then node.predicate
              when Prism::CallNode then node.name && node.receiver
              end
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "stays quiet about wire data read only through literal keys" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def build(msg)
              @count += 1
              record(msg["id"], msg.fetch("status"), msg[:ms], msg["fails"])
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags hash-like access once a key is computed or the name is reassigned" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def pick(row, keys)
              @seen = true
              row.fetch(keys.first) && row.fetch("kind") && row.fetch("name")
            end

            def bump(tally)
              tally += 1
              @log.push(tally.fetch("a"), tally.fetch("b"))
            end

            def scoop(bag)
              @seen = true
              bag.fetch && bag.fetch("kind") && bag.fetch("name")
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#pick", "App::Zone::Thing#bump", "App::Zone::Thing#scoop"]))
  end

  it "counts an explicit self receiver once" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def total(order)
              self.rate * order.net + order.tax
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["order (line 5)", "self (line 5)"]))
  end

  it "still flags a name when the guard or lookup is about something else" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            TABLE = { Prism::CallNode => :call }.freeze

            def price(item, other)
              return 0 if other.is_a?(Prism::CallNode)
              @rate * item.net + item.tax
            end

            def label(item)
              @rate * item.net + item.tax + TABLE[:call].size
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#price", "App::Zone::Thing#label"]))
  end

  it "still flags an exception rescued from an error class defined as a constant" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          Boom = Class.new(StandardError)

          class Thing
            def guard
              @tries += 1
              risky
            rescue Zone::Boom => e
              e.message && e.backtrace && e.cause
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#guard"]))
  end

  it "stays quiet about a stateless converter that ends by building a typed object" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def from_row(row)
              Result.new(id: checksum(row.id), name: row.name, size: row.size, kind: row.kind)
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags a constructor tail once the method touches instance state" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def absorb(row)
              @last = row.id
              Result.new(id: row.id, name: row.name, size: row.size)
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#absorb"]))
  end

  it "stays quiet about a structure the method itself builds from a literal" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def defaults(argv)
              options = { framework: "rspec", jobs: 1 }
              @seen = true
              options.merge!(scan(argv))
              options.delete(:tmp)
              options.delete(:cache)
              options.freeze
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags a name loaded from elsewhere and leaned on" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def sweep
              list = load
              @seen = true
              list.sort && list.trim && list.pack
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#sweep"]))
  end

  it "reads values_at and dig with literal keys as wire access" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def anchor(rule)
              @seen = true
              rule.values_at(:file, :line) && rule.dig("meta", "label") && rule[:label]
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "treats a value derived from a foreign name or constant as foreign too" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def label(node)
              return unless node.is_a?(Prism::StringNode)
              value = node.unescaped
              @seen = true
              value.inspect && value.chomp && value.strip
            end

            def boot
              app = Rails.application
              @seen = true
              app.load && app.warm && app.serve
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags a value built by a class the codebase defines" do
    findings = sniffed(
      {
        "lib/app/zone/thing.rb" => <<~RUBY,
          module App
            module Zone
              class Thing
                def wield
                  part = Widget.build
                  @seen = true
                  part.load && part.store && part.sync
                end
              end
            end
          end
        RUBY
        "lib/app/zone/widget.rb" => <<~RUBY,
          module App
            module Zone
              class Widget
              end
            end
          end
        RUBY
        "lib/app/zone/lexicon.rb" => lexicon
      },
      "feature_envy"
    )
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#wield"]))
  end

  it "stays quiet about an exception rescued from foreign or implied classes" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def guard
              @tries += 1
              risky
            rescue ArgumentError
              retry
            rescue => e
              e.message && e.backtrace && e.cause
            end

            def relay
              @tries += 1
              risky
            rescue IOError => e
              e.message && e.backtrace && e.cause
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags an exception rescued from a class the codebase defines" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Boom < StandardError
          end

          class Thing
            def guard
              @tries += 1
              risky
            rescue Zone::Boom => e
              e.message && e.backtrace && e.cause
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#guard"]))
  end

  it "reads dispatch through a table keyed by foreign classes as a guard" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            LABEL = "thing"
            TABLE = { Prism::CallNode => :call, Prism::IfNode => :branch }.freeze

            def pick(node)
              @seen = true
              TABLE[node.class] && node.name && node.receiver
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "reads dispatch through a table's fetch keyed by foreign classes as a guard" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            LABEL = "thing"
            TABLE = { Prism::CallNode => :call, Prism::IfNode => :branch }.freeze

            def pick(node)
              @seen = true
              TABLE.fetch(node.class, nil) && node.name && node.receiver
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "keeps flagging when the table's keys are owned, mixed, absent, or not a table at all" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Local
          end

          class Thing
            OWNED = { Local => :one }
            BLANK = {}.freeze
            LOOSE = { "plain" => :two }.freeze
            MIXED = { **LOOSE, Prism::IfNode => :if }.freeze
            LIST = [1].freeze

            def near(node)
              @seen = true
              OWNED[node.class] && node.load && node.store
            end

            def blank(node)
              @seen = true
              BLANK[node.class] && node.load && node.store
            end

            def loose(node)
              @seen = true
              LOOSE[node.class] && node.load && node.store
            end

            def flat(node)
              @seen = true
              LIST[node.class] && node.load && node.store
            end

            def spread(node)
              @seen = true
              MIXED[node.class] && node.load && node.store
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(
        [
          "App::Zone::Thing#near", "App::Zone::Thing#blank",
          "App::Zone::Thing#loose", "App::Zone::Thing#flat", "App::Zone::Thing#spread"
      ]
      )
    )
  end

  it "counts only messages the codebase itself defines, never operators or what every object answers" do
    parcel = <<~RUBY
      module App
        module Zone
          Pair = Data.define(:left, :right)

          class Parcel
            has_many :lines
            attr_reader :label
            alias tag label

            def pack = send(:ghost)

            def to_s = "parcel"

            def [](key) = key

            def +(other) = other

            private

            def seal = 1

            def hush = 1
          end

          class Box
            def hush = 2
          end
        end
      end
    RUBY
    thing = <<~RUBY
      module App
        module Zone
          class Thing
            def ship(order)
              @seen = true
              stamp
              order.to_s && order[:id] && (order + order) && order.frobnicate
              order.ghost && order.ghost(1) && order.ghost(2)
            end

            def wrap(order)
              @seen = true
              stamp
              order.seal && order.seal(1) && order.seal(2)
            end

            def muffle(order)
              @seen = true
              stamp
              order.hush && order.hush(1) && order.hush(2)
            end

            def bundle(order)
              @seen = true
              order.pack
              order.lines
              order.tag
              order.label = 1
              order.left
            end
          end
        end
      end
    RUBY
    findings = sniffed({ "lib/app/zone/thing.rb" => thing, "lib/app/zone/parcel.rb" => parcel }, "feature_envy")
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#muffle App::Zone::Thing#bundle]))
    expect(findings.last.evidence).to(eq(["order (lines 25, 26, 27, 28, 29)", "self (line 24)"]))
  end

  it "keeps apart block variables that merely share a name, and follows outer names into blocks" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def tidy(rows)
              @seen = true
              stamp
              rows.each { |r| r.load }
              rows.each { |r| r.store }
              rows.each { |r| r.sync }
            end

            def fill(order)
              @seen = true
              [1].each { order.load }
              [2].each { [3].each { order.store } }
              -> { order.sync }
            end

            def nest(order)
              @seen = true
              stamp
              order.load
              def helper(order) = order.load && order.store && order.sync
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#fill"]))
    expect(findings.first.evidence).to(eq(["order (lines 14, 15, 16)", "self (line 13)"]))
  end

  it "treats what a foreign constructor or chain yields to its block as foreign" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def connection
              @connection ||= Faraday.new(url) do |f|
                f.load
                f.store
                f.sync
              end
            end

            def boot
              @seen = true
              Rails.application.tap { |app| app.warm && app.serve }
            end

          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags what an owned constructor yields, and locals the block binds itself" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Widget
          end

          class Thing
            def forge
              @seen = true
              Widget.new { |w| w.load && w.store }
            end

            def wire
              @seen = true
              Faraday.new do |f|
                part = Widget.build
                part.load && part.store && f
              end
            end

            def weld
              @seen = true
              Faraday.new do
                part = Widget.build
                part.load && part.store
              end
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#forge App::Zone::Thing#wire App::Zone::Thing#weld]))
  end

  it "sees block parameters referenced together, as in a comparator, as peers rather than a destination" do
    findings = envy(<<~RUBY)
      module App
        module Zone
          class Thing
            def ranked
              @items.sort { |a, b| a.load <=> b.load && a.store <=> b.store }
            end

            def ranks(left, right)
              @seen = true
              left.load <=> right.load && left.store <=> right.store
            end

            def grouped
              @items.each_slice(2).map { |pair| pair.load && pair.store }
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#ranks App::Zone::Thing#grouped]))
  end
end
