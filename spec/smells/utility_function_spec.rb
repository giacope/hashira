# frozen_string_literal: true

RSpec.describe(Hashira::Smells::UtilityFunction) do
  def utility(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "utility_function")
  it "flags a public instance method that never touches instance state" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Thing
            def shout(word)
              word.to_s.upcase
            end
          end
        end
      end
    RUBY
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(finding.package).to(eq("App::Zone::Thing#shout"))
    expect(message(finding)).to(include("touches no instance state", "zone/thing.rb:4"))
  end

  it "leaves private helpers, module functions, and singleton methods alone" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Thing
            def self.build(word) = word.to_s

            private

            def quiet(word) = word.to_s
          end

          module Bare
            module_function

            def loud(word) = word.to_s
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "exempts methods defined inside class << self" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Thing
            class << self
              LIMIT = 3

              def scrub(text) = text.strip
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "requires at least one call and zero self references" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Thing
            def blank = 1

            def stateful(word)
              @word = word.to_s
            end

            def implicit(word)
              tidy(word)
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end
end
