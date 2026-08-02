# frozen_string_literal: true

RSpec.describe(Hashira::Smells::RepeatedConditional) do
  def branchy(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "repeated_conditional")
  it "flags a test repeated in more than two places across the class" do
    findings = branchy(<<~RUBY)
      module App
        module Zone
          class Thing
            def alpha = @mode == :x ? 1 : 2

            def beta
              return 3 if @mode == :x
              4
            end

            def gamma
              case @mode == :x
              when true then 5
              else 6
              end
            end
          end
        end
      end
    RUBY
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(finding.package).to(eq("App::Zone::Thing"))
    expect(finding.message).to(include("branches on the same test 3 times", "zone/thing.rb:3"))
    expect(finding.evidence).to(eq(["@mode == :x × 3 (lines 4, 7, 12)"]))
  end
  it "tolerates two repeats, block_given?, and predicateless cases" do
    findings = branchy(<<~RUBY)
      module App
        module Zone
          class Thing
            def alpha = @mode == :x ? 1 : 2

            def beta = @mode == :x ? 3 : 4

            def gamma
              yield if block_given?
              tick if block_given?
              tock if block_given?
            end

            def delta
              case
              when @late then 1
              else 2
              end
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end
  it "skips modules and nested classes it does not own" do
    findings = branchy(<<~RUBY)
      module App
        module Zone
          module Helper
            def a = @m ? 1 : 2

            def b = @m ? 3 : 4

            def c = @m ? 5 : 6
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end
end
