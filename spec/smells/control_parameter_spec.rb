# frozen_string_literal: true

RSpec.describe(Hashira::Smells::ControlParameter) do
  def steered(source) = flagged("lib/app/zone/thing.rb" => source, "lib/app/zone/caller.rb" => caller(source))

  def flagged(files) = sniffed(files, "control_parameter")

  def caller(source) = "class Caller\n  def run = [#{defined(source).map { called(it) }.join(", ")}]\nend\n"

  def defined(source) = Hashira::Analysis::NodeWalk.new(Prism.parse(source).value).collect.grep(Prism::DefNode)

  def called(definition) = "App::Zone::Thing.new.#{definition.name}(#{flags(definition)})"

  def flags(definition) = Hashira::Smells::Parameters.new(definition).parts.map { flag(it) }.join(", ")

  def flag(part) = part.type.to_s.include?("keyword") ? "#{part.name}: true" : "true"

  it "flags a flag only where a caller picks it as a literal: true, false or a symbol" do
    source = "class Writer\n  def write(quoted) = quoted ? @io.puts(1) : @io.puts(2)\n\n  " \
      "def emit(raw:) = raw ? @a : @b\nend\n"
    calls = ["w.write(@quoted)\n  w.emit(raw: compute)", "w.write(false)\n  w.emit(raw: :yes)", "Writer.new.write(:on)"]
    found =
      calls.map do
        flagged("lib/app/w.rb" => source, "lib/app/c.rb" => "class C\n  def go(w = Writer.new)\n  #{it}\n end\nend\n")
      end
    expect(found.map { it.map(&:package) }).to(eq([[], %w[Writer#write Writer#emit], %w[Writer#write]]))
  end

  it "counts a caller only where its receiver is the method's class, never a same-named method elsewhere" do
    source = <<~RUBY
      class Database
        def self.build(name) = name == "pg" ? @pool.checkout : @pool.idle
        def write(quoted) = quoted ? @io.puts(1) : @io.puts(2)
      end
    RUBY
    calls = [
      "@items.build(:line)\n  @db.write(true)\n  write(false)\n  self.write(:on)", "::Database.build(:pg)",
      "db = Database.new\n  db.write(true)",
      "db = items\n  db.write(true)\n  db.build(:x)\n  Cart.new.write(:on)\n end\n def other\n  db = Database.new",
      "@database.write(true)", "database.write(true)", "main_database = items\n  main_database.write(:on)",
      "items.first(2).write(true)\n  Database.write(true)\n  [Database].first.build(:pg)"
    ]
    found =
      calls.map do
        flagged("lib/app/d.rb" => source, "lib/app/c.rb" => "class Cart\n  def go\n  #{it}\n end\nend\n")
      end
    expect(found.map { it.map(&:package) })
      .to(eq([[], %w[Database.build], %w[Database#write], [], *[%w[Database#write]] * 3, []]))
  end

  it "resolves the receiver from where the call sits, and a ::-rooted one from the top" do
    top = <<~RUBY
      class Database
        def self.build(name) = name == "pg" ? @pool.checkout : @pool.idle
      end

      class Store
        def self.open(name) = name == :a ? @pool.checkout : @pool.idle
        def other = @pool.open(:a)
      end
    RUBY
    shop = <<~RUBY
      module Shop
        class Database
          def write(quoted) = quoted ? @io.puts(1) : @io.puts(2)
        end

        class Cart
          def go = [@database.write(true), ::Database.build(:pg)]
        end
      end
    RUBY
    found = flagged("lib/app/top.rb" => top, "lib/app/shop.rb" => shop).map(&:package)
    expect(found).to(eq(%w[Shop::Database#write Database.build]))
  end

  it "types a literal receiver by its core class, where the project reopens that class" do
    reopened = "class String\n  def camelize(first = :upper) = first == :upper ? capitalize : downcase\nend\n"
    calls = ["\"x\".camelize(:lower)", "[1].camelize(:lower)"]
    caller = "module App\n  class String; end\n  class C\n    def go = %s\n  end\nend\n"
    found = calls.map { flagged("lib/app/s.rb" => reopened, "lib/app/c.rb" => format(caller, it)) }
    expect(found.map { it.map(&:package) }).to(eq([%w[String#camelize], []]))
  end

  it "leaves a factory alone whose every branch only builds an object: the switch maps a name to a strategy" do
    source = <<~RUBY
      module App
        class Store
          def self.build(name) = name == :pg ? Postgres.new(name) : Null.new
          def self.open(name) = name == :pg ? Postgres.new.tap(&:connect) : Null.new
        end
      end
    RUBY
    caller = "module App\n  class Cart\n    def go = [Store.build(:pg), Store.open(:pg)]\n  end\nend\n"
    expect(flagged("lib/app/store.rb" => source, "lib/app/cart.rb" => caller).map(&:package)).to(eq(%w[App::Store.open]))
  end

  it "leaves a private or protected helper's flag alone: the explicit public methods in front are the interface" do
    head = "class Writer\n  def quoted = put(true)\n  def plain = put(false)\n"
    put = "def put(quoted) = quoted ? @io.puts(1) : @io.puts(2)\nend\n"
    sources = %w[private protected public].map { "#{head}  #{it}\n  #{put}" }
    expect(sources.map { flagged("lib/app/w.rb" => it).map(&:package) }).to(eq([[], [], %w[Writer#put]]))
  end

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

  it "leaves a destructured parameter alone, since no caller passes it as a literal of its own" do
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
    expect(findings).to(be_empty)
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
