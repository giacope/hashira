# frozen_string_literal: true

RSpec.describe(Hashira::Smells::InstanceVariableAssumption) do
  def assumed(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "instance_variable_assumption")
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
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(finding.package).to(eq("App::Zone::Thing"))
    expect(message(finding)).to(include("reads instance variables nothing in the class assigns", "zone/thing.rb:3"))
    expect(finding.evidence).to(eq(["@late"]))
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
end
