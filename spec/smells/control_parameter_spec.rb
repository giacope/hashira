# frozen_string_literal: true

RSpec.describe(Hashira::Smells::ControlParameter) do
  def steered(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "control_parameter")
  it "flags a parameter that only decides which path to take" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def write(quoted)
              if quoted
                @io.puts("'x'")
              else
                @io.puts("x")
              end
            end
          end
        end
      end
    RUBY
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(finding.package).to(eq("App::Zone::Thing#write"))
    expect(message(finding)).to(include("is steered by 'quoted'", "zone/thing.rb:4"))
    expect(finding.evidence).to(eq(["quoted (line 5)"]))
  end

  it "flags comparisons, unless, case, and boolean guards on the parameter" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def pick(mode)
              return @a if mode == :fast
              @b
            end

            def veto(flag)
              @done = true unless flag
            end

            def sort(order)
              case order
              when :asc then @list
              else @list.reverse
              end
            end

            def bump(deep)
              deep && @count.step
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(%w[App::Zone::Thing#pick App::Zone::Thing#veto App::Zone::Thing#sort App::Zone::Thing#bump])
    )
  end

  it "sees destructured parameters" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def route((mode, payload))
              if mode == :fast
                @sink.rush(payload)
              else
                @sink.walk(payload)
              end
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["mode (line 5)"]))
  end

  it "accepts parameters that also do real work" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def body_use(flag)
              @log.write(flag)
              flag ? @a : @b
            end

            def branch_use(name)
              if name
                @io.puts(name)
              end
            end

            def called_in_condition(text)
              @quiet = true if text.empty?
            end

            def compared_but_used(mode)
              @io.puts(mode) if mode == :loud
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "accepts parameters handed on as a value through || or &&" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def label(name) = name || "anonymous"

            def keep(options)
              @options = options || {}
            end

            def mark(padded) = @io.puts(padded && "wide")

            def settle(quiet)
              return @a if quiet == :hush
              @level = quiet || :loud
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags && standing alone as a statement and || steering a loop" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def bump(deep)
              deep && @count.step
              @count
            end

            def spin(eager)
              @count.step while eager || @count.low?
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:evidence)).to(eq([["deep (line 5)"], ["eager (line 10)"]]))
  end

  it "accepts parameters used in an else branch" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def fallback(name)
              if name
                @io.puts("named")
              else
                @io.puts(name.inspect)
              end
            end

            def inverted(name)
              unless name
                @io.puts("anonymous")
              else
                @io.puts(name)
              end
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "leaves conditions inside a nested definition to that definition" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def install(mode)
              @installed = true
              def pick(mode) = mode ? @a : @b
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "does not take a nested definition's read of a same-named local as real work" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def install(mode)
              return @a if mode == :fast
              def announce(mode) = @io.puts(mode)
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["mode (line 5)"]))
  end

  it "reports each controlling parameter with every deciding line" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def route(kind)
              return @a if kind == :a
              return @b if kind == :b
              @c
            end
          end
        end
      end
    RUBY
    expect(findings.first.evidence).to(eq(["kind (lines 5, 6)"]))
  end

  it "follows an elsif ladder rung by rung, listing the lines in order" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def route(kind)
              if kind == :a
                @a
              elsif kind == :b
                @b
              end
            end
          end
        end
      end
    RUBY
    expect(findings.first.evidence).to(eq(["kind (lines 5, 7)"]))
  end

  it "takes a comparison against another value as data, not a switch" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def renew(expected_epoch)
              return false unless current_epoch == expected_epoch
              @epoch += 1
            end

            def swap(seen)
              @value = @next if @value != seen
            end

            def changed?(before, after)
              return false unless before && after && before != after
              @log.write(:changed)
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still takes a comparison against a literal or a constant as a switch" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def pick(mode)
              return @a if mode == FAST
              return @b if Speed::SLOW == mode
              @c if mode =~ /x/ && @low == @high
            end

            def odd(mode) = (@a if mode.==)

            def guard(level)
              return unless level && level != :off
              @log.write(:on)
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["mode (lines 5, 6, 7)", "mode (line 10)", "level (line 13)"]))
  end

  it "takes a conditional that only maps the parameter to literal values as a lookup" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def apply(dry_run)
              status = dry_run ? "dry_run" : "applied"
              @log.write(status)
            end

            def label(kind)
              case kind
              when :a then t(".alpha")
              when :b then I18n.t(:beta)
              else Labels::OTHER
              end
            end

            def tone(loud)
              @io.puts(if loud then :high end)
            end

            def tier(size)
              if size == :big
                3
              elsif size == :mid
                2
              else
                1
              end
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags a conditional any of whose branches does more than name a value" do
    findings = steered(<<~RUBY)
      module App
        module Zone
          class Thing
            def apply(dry_run) = dry_run ? @a : "applied"

            def label(kind)
              case kind
              when :a then t(@key)
              else :other
              end
            end

            def bare(kind)
              case kind
              when :b then t
              else :other
              end
            end

            def blank(kind)
              case kind
              when :c
              else :other
              end
            end

            def steps(fast)
              if fast
                :one
                :two
              end
            end

            def guard(on) = on && "wide"
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(
        %w[
          App::Zone::Thing#apply App::Zone::Thing#label App::Zone::Thing#bare App::Zone::Thing#blank
          App::Zone::Thing#steps App::Zone::Thing#guard
        ]
      )
    )
  end
end
