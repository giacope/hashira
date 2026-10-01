# frozen_string_literal: true

RSpec.describe(Hashira::Smells::RepeatedCall) do
  def repeated(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "repeated_call")
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
              first = @io.tick(1)
              [first, @io.tick(1)]
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
              kept = transaction { save }
              [kept, transaction { save }]
            end

            def joined
              kept = @rows.map { compute }
              [kept, @rows.map { compute }]
            end

            def varied
              kept = @rows.each { poke }
              [kept, @rows.each { prod }]
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

  it "excuses calls that mint a fresh value every time they run" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def buffers
              out = "".b
              err = "".b
              [out, err]
            end

            def ids
              { job: rand(1000), run: rand(1000) }
            end

            def tokens
              [SecureRandom.hex(8), SecureRandom.hex(8)]
            end

            def copies(row)
              [row.dup, row.dup]
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "excuses repeats that no single run can reach twice" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def steered(node)
              case node.kind
              when :left then walk(node)
              when :two then walk(node)
              end
            end

            def matched(row)
              case row
              in { left: } then @io.tick(2)
              in { right: } then @io.tick(2)
              end
            end

            def either(flag)
              if flag
                @io.tick(1)
              else
                @io.tick(1)
              end
            end

            def reversed(flag)
              unless flag
                @io.wrap { work }
              else
                @io.wrap { work }
              end
            end

            def guarded(key)
              raise(KeyError, key.to_s) unless @store.key?(key)
              @store.fetch(key)
            rescue TypeError
              raise(KeyError, key.to_s)
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still counts repeats on separate conditions, which one run can reach both of" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def sifted(one, two)
              left = @io.tick(1) if one
              right = @io.tick(1) if two
              [left, right]
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["@io.tick(1) × 2 (lines 5, 6)"]))
  end

  it "counts calls in a rescue body and its else clause when execution can reach both" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def guarded
              begin
                left = @io.tick(1)
              rescue StandardError
                @io.warn
              else
                right = @io.tick(1)
              ensure
                cleanup
              end
              [left, right]
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["@io.tick(1) × 2 (lines 6, 10)"]))
  end

  it "counts a call in a condition repeated in the branch it guards" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def lookup(key)
              if @store.fetch(key)
                @store.fetch(key).to_s
              end
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["@store.fetch(key) × 2 (lines 5, 6)"]))
  end

  it "counts a call in a rescue body repeated in the ensure that follows it" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def guarded
              work
            rescue IOError
              @log.write(@io.close(1))
            ensure
              @log.write(@io.close(1))
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["@io.close(1) × 2 (lines 7, 9)"]))
  end

  it "excuses calls on opposite sides of a rescue modifier" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def guarded = @io.tick(1) rescue @io.tick(1)
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "leaves repeated commands alone: calls whose result the method throws away" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def said
              @io.tick(1)
              @io.tick(1)
              nil
            end

            def guarded(one)
              @io.tick(1) if one
              @io.tick(1) if one
              one ? nil : @io.tick(2)
              one ? nil : @io.tick(2)
              @io.tick(3) unless one
              @io.tick(3) unless one
              nil
            end

            def otherwise(one)
              unless one then nil else @io.tick(1) end
              unless one then nil else @io.tick(1) end
              nil
            end

            def switched(one)
              case one
              when 1 then @io.tick(1)
              end
              case one
              when 1 then @io.tick(1)
              end
              case one
              when 1 then nil
              else @io.tick(2)
              end
              case one
              when 1 then nil
              else @io.tick(2)
              end
              nil
            end

            def matched(one)
              case one
              in 1 then @io.tick(1)
              end
              case one
              in 1 then @io.tick(1)
              end
              case one
              in 1 then nil
              else @io.tick(2)
              end
              case one
              in 1 then nil
              else @io.tick(2)
              end
              nil
            end

            def begun(one)
              begin
                @io.tick(1)
              end
              begin
                @io.tick(1)
              end
              nil
            end

            def rescued(one)
              begin
                one
              rescue KeyError
                @io.tick(1)
              end
              begin
                one
              rescue KeyError
                @io.tick(1)
              end
              nil
            end

            def chained(one)
              begin
                one
              rescue KeyError
                one
              rescue IndexError
                @io.tick(1)
              end
              begin
                one
              rescue KeyError
                one
              rescue IndexError
                @io.tick(1)
              end
              nil
            end

            def settled(one)
              begin
                one
              rescue KeyError
                one
              else
                @io.tick(1)
              end
              begin
                one
              rescue KeyError
                one
              else
                @io.tick(1)
              end
              nil
            end

            def ensured(one)
              begin
                one
              ensure
                @io.tick(1)
              end
              begin
                one
              ensure
                @io.tick(1)
              end
            end

            def wrapped(one)
              (one; @io.tick(1))
              (one; @io.tick(1))
              nil
            end

            def modified(one)
              @io.tick(1) rescue one
              @io.tick(1) rescue one
              one rescue @io.tick(2)
              one rescue @io.tick(2)
              nil
            end

            def joined(one)
              one && @io.tick(1)
              one && @io.tick(1)
              one || @io.tick(2)
              one || @io.tick(2)
              nil
            end

            def marked(rows)
              rows.each { @io.tick(1) }
              rows.each { @io.tick(1) }
              nil
            end

            def looped(one)
              while one
                @io.tick(1)
              end
              while one
                @io.tick(1)
              end
            end

            def awaited(one)
              until one
                @io.tick(1)
              end
              until one
                @io.tick(1)
              end
            end

            def walked(rows)
              for row in rows
                @io.tick(1)
              end
              for row in rows
                @io.tick(1)
              end
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still counts a call whose value flows on: returned, assigned, passed, or a kept block's result" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def returned
              kept = @io.tick(1)
              @io.tick(1)
            end

            def passed
              @log.write(@io.tick(2))
              @log.write(@io.tick(2))
              nil
            end

            def yielded(rows)
              [rows.map { @io.tick(3) }, rows.select { @io.tick(3) }]
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(["@io.tick(1) × 2 (lines 5, 6)", "@io.tick(2) × 2 (lines 10, 11)", "@io.tick(3) × 2 (line 16)"])
    )
  end

  it "excuses calls fed a freshly minted value as an argument, but not calls on one" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def shown = [render(Other.new), render(Other.new)]

            def wrapped = [wrap(label("".b)), wrap(label("".b))]

            def named = [Other.new.name, Other.new.name]
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["Other.new.name × 2 (line 8)"]))
  end

  it "reports a repeated chain once, not again for each prefix repeated on the same calls" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def stamped = [DateTime.now.utc, DateTime.now.utc]

            def shown = [format(@params[:id]), format(@params[:id])]

            def stray = [Time.now.utc, Time.now.utc, Time.now]
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "DateTime.now.utc × 2 (line 4)", "format(@params[:id]) × 2 (line 6)",
          "Time.now.utc × 2 (line 8)", "Time.now × 3 (line 8)"
        ]
      )
    )
  end

  it "excuses the same call at two exits, since a run leaves the method once" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def create(one, two)
              return head(:ok) unless one
              return if two
              return head(:ok) if @late.ready?(two)
              save
              head(:ok)
            end

            def kept(one)
              kept = @io.tick(1)
              return @io.tick(1) if one
              kept
            end

            def looped(rows)
              rows.each { |row| return @io.tick(2) if row }
              rows.each { |row| return @io.tick(2) if row }
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["@io.tick(1) × 2 (lines 13, 14)"]))
  end
end
