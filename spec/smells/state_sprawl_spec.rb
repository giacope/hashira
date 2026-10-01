# frozen_string_literal: true

RSpec.describe(Hashira::Smells::StateSprawl) do
  def crowded(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "state_sprawl")
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

  it "does not count a memo predeclared as nil, or one guarded by defined?" do
    findings = crowded(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @a = 1
              @b = 2
              @c, @d = 3, 4
              @memo = nil
            end

            def cache = @memo ||= @a + @b

            def reset = @memo = nil

            def total
              return @total if defined?(@total)
              @total = @c + @d
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "counts a nil-predeclared field that is also set outright, or never lazily filled" do
    findings = crowded(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @a, @b = 1, 2
              @c = nil
              @d = nil
              @e = nil
              @g = defined?(@h)
            end

            def cache = @c ||= @a + @b

            def fill = @c = 3

            def memo = @e ||= @f ||= 4
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(%w[@a @b @c @d @g]))
  end

  it "counts a field that defined? tests as a flag rather than guarding a memo" do
    findings = crowded(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize(value, packed)
              @a, @b, @c = value, 2, 3
              @packed = true if packed
              @value = value unless value.nil?
            end

            def packed? = defined?(@packed)

            def value
              @value = @a.to_s unless defined?(@value)
              @value
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(%w[@a @b @c @packed @value]))
  end

  it "does not count underscore-prefixed memoization caches as state" do
    findings = crowded(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @a = 1
              @b = 2
              @c, @d = 3, 4
            end

            def wide
              @_wide = @a + @b
            end

            def deep
              @_deep = @c + @d
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end
end
