# frozen_string_literal: true

RSpec.describe(Hashira::Smells::RepeatedConditional) do
  def branching(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "repeated_conditional")
  it "flags a test repeated in more than two places across the class" do
    findings = branching(<<~RUBY)
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
    expect(message(finding)).to(include("branches on the same test 3 times", "zone/thing.rb:3"))
    expect(finding.evidence).to(eq(["@mode == :x × 3 (lines 4, 7, 12)"]))
  end

  it "tolerates two repeats, block_given?, and predicateless cases" do
    findings = branching(<<~RUBY)
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
    findings = branching(<<~RUBY)
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

  it "keeps a test on a local variable to the method or block that binds it" do
    findings = branching(<<~RUBY)
      module App
        module Zone
          class Thing
            def alpha(all) = all.zero? ? 1 : 2

            def beta(all) = all.zero? ? 3 : 4

            def gamma(all) = all.zero? ? 5 : 6

            def delta(rows)
              return 1 if rows.empty?
              rows.map { it.empty? ? 0 : 1 }
              rows.empty? ? 2 : 3
            end

            def epsilon(rows)
              rows.each { tick unless it }
              rows.each { tock unless it }
              rows.each { tuck unless it }
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "counts a test on a local repeated inside one method, and lists each line once" do
    findings = branching(<<~RUBY)
      module App
        module Zone
          class Thing
            def alpha(all)
              return (all ? 1 : 2) if all
              all ? 3 : 4
            end

            def beta
              return (@mode ? 1 : 2) if @mode
              @mode ? 3 : 4
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["all × 3 (lines 5, 6)", "@mode × 3 (lines 10, 11)"]))
  end

  it "counts a test on the object's own state across blocks too, lines in order" do
    findings = branching(<<~RUBY)
      module App
        module Zone
          class Thing
            def alpha(rows)
              rows.map { @mode ? 1 : 2 }
              return 3 if @mode
              rows.map { |row| row.size if @mode }
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["@mode × 3 (lines 5, 6, 7)"]))
  end

  it "judges a reopened class once, across every file that opens it" do
    findings = sniffed(
      {
        "lib/app/zone/thing.rb" => "class Thing\n  def a = @m ? 1 : 2\n\n  def b = @m ? 3 : 4\nend\n",
        "lib/app/zone/thing/more.rb" => "class Thing\n  def c = @m ? 5 : 6\nend\n"
      },
      "repeated_conditional"
    )
    expect(findings.size).to(eq(1))
    expect(findings.first.detail[:site]).to(eq("thing.rb:1"))
    expect(findings.first.evidence).to(eq(["@m × 3 (lines 2, 4)"]))
  end
end
