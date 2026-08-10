# frozen_string_literal: true

RSpec.describe(Hashira::Smells::DuplicateMethodCall) do
  def repeated(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "duplicate_method_call")
  it "flags the same receiver-and-arguments call made twice" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def double
              @other.thing(1) + @other.thing(1)
            end
          end
        end
      end
    RUBY
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(finding.package).to(eq("App::Zone::Thing#double"))
    expect(message(finding)).to(include("repeats identical calls", "zone/thing.rb:4"))
    expect(finding.evidence).to(eq(["@other.thing(1) × 2 (line 5)"]))
  end

  it "tracks safe navigation, receiverless argument calls, and block passes" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def wobble
              @maybe&.load + @maybe&.load
            end

            def fetchy
              fetch(:host) + fetch(:host)
            end

            def mappy(rows)
              rows.map(&:name) + rows.map(&:name)
            end

            def spread
              @io.tick(1)
              @io.tick(1)
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "@maybe&.load × 2 (line 5)", "fetch(:host) × 2 (line 9)",
          "rows.map(&:name) × 2 (line 13)", "@io.tick(1) × 2 (lines 17, 18)"
        ]
      )
    )
  end

  it "flags identical literal blocks once, and shared calls whose blocks differ" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def wrapped
              transaction { save }
              transaction { save }
            end

            def joined
              @rows.map { compute }
              @rows.map { compute }
            end

            def varied
              @rows.each { poke }
              @rows.each { prod }
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "transaction { save } × 2 (lines 5, 6)",
          "@rows.map { compute } × 2 (lines 10, 11)",
          "@rows.each × 2 (lines 15, 16)"
        ]
      )
    )
  end

  it "excuses constructors, bare calls, and calls that differ in arguments" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def spawn
              Other.new + Other.new
            end

            def bare
              tick + tick
            end

            def varied
              @io.puts(1) + @io.puts(2)
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end
end
