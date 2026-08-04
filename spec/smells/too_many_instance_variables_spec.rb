# frozen_string_literal: true

RSpec.describe(Hashira::Smells::TooManyInstanceVariables) do
  def crowded(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "too_many_instance_variables")
  it "flags a class assigning more than four instance variables" do
    findings = crowded(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @a = 1
              @b = 2
              @c, @d = 3, 4
            end

            def bump = @e += 1

            class Inner
              def fill
                @z = 1
              end
            end
          end
        end
      end
    RUBY
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(finding.package).to(eq("App::Zone::Thing"))
    expect(message(finding)).to(include("holds 5 instance variables", "zone/thing.rb:3"))
    expect(finding.evidence).to(eq(%w[@a @b @c @d @e]))
  end
  it "does not count memoization, repeats, or module state" do
    findings = crowded(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @a = 1
              @b = 2
              @c = 3
              @d = 4
              @a = 5
            end

            def cache = @memo ||= @a + @b
          end

          module Wide
            def fill
              @a = 1
              @b = 2
              @c = 3
              @d = 4
              @e = 5
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end
end
