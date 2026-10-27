# frozen_string_literal: true

RSpec.describe(Hashira::Smells::RepeatedCall, :aggregate_failures) do
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
    expect(findings.map { [it.package, it.evidence] })
      .to(eq([["App::Zone::Thing#double", ["@other.thing(1) × 2 (line 5)"]]]))
    expect(message(findings.first)).to(include("repeats identical calls", "zone/thing.rb:4"))
  end

  it "leaves a plain read of a near object made twice alone, even fed on, and reports it read three times" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def guard(node) = node.parent && use(node.parent)

            def keyed(match) = [@params[:id], @params[:id], match[1], match[1]]

            def thrice(node) = [node.parent, node.parent, node.parent]

            def relayed(record) = [record["s3"]["bucket"], record["s3"]["key"]]

            def queried = [Time.now, Time.now]

            def helper = [current_user.errors, current_user.errors]
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(%w[App::Zone::Thing#thrice App::Zone::Thing#queried App::Zone::Thing#helper])
    )
  end

  it "takes a literal-key read through the class's own attribute reader for a plain read, not one through a helper" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            attr_reader :options

            def routing = [options[:routing], options[:routing]]

            def selfish = [self.options[:a], self.options[:a]]

            def helper = [settings[:a], settings[:a]]

            def thrice = [options[:x], options[:x], options[:x]]

            def computed(key) = [options[key], options[key]]

            def chained(other) = [other.options[:a], other.options[:a]]

            def called = [options(1)[:a], options(1)[:a]]

            def settings = { a: @a }
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[helper thrice computed chained called].map { "App::Zone::Thing##{it}" }))
  end

  it "counts the plain reads one run makes, not every read across branches that never run together" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def paged(kind)
              case kind
              when :before then page(@room.messages, @room.messages)
              when :after then page(@room.messages, @room.messages)
              else @room.messages
              end
            end

            def crowded(kind)
              case kind
              when :before then page(@room.messages, @room.messages, @room.messages)
              else @room.messages
              end
            end
          end
        end
      end
    RUBY
    expect(findings.map { [it.package, it.evidence] }).to(
      eq([["App::Zone::Thing#crowded", ["@room.messages × 4 (lines 14, 15)"]]])
    )
  end

  it "takes a reading measured against a stored earlier reading for a deliberate second sample, not a repeat" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def measure(clock)
              started = clock.now(:ms)
              @runner.call
              clock.now(:ms) - started
            end

            def wait(clock, timeout)
              deadline = clock.now(:ms) + timeout
              @runner.call until clock.now(:ms) > deadline
            end

            def same(clock)
              started = clock.now(:ms)
              @runner.call
              clock.now(:ms) == started
            end

            def passed(clock)
              started = clock.now(:ms)
              @log.write(started, clock.now(:ms))
            end

            def apart(clock)
              started = clock.now(:ms)
              [clock.now(:ms), started - 1]
            end

            def skewed(clock, offset)
              started = clock.now(:ms)
              [started, clock.now(:ms) - offset]
            end
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[same passed apart skewed]))
  end

  it "reads a reading the loop names as it measures it, in parentheses, for the deadline loop it is" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def named(clock, timeout)
              deadline = clock.now(:ms) + timeout
              while (now = clock.now(:ms)) < deadline
                return true if @io.ready?(deadline - now)
              end
            end

            def bare(clock, timeout)
              deadline = clock.now(:ms) + timeout
              @io.poll while (clock.now(:ms)) < deadline
            end

            def boxed(clock, timeout)
              deadline = clock.now(:ms) + timeout
              @io.poll while [clock.now(:ms)].max < deadline
            end
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[boxed]))
  end

  it "parts two calls when the receiver is handed on between them, as an argument, a keyword or a stored result" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def logged
              first = @cart.total(1)
              log(@cart)
              [first, @cart.total(1)]
            end

            def keyed
              first = @cart.total(1)
              log(cart: @cart)
              [first, @cart.total(1)]
            end

            def kept
              first = @cart.total(1)
              seen = audit(@cart)
              [first, @cart.total(1), seen]
            end

            def plain
              first = @cart.total(1)
              log(@other, cart: @basket)
              [first, @cart.total(1)]
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#plain"]))
  end

  it "parts two calls around a command on the receiver that takes the first as its unparenthesized argument" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def topped
              @cart.add @cart.total(1)
              @cart.total(1)
            end

            def forwarded
              @other.add @cart.total(1)
              @cart.total(1)
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#forwarded"]))
  end

  it "counts a bare call handed a block argument, unlike a bare read, as a call that can repeat" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def twice = [total, total]

            def handed = [pick(&@rule), pick(&@rule)]

            def total = 1

            def pick = 2
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#handed"]))
  end

  it "never surveys the bindings of a call made once, which cannot repeat" do
    asked = []
    spy_on(Hashira::Smells::Bindings, :free, asked)
    repeated("module App\n  class Thing\n    def once = @other.thing(1) + @other.other(2)\n  end\nend\n")
    expect(asked).to(eq([]))
  end

  it "takes the same call again, in the arm a test of its first answer falls back from, for a retry" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def settle(job)
              outcome = attempt(job, first: true)
              outcome.lost? ? attempt(job, first: true) : outcome
            end

            def kept(job)
              outcome = attempt(job, first: true)
              unless outcome.lost?
                outcome
              else
                @log.write(:again)
                attempt(job, first: true)
              end
            end

            def twice(job)
              outcome = attempt(job, first: true)
              job.lost? ? attempt(job, first: true) : outcome
            end

            def reuse(job)
              outcome = attempt(job, first: true)
              outcome.lost? ? attempt(job, first: true).to_s : outcome
            end

            def bare(job)
              outcome = attempt(job, first: true)
              outcome.lost? ? attempt(job, first: true) : job
            end

            def empty(job)
              outcome = attempt(job, first: true)
              if outcome.lost?
                attempt(job, first: true)
              elsif outcome.slow?
                outcome
              else
              end
            end

            def nested(job)
              outcome = attempt(job, first: !plan.quick?)
              outcome.lost? ? attempt(job, first: !plan.quick?) : outcome
            end
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[twice reuse bare empty]))
  end

  it "tracks safe navigation, receiverless argument calls, and block passes" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def wobble
              @maybe&.load(1) + @maybe&.load(1)
            end

            def fetchy
              fetch(:host, @ttl) + fetch(:host, @ttl)
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
          "@maybe&.load(1) × 2 (line 5)", "fetch(:host, @ttl) × 2 (line 9)",
          "rows.map(&:name) × 2 (line 13)", "@io.tick(1) × 2 (lines 17, 18)"
        ]
      )
    )
  end

  it "flags identical literal blocks once, but not calls whose blocks differ" do
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

            def varied(child, assign)
              at = @kids.index { it.equal?(child) }
              [at, @kids.index { it.equal?(assign) }]
            end

            def named
              kept = @rows.map { |row| row.name }
              [kept, @rows.map { |row| row.name }]
            end

            def lambdas = [->(x) { x.succ }.call(1), ->(x) { x.succ }.call(1)]
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "transaction { save } × 2 (lines 5, 6)", "@rows.map { compute } × 2 (lines 10, 11)",
          "@rows.map { |row| row.name } × 2 (lines 20, 21)", "->(x) { x.succ }.call(1) × 2 (line 24)"
        ]
      )
    )
  end

  it "counts a name bound in two blocks as two variables, and the one name inside one block as one" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def apart(left, right)
              [left.map { it.name.upcase }, right.map { it.name.upcase }]
            end

            def sliced(rows)
              [rows.map { |list| list.size(1) }, rows.select { |list| list.size(1) }]
            end

            def numbered(left, right)
              [left.map { _1.name }, right.map { _1.name }]
            end

            def shadowed(name, rows)
              rows.each { |name| @out.puts(name.size) }
              name.size
            end

            def together(rows)
              rows.map { [it.name, it.name, it.name] }
            end

            def captured(node, rows)
              rows.map { node.name(1) } + rows.select { node.name(1) }
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["it.name × 3 (line 22)"]))
  end

  it "takes a read of it twice for style, as it does a named block variable's" do
    findings = repeated("class Thing\n  def pair(rows) = rows.map { [it.name, it.name] }\nend\n")
    expect(findings).to(be_empty)
  end

  it "counts a variable reassigned between two calls as two values" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def climb(parent)
              seen = parent.type(1)
              parent = parent.parent while parent.type(1) == :begin
              [seen, parent.type(1)]
            end

            def bumped(count)
              before = count.succ
              count += 1
              between = count.succ
              count += 1
              [before, between, count.succ]
            end

            def swapped(node, rows)
              first = node.name(1)
              rows.each { node = it }
              [first, node.name(1)]
            end

            def walked(parent)
              until parent.type(1) == :def
                parent = parent.parent
                @out.puts(parent.type(1))
              end
            end

            def steady(parent)
              while parent
                seen = parent.type(1)
                @out.puts(seen, parent.type(1))
                parent = parent.parent
              end
            end

            def fenced(node)
              first = node.name(1)
              def reset(node) = (node = nil)
              [first, node.name(1)]
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(["parent.type(1) × 2 (lines 33, 34)", "node.name(1) × 2 (lines 40, 42)"])
    )
  end

  # A modifier's condition runs before the statement written ahead of it, and
  # an instance variable assigned between two calls hands them two values.
  it "counts a variable written before a trailing condition, or an instance variable reassigned, as two values" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def opening(at)
              at += 1 if @source.char(at) == "^"
              @source.char(at) == "]" ? at + 1 : at
            end

            def unbumped(count)
              count += 1 unless @log.seen(count)
              @log.seen(count)
            end

            def active=(id)
              @flips.fetch(@active).reveal
              @active = id
              @flips.fetch(@active).conceal
            end

            def bumped
              @calls += 1
              @out.puts(@flips.fetch(@calls))
              @out.puts(@flips.fetch(@calls))
            end

            def asked(at)
              @source.char(at) if @source.char(at)
            end

            def stepped(at)
              first = @source.char(at)
              at += 1
              second = @source.char(at)
              at += 1
              [first, second, @source.char(at)]
            end

            def refetched(count)
              seen = @log.seen(count)
              @out.puts(seen) if (count = @log.next) && @log.seen(count)
            end

            def shadowed(node)
              first = node.name(1)
              @rows.each { |node| node = node.parent }
              [first, node.name(1)]
            end

            def bare(at)
              if @source.char(at)
              end
              @source.char(at)
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "@flips.fetch(@calls) × 2 (lines 22, 23)", "@source.char(at) × 2 (line 27)",
          "node.name(1) × 2 (lines 44, 46)", "@source.char(at) × 2 (lines 50, 52)"
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
              rows.map { [@io.tick(3), @io.tick(3)] }
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

  it "reports a repeated chain once, not again for each prefix repeated on the same calls, and a wider prefix alone" do
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
        ["DateTime.now.utc × 2 (line 4)", "format(@params[:id]) × 2 (line 6)", "Time.now × 3 (line 8)"]
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

  it "reads `call and return` and `call and raise` as an exit, but `or return` as a guard the run passes" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def create(file)
              rows = begin
                file.read.lines
              rescue IOError
                @view.render(:index) and return
              end
              @store.save(rows) ? @view.redirect : @view.render(:index)
            end

            def strict(rows)
              @io.tick(1) and raise(ArgumentError) if rows
              @io.tick(1) and fail
            end

            def guard(rows)
              @io.tick(2) or return
              @io.tick(2) && @log.write(rows)
              @io.tick(2) and @log.rows.raise
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["@io.tick(2) × 3 (lines 19, 20, 21)"]))
  end

  it "excuses a call inside an exit's value and its twin after the exit, which never both run" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def label(user)
              return format(user.account.name) unless user.active?
              user.account.name
            end

            def owner(record)
              return record.owner if record.orphan?
              record.owner.name
            end

            def scan(rows)
              rows.each { |row| return wrap(@io.tick(1)) if row }
              @io.tick(1)
            end

            def waited(flag)
              while flag
                return wrap(@io.tick(2)) if flag.ready?
                flag = flag.next
              end
              @io.tick(2)
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still counts a call made before the exit, one a loop brings round again, or one an ensure runs after it" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def label(user)
              shown = user.account.name
              return format(user.account.name) unless user.active?
              shown
            end

            def scan(rows)
              rows.map do |row|
                return wrap(@io.tick(1)) if row
                [row, @io.tick(1)]
              end
            end

            def polled(flag)
              while flag
                return wrap(@io.tick(2)) if flag.ready?
                flag = flag.next(@io.tick(2))
              end
            end

            def closed(one)
              return wrap(@io.tick(3)) if one
              one
            ensure
              @log.write(@io.tick(3))
            end

            def guarded(job, flag)
              before = job.status(:now)
              return if flag
              [before, job.status(:now)]
            end

            def paired(one)
              return wrap(@io.tick(4), @io.tick(4)) if one
              one
            end

            def tested(one)
              return wrap(@io.tick(5)) if @io.tick(5)
              one
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "user.account.name × 2 (lines 5, 6)", "@io.tick(1) × 2 (lines 12, 13)", "@io.tick(2) × 2 (lines 19, 20)",
          "@io.tick(3) × 2 (lines 25, 28)", "job.status(:now) × 2 (lines 32, 34)", "@io.tick(4) × 2 (line 38)",
          "@io.tick(5) × 2 (line 43)"
        ]
      )
    )
  end

  it "does not count the operand of defined?, which Ruby never evaluates" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def notify(error)
              Rails.error.report(error) if defined?(Rails.error)
              nil
            end

            def probe(error)
              Rails.error.report(error) if Rails.error
              nil
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#probe"]))
    expect(findings.flat_map(&:evidence)).to(eq(["Rails.error × 2 (line 10)"]))
  end

  it "counts two reads as two values when a command on the receiver, or a call handed it, runs between them" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def finish(job)
              before = job.status
              job.finalize!
              log(:noop) if job.status == before
            end

            def handed(job)
              before = job.status
              Finalizer.run(job)
              job.status == before
            end

            def keyed(job)
              before = job.status
              Finalizer.run(force: true, job: job)
              job.status == before
            end

            def profile(auth)
              response = http.get("/me", token: auth.token)
              return response unless response.status == 401
              auth.invalidate!
              http.get("/me", token: auth.token)
            end

            def pair(cursor)
              first = cursor.current
              cursor.advance
              [first, cursor.current]
            end

            def deep(job)
              before = job.run.status
              job.reset!
              job.run.status == before
            end

            def stamped(job)
              job.update job.status
              job.status
            end

            def assigned(job)
              before = job.status
              result = Finalizer.call(job)
              [result, job.status == before]
            end

            def stored(job)
              before = job.status
              @result = Finalizer.call(job)
              job.status == before
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still counts two reads when what runs between them leaves the receiver alone" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def logged(job)
              before = job.status(:now)
              @log.write(before)
              job.status(:now) == before
            end

            def sized(job)
              before = job.status(:now)
              Finalizer.run(job.id)
              job.status(:now) == before
            end

            def spread(job, **)
              before = job.status(:now)
              Finalizer.run(**)
              job.status(:now) == before
            end

            def apart(job, flag)
              if flag
                before = job.status(:now)
              else
                job.finalize!
              end
              job.status(:now) == before
            end

            def later(job, flag)
              before = job.status(:now)
              job.status(:now) == before
            ensure
              job.finalize!
            end

            def kept(job)
              before = job.status(:now)
              done = job.finalize!
              job.status(:now) == done
            end

            def told(job)
              before = job.status(:now)
              log(job.id)
              job.status(:now) == before
            end

            def wrapped(job)
              before = job.status(:now)
              job.log(job.status(:now) == before)
              nil
            end

            def itself(job) = [job.with(job).status, job.with(job).status]

            def shown(job) = { before: job.status(:now), text: format(job), after: job.status(:now) }

            def settled(job, flag)
              before = job.status(:now)
              label = flag ? job : before
              [label, job.status(:now)]
            end

            def updated(job)
              before = job.status(:now)
              job.update job.status(:now)
              before
            end

            def blocked(job)
              before = job.status(:now) { job.reset!; 1 }
              [before, job.status(:now) { job.reset!; 1 }]
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "job.status(:now) × 2 (lines 5, 7)", "job.status(:now) × 2 (lines 11, 13)",
          "job.status(:now) × 2 (lines 17, 19)", "job.status(:now) × 2 (lines 24, 28)",
          "job.status(:now) × 2 (lines 32, 33)", "job.status(:now) × 2 (lines 39, 41)",
          "job.status(:now) × 2 (lines 45, 47)", "job.status(:now) × 2 (lines 51, 52)",
          "job.with(job).status × 2 (line 56)", "job.status(:now) × 2 (line 58)", "job.status(:now) × 2 (lines 61, 63)",
          "job.status(:now) × 2 (lines 67, 68)",
          "job.status(:now) { job.reset!; 1 } × 2 (lines 73, 74)"
        ]
      )
    )
  end

  it "excuses generated values and reads of the last regexp match, which any match replaces" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def tokens = [Token.generate(8), Token.generate(8)]

            def found(text) = [text =~ /a/ && Regexp.last_match(1), text =~ /b/ && Regexp.last_match(1)]

            def global(text) = [text =~ /a/ && $~[1], text =~ /b/ && $~[1]]

            def numbered(text) = [text =~ /a/ && $1.to_i, text =~ /b/ && $1.to_i]

            def whole(text) = [text =~ /a/ && $&.size, text =~ /b/ && $&.size]

            def english(text) = [text =~ /a/ && $LAST_MATCH_INFO[1], text =~ /b/ && $LAST_MATCH_INFO[1]]
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still counts a repeated call on Regexp or a global other than the last match" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def escaped(text) = [Regexp.escape(text), Regexp.escape(text)]

            def stdout(text) = [$stdout.write(text), $stdout.write(text)]

            def nested(text) = [Regexp.union(text).last_match, Regexp.union(text).last_match]

            def own = [last_match(1), last_match(1)]
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "Regexp.escape(text) × 2 (line 4)", "$stdout.write(text) × 2 (line 6)",
          "Regexp.union(text).last_match × 2 (line 8)", "last_match(1) × 2 (line 10)"
        ]
      )
    )
  end

  it "compares calls only within one block, since a block may run at another time" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def watched(job)
              before = job.status
              on(:done) { notify(before, job.status) }
            end

            def nested(job)
              on(:done) { on(:fail) { notify(job.status) } && job.status }
            end

            def lambdas(job) = [-> { job.status }, -> { job.status }]
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "rates a finding low when each repeat is a cheap read: a plain reader or a literal-key lookup" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def reader(job) = [job.status, job.status, job.status]

            def keyed = [@params[:id], @params[:id], @params[:id]]

            def both(job) = [job&.status, job&.status, @params.dig(:a, :b), @params.dig(:a, :b), job&.status]
          end
        end
      end
    RUBY
    expect(findings.map(&:confidence)).to(eq(%i[low low low]))
  end

  it "keeps clock reads, reach-through chains, and calls with blocks or computed keys at full confidence" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def stamped = [Time.now, Time.now]

            def current = [Time.current, Time.current]

            def dated = [Date.current, Date.current]

            def today = [Date.today, Date.today]

            def ticked = [clock.now, clock.now]

            def spun = [Process.clock_gettime(1), Process.clock_gettime(1)]

            def chained(job) = [job.run.status, job.run.status]

            def computed(key) = [@params[key], @params[key]]

            def mixed(key) = [@params[:id], @params[:id], @params[key], @params[key]]

            def passed(rows) = [rows.map(&:name), rows.map(&:name)]

            def called = [compute(1), compute(1)]

            def cursor(page) = [page.current, page.current, page.current]
          end
        end
      end
    RUBY
    expect(findings.map(&:confidence)).to(eq(([nil] * 11) + [:low]))
  end

  it "rates a repeat low when one of the pair is a parameter default, which runs only when the argument is left out" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def run(at: clock.now)
              schedule(at, clock.now)
            end

            def twice(at: clock.now)
              schedule(at, clock.now, clock.now)
            end

            def plain(at)
              schedule(at, clock.now, clock.now)
            end
          end
        end
      end
    RUBY
    expect(findings.map { [it.package, it.confidence] }).to(
      eq([["App::Zone::Thing#run", :low], ["App::Zone::Thing#twice", nil], ["App::Zone::Thing#plain", nil]])
    )
  end

  it "collapses chains that share a repeated prefix into the prefix, which one local fixes, and prints an index read" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def deliver(qm)
              [qm.message.scope, qm.message.scope, qm.message.rcpt_to, qm.message.rcpt_to, qm.message.id]
            end

            def show = [params[:user], params[:user]]

            def keep(qm) = [qm.message.scope, qm.message.scope]
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence))
      .to(eq(["qm.message × 5 (line 5)", "params[:user] × 2 (line 8)", "qm.message.scope × 2 (line 10)"]))
  end
end
