# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Report, :aggregate_failures) do
  # The class of a pipeline's smells analyzer and the kinds it finds: every rule on, or with nil the defaults.
  def sniffing(options)
    rules = options ? Hashira::Config::Rules::ALL : Hashira::Config::Rules::NONE
    pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"], rules:), **options.to_h)
    [pipeline.smells.class, pipeline.findings.map(&:kind)]
  end

  it "runs inside the pipeline by default and steps aside when skipped" do
    found = within(Fixtures::CYCLIC_FILES) { [{}, { enabled: %i[coupling] }, nil].map { sniffing(it) } }
    expect(found).to(
      match(
        [
          [described_class, include("utility_function")], [NilClass, exclude("utility_function")],
          [anything, include("cycle", "utility_function")]
        ]
      )
    )
  end

  it "honours visibility markers in all their spellings" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            class Thing
              VERSION = "1"

              def open(word) = word.to_s

              private def wrapped(word) = word.to_s

              def named(word) = word.to_s

              private :named

              def shown(word) = word.to_s

              private "stray"

              Thing.private :ignored

              private

              def hidden(word) = word.to_s
            end

            class Bare
            end
          end
        end
      RUBY
    }
    findings = sniffed(files, "utility_function")
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#open", "App::Zone::Thing#shown"]))
  end

  it "names singleton subjects with a dot and instance subjects with a hash" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            class Duck; def honk = 1; def moo = 1; end

            class Thing
              def self.probe(duck)
                duck.honk if duck.respond_to?(:honk)
              end

              def poke(duck)
                duck.honk if duck.respond_to?(:honk)
              end
            end
          end
        end
      RUBY
    }
    findings = sniffed(files, "manual_dispatch")
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing.probe App::Zone::Thing#poke]))
  end

  it "handles every parameter shape when hunting control parameters" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY,
        module App
          module Zone
            class Thing
              def mixed(alfa, bravo = nil, *rest, post, charlie:, delta: nil, **extra, &blk)
                @io.write(alfa, rest, post, charlie, extra, blk)
                @done = true if bravo && delta
              end

              def anonymous(*, **) = @io.flush

              def forward(...) = @io.call(...)

              def sneaky(flag)
                def helper = 1
                @done = true if flag
              end
            end
          end
        end
      RUBY
      "lib/app/zone/caller.rb" => <<~RUBY
        class Caller
          def run(thing = App::Zone::Thing.new) = [thing.mixed, thing.mixed(1, true, 2, delta: :d), thing.sneaky(:x)]
        end
      RUBY
    }
    findings = sniffed(files, "control_parameter")
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#mixed App::Zone::Thing#sneaky]))
    expect(findings.first.evidence).to(eq(["bravo (line 6)", "delta (line 6)"]))
  end

  it "names a compound-path type the way Ruby resolves it, not the way it nests" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            class Zone::Thing
              def leak = @late
            end
          end
        end
      RUBY
    }
    findings = sniffed(files, "assumed_state")
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing"]))
  end

  it "names what a concern or class << self defines for the class with a dot, private ones included" do
    files = {
      "lib/app/zone/greets.rb" => <<~RUBY
        module App
          module Zone
            class Duck; def honk = 1; def moo = 1; end

            module Greets
              class_methods do
                def summon(duck) = (duck.honk if duck.respond_to?(:honk))

                private

                def stash(duck) = (duck.honk if duck.respond_to?(:honk))
              end

              module ClassMethods
                def gather(duck) = (duck.honk if duck.respond_to?(:honk))
              end

              class << self
                private def shelve(duck) = (duck.honk if duck.respond_to?(:honk))
              end

              def greet(duck) = (duck.honk if duck.respond_to?(:honk))
            end

            module ClassMethods
              def bare(duck) = (duck.honk if duck.respond_to?(:honk))
            end

            class Styles
              class ClassMethods
                def check(duck) = (duck.honk if duck.respond_to?(:honk))
              end
            end
          end
        end
      RUBY
    }
    findings = sniffed(files, "manual_dispatch")
    expect(findings.map(&:package)).to(
      eq(
        %w[
          App::Zone::Greets.summon App::Zone::Greets.stash App::Zone::Greets.shelve App::Zone::Greets#greet
          App::Zone::Greets.gather App::Zone.bare App::Zone::Styles::ClassMethods#check
        ]
      )
    )
  end

  it "judges a class's state across every file that reopens it" do
    files = {
      "lib/app/zone/thing.rb" => "class Thing\n  def initialize = [@a = 1, @b = 2, @c = 3]\nend\n",
      "lib/app/zone/thing/more.rb" => "class Thing\n  def more = [@d = 4, @e = 5]\n\n  def sum = @d + @e\nend\n"
    }
    findings = sniffed(files, "state_sprawl")
    parked = %w[@d @e].map { "#{it} (parked between calls)" }
    expect(findings.map(&:evidence)).to(eq([%w[@a @b @c] + parked]))
  end
end
