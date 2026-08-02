# frozen_string_literal: true

RSpec.describe(Hashira::Smells::InstanceVariableAssumption) do
  def assumed(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "instance_variable_assumption")
  it "flags instance variables read but never assigned in initialize" do
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
    expect(finding.message).to(include("reads instance variables never set in initialize", "zone/thing.rb:3"))
    expect(finding.evidence).to(eq(["@late"]))
  end
  it "treats every read as an assumption when initialize is missing" do
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
end
