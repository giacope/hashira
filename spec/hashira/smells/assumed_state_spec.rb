# frozen_string_literal: true

RSpec.describe(Hashira::Smells::AssumedState, :aggregate_failures) do
  def assumed(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "assumed_state")
  it "leaves a reopened library class to its owner, and counts instance_variable_set on a copy as assigning" do
    files = {
      "lib/app/ext/doc_manager.rb" => "class Gem::DocManager\n  def install = File.join(@doc_dir, @spec.name)\nend\n",
      "lib/app/zone/agg.rb" => <<~RUBY
        module App
          module Zone
            class Agg
              def initialize(expr) = @expr = expr

              def distinct = dup.tap { it.instance_variable_set(:@distinct, true) }

              def stamped = dup.tap { it.instance_variable_set("@stamp", 1) }

              def odd = dup.tap { it.instance_variable_set(name, 1) }

              def bare = instance_variable_set

              def report = [@expr, @distinct, @stamp, @lost]
            end
          end
        end
      RUBY
    }
    expect(sniffed(files, "assumed_state").map(&:evidence)).to(eq([["@lost"]]))
  end

  it "counts a peer's instance_variable_set, a set a subclass's constructor reaches, and leaves eval'd state alone" do
    files = {
      "lib/app/zone/thing.rb" => <<~'RUBY'
        module App
          module Zone
            class Params
              def self.nest(value, nesting)
                params = new(value)
                params.instance_variable_set(:@nesting, nesting)
                other = Params.allocate
                other.instance_variable_set(:@peer, 1)
                made = self.new(value)
                made.instance_variable_set(:@made, 1)
                stray = Other.new
                stray.instance_variable_set(:@stray, 1)
                plain = value
                plain.instance_variable_set(:@plain, 1)
                copied = value.dup
                copied.instance_variable_set(:@copied, 1)
                crafted = craft(value)
                crafted.instance_variable_set(:@crafted, 1)
                @class_level.instance_variable_set(:@far, 1)
                params
              end

              def initialize(value) = @value = value

              def path = [@nesting, @peer, @made, @stray, @plain, @copied, @crafted, @far, @value]
            end

            class Pager
              def limited? = [@limit, @offset]

              protected

              def assign(pairs) = pairs.each { |name, min| instance_variable_set(:"@#{name}", min) }
            end

            class OffsetPager < Pager
              def initialize = assign(limit: 1)
            end

            class Card
              %w[month year].each { |m| class_eval("def #{m}=(v) = @#{m} = v") }

              def initialize = @at = 1

              def expiry = [@month, @year]
            end

            class Integration
              def initialize = @at = 1

              def integrate
                ::ActionController::TestCase.class_eval do
                  def subject = @controller
                end
              end
            end
          end
        end
      RUBY
    }
    expect(sniffed(files, "assumed_state").map(&:evidence)).to(eq([%w[@copied @crafted @far @plain @stray]]))
  end

  it "counts a computed instance_variable_set anywhere in the class or its ancestors, whatever method reaches it" do
    core = <<~'RUBY'
      module Core
        def initialize(options) = setup(options)
        def setup(options) = options.each { |key, value| instance_variable_set("@shop_#{key}", value) }
        def b=(value) = style(:b, value)
        def style(name, value) = instance_variable_set(:"@#{name}", value)
      end
    RUBY
    classes = <<~'RUBY'
      class Real
        include Core
        def initialize(options) = super
        def url = [@shop_key, @b]
      end

      class Mock
        def initialize(options) = @data = options
        def url = [@shop_key, @data]
      end

      class Hooked
        define_method(:load) { |key| instance_variable_set("@hook_#{key}", 1) }
        def url = [@hook_key, @other_key]
      end
    RUBY
    found = sniffed({ "lib/app/core.rb" => core, "lib/app/classes.rb" => classes }, "assumed_state")
    expect(found.to_h { [it.package, it.evidence] }).to(eq("Mock" => ["@shop_key"], "Hooked" => ["@other_key"]))
  end

  it "counts a literal instance_variable_set on an instance any method builds of the class, through a local or a tap" do
    source = <<~RUBY
      module App
        module Zone
          class Configuration
            def dsl(context) = DSL.new.tap { |dsl| dsl.instance_variable_set(:@context, context) }
            def kind = Zone::Builder.allocate.tap { it.instance_variable_set(:@kind, 1) }
            def numbered = Builder.new.tap { _1.instance_variable_set(:@numbered, 1) }

            def made
              built = Builder.new
              built.instance_variable_set(:@made, 1)
              built.instance_variable_get(:@peeked)
              built.instance_variable_set(peeked, 1)
              stray = Stray.new
              stray.instance_variable_set(:@lost, 1)
              DSL.new.tap { |dsl| self.dsl(1).instance_variable_set(:@far, 1) }
              DSL.new.tap { kind.instance_variable_set(:@far, 1) }
              DSL.new.tap { |*| kind.instance_variable_set(:@far, 1) }
              Stray.new.tap { it.instance_variable_set(:@gone, 1) }
              DSL.new.tap(&:freeze)
            end
          end

          class DSL
            def initialize = @at = 1
            def run = [@context, @far]
          end

          class Builder
            def initialize = @at = 1
            def show = [@kind, @numbered, @made, @lost, @gone, @peeked]
          end
        end
      end
    RUBY
    found = assumed(source)
    expect(found.to_h { [it.package, it.evidence] })
      .to(eq("App::Zone::DSL" => ["@far"], "App::Zone::Builder" => %w[@gone @lost @peeked]))
  end

  it "leaves a class alone whose parent the project only reopens, as it does an unknown parent" do
    files = {
      "lib/app/tilt.rb" =>
        "module SafeTemplate\n  def render = 1\nend\n\nclass Tilt::Template\n  include SafeTemplate\nend\n",
      "lib/app/haml.rb" => <<~RUBY
        module App
          class HamlTemplate < ::Tilt::Template
            def prepare = @options[:context]
          end

          class Own
            def initialize = @at = 1
          end

          class Child < Own
            def show = @lost
          end
        end
      RUBY
    }
    expect(sniffed(files, "assumed_state").map(&:evidence)).to(eq([["@lost"]]))
  end

  it "flags instance variables read but never assigned anywhere in the class" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @seen = true
            end

            def report = @late.to_s + @seen.to_s
          end
        end
      end
    RUBY
    expect(findings.map { [it.package, it.evidence] }).to(eq([["App::Zone::Thing", ["@late"]]]))
    expect(message(findings.first))
      .to(include("reads instance variables nothing in the class assigns", "zone/thing.rb:3"))
  end

  it "treats every read as an assumption when nothing assigns at all" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Thing
            def report = @late.to_s
          end
        end
      end
    RUBY
    expect(findings.first.evidence).to(eq(["@late"]))
  end

  it "excuses reads sheltered under any conditional assignment" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @seen = true
            end

            def stash(map) = map[:key] ||= @late

            def fallback(handle)
              handle ||= @later
              handle.to_s
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "excuses memoized reads, initialized writes, and module mixins" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @base ||= 1
            end

            def cache = @memo ||= @base + probe

            def store = @seen = @base
          end

          module Mixin
            def report = @late.to_s
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "trusts underscore-prefixed memoization caches to be lazily assigned" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @seen = true
            end

            def report = (@_report ||= @seen.to_s)
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "trusts an underscore-prefixed cache even when only read" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @seen = true
            end

            def report = @_report || @seen.to_s
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "follows a superclass the codebase defines and still flags what nothing assigns" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Base
            def initialize
              @late = true
            end
          end

          class Thing < Base
            def report = [@late, @seen]
          end
        end
      end
    RUBY
    expect(findings.map(&:evidence)).to(eq([["@seen"]]))
  end

  it "resolves a superclass named like the class itself to the outer class" do
    findings = assumed(<<~RUBY)
      module App
        class Thing
          def initialize
            @late = true
          end
        end

        module Zone
          class Thing < Thing
            def report = [@late, @seen]
          end
        end
      end
    RUBY
    expect(findings.map(&:evidence)).to(eq([["@seen"]]))
  end

  it "walks a mixin cycle once" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          module Tracked
            include Timed

            def track = @tracked = true
          end

          module Timed
            include Tracked
          end

          class Thing
            include Timed

            def report = [@tracked, @seen]
          end
        end
      end
    RUBY
    expect(findings.map(&:evidence)).to(eq([["@seen"]]))
  end

  it "counts assignments made anywhere the object can reach" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          module Tracked
            include Timed

            def track(value) = @tracked = value
          end

          module Timed
            def stamp = @stamped = 1
          end

          class Thing
            include Tracked
            include Timed

            attr_writer :handle

            def initialize(value)
              track(value)
              settle(value)
            end

            def report = [@tracked, @stamped, @handle, @settled]

            private

            def settle(value) = @settled = value
          end

          class Thing
            def again = @tracked
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "stays quiet when a class inherits or mixes in something the codebase cannot see" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Thing < ActiveRecord::Base
            def report = @late.to_s
          end

          class Other
            include ActiveModel::Model

            def report = @late.to_s
          end

          class Dynamic
            extend Module.new

            def report = @late.to_s
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "stays quiet when the class body calls a macro that neither Ruby nor the codebase defines" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Base
            pattr_initialize [:late]
          end

          class Thing < Base
            def report = @late.to_s
          end

          class Other
            acts_as_list

            def report = @late.to_s
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags a class whose macros Ruby or the codebase defines, or that only a mixin's body calls" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          module Fields
            def fields(*) = nil
          end

          module Delegated
            delegate :size, to: :list
          end

          class Thing
            extend Fields
            include Delegated
            attr_reader :late
            fields :late
            private

            def report = @late.to_s
          end
        end
      end
    RUBY
    expect(findings.map(&:evidence)).to(eq([["@late"]]))
  end

  it "says when the subclasses are the ones expected to install what the base class reads" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Base
            def report = [@late, @seen]
          end

          class Middle < Base
          end

          class Leaf < Middle
            def initialize = @late = 1
          end
        end
      end
    RUBY
    expect(findings.map(&:evidence)).to(eq([%w[@late @seen]]))
    expect(findings.first.detail).to(include(installed: %w[@late], unassigned: %w[@seen]))
    expect(message(findings.first)).to(
      include(
        "subclasses are expected to install '@late'; pass it in instead",
        "Nothing ever assigns '@seen', so it reads nil: a typo or a dead hook"
      )
    )
  end

  it "tells a dead extension hook nothing assigns from state only the subclasses install" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Base
            def report = @hook
          end

          class Leaf < Base
            def initialize = @other = 1
          end
        end
      end
    RUBY
    finding = findings.first
    expect(finding.detail).to(include(installed: [], unassigned: %w[@hook]))
    expect(message(finding)).to(include("Nothing ever assigns '@hook'"))
    expect(message(finding)).not_to(include("subclasses"))
  end

  it "does not count singleton writes or extended modules as instance initialization" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          module State
            def set_state = @state = true
          end

          class Thing
            extend State

            def self.configure(value) = @token = value
            def report = [@state, @token]
          end
        end
      end
    RUBY
    expect(findings.first.evidence).to(eq(["@state", "@token"]))
  end

  it "counts the writers an attribute macro mints from a splatted list the class declares" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Thing
            EXTRA = %i[limit].freeze
            OPTIONS = %i[host port].freeze
            MODES = [:mode, 1]
            LIMIT = 3
            attr_accessor(*OPTIONS)
            attr_writer(*MODES, *LIMIT, *Missing, *options, label)

            def report = [@host, @port, @mode, @limit]
          end
        end
      end
    RUBY
    expect(findings.first.evidence).to(eq(["@limit"]))
  end

  it "takes a block the class body hands its own DSL for instance code, as a lexer or controller runs it" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Base
            def self.start(&block) = (@starts ||= []) << block
            def self.rule(&) = nil
          end

          class Thing < Base
            start { @content_type = "text/plain" }
            rule do
              @debug = true
            end

            def mimetype = [@content_type, @debug, @missing]
          end
        end
      end
    RUBY
    expect(findings.first.evidence).to(eq(["@missing"]))
  end

  it "recognizes string-named attribute writers" do
    findings = assumed(<<~RUBY)
      module App
        module Zone
          class Thing
            attr_writer "handle"

            def report = @handle
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  def reopened
    base = "module App\n  module Zone\n    class Base\n      def initialize = @seen = 1\n    end\n  end\nend\n"
    thing = "module App\n  module Zone\n    class Thing < Base\n      def report = @seen\n    end\n  end\nend\n"
    { "lib/app/zone/base.rb" => base }.merge((1..3).to_h { ["lib/app/zone/thing#{it}.rb", thing] })
  end

  it "reads a class name's ancestry once, however many files reopen it" do
    swept = []
    spy_on(Hashira::Smells::Scope, :sweep, swept)
    smells(reopened, &:findings)
    expect(swept.grep(Prism::DefNode).map(&:name).tally).to(eq(initialize: 1, report: 3))
  end
end
