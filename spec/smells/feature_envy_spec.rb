# frozen_string_literal: true

RSpec.describe(Hashira::Smells::FeatureEnvy) do
  def envy(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "feature_envy")
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
    expect(message(finding)).to(include("refers to 'order' more than to self", "zone/thing.rb:4"))
    expect(finding.evidence).to(eq(["order (line 5)"]))
  end
  it "counts compound assignments against the assigned name" do
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
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#bump"]))
    expect(findings.flat_map(&:evidence)).to(eq(["count (lines 5, 6)"]))
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
    expect(message(findings.first)).to(include("'left', 'right'"))
    expect(findings.first.evidence).to(eq(["left (lines 6, 7)", "right (lines 8, 9)"]))
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
              @made = seed.new
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end
end
