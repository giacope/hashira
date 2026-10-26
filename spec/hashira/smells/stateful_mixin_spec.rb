# frozen_string_literal: true

RSpec.describe(Hashira::Smells::StatefulMixin, :aggregate_failures) do
  def mixed(source) = sniffed({ "lib/app/zone/mixin.rb" => source }, "stateful_mixin")

  it "flags a mixin whose methods read state its host assigns, naming each field" do
    findings = mixed(<<~RUBY)
      module Loud
        def shout = "\#{@text.upcase}!"

        def whisper = @text.downcase + @mark.to_s
      end

      class Message
        include Loud

        def initialize(text) = @text = text
      end
    RUBY
    evidence = ["reads @text (lines 2, 4)", "reads @mark (line 4)"]
    expect(findings.map { [it.package, it.evidence] }).to(eq([["Loud", evidence]]))
    expect(message(findings.first)).to(
      eq(
        "Loud mixes behavior into its host's own state (zone/mixin.rb:1). " \
          "Make it a decorator: wrap the host and reach it through its public methods."
      )
    )
  end

  it "flags a mixin that keeps its own state in its host, but not a memo cache" do
    findings = mixed(<<~RUBY)
      module Tracked
        def track(event)
          @events = [event]
          @count += 1
          @seen &&= true
          @last, @first = event, event
        end

        def events = @events

        def cache = @cache ||= {}

        def hidden = @_hidden = 1
      end
    RUBY
    expect(findings.first.evidence).to(
      eq(
        [
          "keeps @events in its host (line 3)", "keeps @count in its host (line 4)",
          "keeps @seen in its host (line 5)", "keeps @last in its host (line 6)", "keeps @first in its host (line 6)"
        ]
      )
    )
  end

  it "flags a concern that installs callbacks, associations, validations or fields on its host" do
    findings = mixed(<<~RUBY)
      module Trackable
        extend ActiveSupport::Concern

        included do
          after_save :track
          has_many :events
          validates :name, presence: true
          self.class_attribute :tracker
        end

        def track = Analytics.event(id)
      end

      module Constrained
        def self.included(base)
          base.validate { |record| record.errors.add(record.error.attribute) }
          base.before_action :check
        end

        attr_accessor :limit

        def check = limit
      end
    RUBY
    expect(findings.to_h { [it.package, it.evidence] }).to(
      eq(
        "Trackable" => [
          "installs after_save (line 5)", "installs has_many (line 6)", "installs validates (line 7)",
          "installs class_attribute (line 8)"
        ],
        "Constrained" => [
          "installs validate (line 16)", "installs before_action (line 17)",
          "installs attr_accessor (line 20)"
        ]
      )
    )
  end

  it "leaves alone a protocol mixin over its host's public methods, and a module that is not a mixin" do
    findings = mixed(<<~RUBY)
      module Ordered
        include Comparable

        def <=>(other) = key <=> other.key

        def self.build = @built ||= new
      end

      module Shared
        extend self

        def config = @config
      end

      module Helpers
        module_function

        def config = @config
      end

      module Hooks
        def self.included(base)
          base.extend(ClassMethods)
          other.after_save :x
          base.scope :recent, -> { order(:id) }
        end
      end

      class Holder
        def read = @value
      end

      module Patches
        refine ::String do
          attr_writer :mark

          def marked = @mark
        end
      end

      module Opaque
        def read = @value

        def write(name) = instance_eval("@value = name")
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "counts state a mixin's own included modules assign as its own" do
    findings = mixed(<<~RUBY)
      module Base
        def start = @started = true
      end

      module Child
        include Base

        def started? = @started
      end
    RUBY
    expect(findings.map { [it.package, it.evidence] }).to(eq([["Base", ["keeps @started in its host (line 2)"]]]))
  end

  it "takes a bare extend for a call, not for extending the module itself" do
    findings = mixed("module Odd\n  extend\n\n  def read = @value\nend\n")
    expect(findings.map(&:evidence)).to(eq([["reads @value (line 4)"]]))
  end

  it "reads only the included hook and its parameter as the host, and leaves a module the project does not own alone" do
    findings = mixed(<<~RUBY)
      module Setup
        def self.configure(base) = base.after_save(:x)

        def self.included(base) = base.extend(Hooks)

        included do
          base.after_save :y
        end

        def go = 1
      end

      module Enumerable
        def total = @sum
      end
    RUBY
    expect(findings).to(be_empty)
  end
end
