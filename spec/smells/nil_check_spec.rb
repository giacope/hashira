# frozen_string_literal: true

RSpec.describe(Hashira::Smells::NilCheck) do
  def checked(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "nil_check")
  it "flags nil?, nil comparisons, and when-nil clauses with their lines" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def query(x) = x.nil? && @a

            def compare(x) = x == nil || nil == x

            def strict(x) = x === nil

            def branch(x)
              case x
              when nil then @a
              else @b
              end
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(%w[App::Zone::Thing#query App::Zone::Thing#compare App::Zone::Thing#strict App::Zone::Thing#branch])
    )
    expect(message(findings.first)).to(include("checks for nil", "zone/thing.rb:4"))
  end
  it "reaches methods defined inside blocks and class << self" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            concerning :Checks do
              def check = @a.nil?
            end

            class << self
              def peek = @cache.nil?
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#check", "App::Zone::Thing.peek"]))
  end
  it "ignores comparisons that never involve nil" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def fine(x)
              case x
              when :a then @a
              else x == :b ? @b : @c
              end
            end

            def odd(x) = x.==
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end
end
