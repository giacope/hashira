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
end
