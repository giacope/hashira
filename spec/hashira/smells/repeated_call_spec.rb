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

  it "reads a call to a reader the class or an ancestor declares as the instance variable it reads, plain or keyed" do
    findings = sniffed(
      {
        "lib/app/base.rb" => <<~RUBY,
          module App
            class Base
              def initialize(options) = @options = options

              private

              attr_reader :options
            end
          end
        RUBY
        "lib/app/titled.rb" => <<~RUBY,
          module App
            module Titled
              attr_accessor :title
            end
          end
        RUBY
        "lib/app/page.rb" => <<~RUBY
          module App
            class Page < Base
              include Titled
              attr_reader :guide

              def plain = [guide.slug, guide.slug]
              def keyed = [options[:on], options[:on]]
              def mixed = [title.size, title.size]
              def selfish = [self.guide.slug, self.guide.slug]
              def thrice = [guide.slug, guide.slug, guide.slug]
              def helper = [found.slug, found.slug]
              def chained = [guide.topic.path, guide.topic.path]
              def called = [guide(1).slug, guide(1).slug]
              def blocked = [guide { 1 }.slug, guide { 1 }.slug]
              def shifted = [guide.state, guide.advance!, guide.state, guide.advance!, guide.state]
              def other(peer) = [guide.state, peer.advance!, guide.state, peer.advance!, guide.state]
              def found = Guide.find(@id)
            end
          end
        RUBY
      },
      "repeated_call"
    )
    expect(findings.map(&:package)).to(eq(%w[thrice helper chained called blocked other].map { "App::Page##{it}" }))
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

  it "takes a call that holds a measured reading for a new value each time, as the reading is, not an unmeasured one" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def read_exactly(clock, size)
              deadline = clock.now(:ms) + @timeout
              while @data.size < size
                remaining = deadline - clock.now(:ms)
                @socket.wait(remaining)
                @socket.wait([deadline - clock.now(:ms), 0].max) if @socket.blocked?
              end
            end

            def stamped(clock)
              deadline = clock.now(:ms) + @timeout
              [deadline, clock.now(:ms).to_s, clock.now(:ms).to_s]
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["clock.now(:ms) × 3 (lines 14, 15)"]))
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

  it "excuses reads that draw the next item from a stream or a queue, which each call consumes" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def handshake
              status = @socket.gets("\\n")
              while (line = @socket.gets("\\n"))
                break if line == "\\r\\n"
              end
              status
            end

            def pair(queue) = [queue.pop, queue.pop, queue.shift, queue.shift, queue.deq, queue.deq]

            def chunks = [@io.readpartial(512), @io.readpartial(512), @io.read_nonblock(9), @io.read_nonblock(9)]

            def bytes = [@io.getc, @io.getc, @io.getbyte, @io.getbyte, @io.readline, @io.readline]

            def heads(items) = [items.first(2), items.first(2)]

            def lines(path) = [File.readlines(path), File.readlines(path)]
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[heads lines]))
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

  it "ends a run at a raise and a block's run at next or break, held or a statement after the first read" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def linked(children, orphaned)
              children.each do |child|
                orphaned << child.slug(1) && next if child.orphan?
                orphaned << child.slug(1) && break if child.stale?
                child.adopt
              end
            end

            def skipped(children)
              children.each do |child|
                if child.orphan?
                  @finder.skip(child.parent(2))
                  next
                end
                @finder.keep(child.parent(2))
              end
            end

            def returned(child)
              if child.orphan?
                @finder.skip(child.parent(3))
                return
              end
              @finder.keep(child.parent(3))
            end

            def raised(attrs)
              raise ArgumentError, "no gss for \#{@store.name(4)}" if attrs.blank?
              @store.put(@store.name(4))
            end

            def read(size, sink)
              while size > 0
                chunk = @socket.read(size) || raise(EOFError)
                size -= sink.write(chunk)
                sink.write(@socket.read(2) || raise(EOFError))
              end
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still counts a read an exit does not end the run of: a loop brings it round, a rescue catches the raise" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def hoisted(children)
              children.each do |child|
                if child.orphan?
                  @finder.skip(@config.limit(1))
                  next
                end
                @finder.keep(@config.limit(1))
              end
            end

            def inner(rows)
              rows.each do |row|
                while row.more?
                  @log.write(row.peek(2))
                  next
                end
                @log.write(row.peek(2))
              end
            end

            def rescued(attrs)
              begin
                raise ArgumentError, "no gss for \#{@store.name(3)}" if attrs.blank?
              rescue ArgumentError
                nil
              end
              @store.put(@store.name(3))
            end

            def chained(ready)
              @log.write(@store.name(4))
              ready && return
              @store.put(@store.name(4))
            end

            def modified(attrs)
              (raise ArgumentError, @store.name(5) if attrs.blank?) rescue nil
              @store.put(@store.name(5))
            end

            def caught(attrs)
              begin
                @store.name(6) and raise(ArgumentError)
              rescue ArgumentError
                nil
              end
              @store.put(@store.name(6))
            end

            def looping(rows)
              rows.each do |row|
                while row.more?
                  @log.write(row.peek(7)) && next
                end
                @log.write(row.peek(7))
              end
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "@config.limit(1) × 2 (lines 7, 10)", "row.peek(2) × 2 (lines 17, 20)", "@store.name(3) × 2 (lines 26, 30)",
          "@store.name(4) × 2 (lines 34, 36)", "@store.name(5) × 2 (lines 40, 41)", "@store.name(6) × 2 (lines 46, 50)",
          "@log.write(row.peek(7)) × 2 (lines 56, 58)"
        ]
      )
    )
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
          "job.status(:now) × 2 (lines 45, 46)", "job.with(job).status × 2 (line 50)",
          "job.status(:now) × 2 (line 52)", "job.status(:now) × 2 (lines 55, 57)",
          "job.status(:now) × 2 (lines 61, 62)", "job.status(:now) { job.reset!; 1 } × 2 (lines 67, 68)"
        ]
      )
    )
  end

  it "counts two reads as two values when a call that consumes or changes the receiver runs between, kept or not" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def walk(path, node)
              while path.size > 0
                step = path.shift
                node = node.child(step) if path.size > 0
              end
              node
            end

            def kept(job)
              before = job.status(:now)
              done = job.finalize!
              job.status(:now) == done
            end

            def drained(queue)
              [queue.size, queue.pop, queue.size]
            end

            def grown(items, item)
              before = items.count(:open)
              total = items << item
              [before, total, items.count(:open)]
            end

            def asked(path, node)
              while path.size > 0
                step = path.first
                node = node.child(step) if path.size > 0
              end
              node
            end

            def other(path, queue)
              before = path.size.succ
              queue.shift
              [before, path.size.succ]
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(["path.size.>(0) × 2 (lines 29, 31)", "path.size.succ × 2 (lines 37, 39)"])
    )
  end

  it "parts two reads around a bang or a change sent by name, literal or with a literal tail" do
    reads = ->(between) { "[object.state(:now), #{between}, object.state(:now)]" }
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Probe
            def computed(object, event) = #{reads['object.send("#{event}!")']}
            def literal(object) = #{reads["object.send(:launch!)"]}
            def worded(object) = #{reads['object.send("launch!")']}
            def sent(object, event) = #{reads['object.public_send(:"#{event}!")']}
            def raw(object, item) = #{reads["object.__send__(:<<, item)"]}
            def variable(object, name) = #{reads["object.send(name)"]}
            def asked(object, event) = #{reads['object.send("#{event}?")']}
            def plain(object) = #{reads["object.send(:launch)"]}
            def handle(object) = #{reads["object.method(:launch!)"]}
            def bare(object) = #{reads["object.send"]}
            def other(object, peer) = #{reads["peer.send(:launch!)"]}
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[variable asked plain handle bare other].map { "App::Zone::Probe##{it}" }))
  end

  it "parts reads of an instance variable around a call on self whose method moves it, however deep" do
    reads = ->(between) { "[@scanner.pos, #{between}, @scanner.pos, #{between}, @scanner.pos]" }
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Lexer
            attr_reader :scanner

            def initialize(text) = @scanner = StringScanner.new(text)

            def helped = #{reads["word"]}
            def deep = #{reads["step"]}
            def selfish = #{reads["self.word"]}
            def reset = #{reads["restart"]}
            def asked = #{reads["done?"]}
            def same = #{reads["at"]}
            def other = #{reads["note"]}
            def cleared = #{reads["clear"]}
            def foreign = #{reads["advance"]}
            def elsewhere = #{reads["@peer.word"]}
            def reader = [scanner.pos, skip, scanner.pos, skip, scanner.pos]
            def peeked = #{reads["ahead"]}
            def skipped = #{reads["blank"]}
            def returned = #{reads["back"]}

            private

            def word = @scanner.scan(/\\w+/)
            def step = word
            def restart = @scanner = StringScanner.new("")
            def done? = @scanner.eos?
            def at = @scanner.pos
            def note = @log.write(1)
            def clear = @log = []
            def skip = scanner.scan(/ /)
            def ahead = "\#{@scanner.peek(1)}!"

            def blank
              @scanner.skip(/ +/)
              true
            end

            def back
              return @scanner.scan(/x/) if @flag

              nil
            end
          end
        end
      end
    RUBY
    shown = findings.flat_map(&:evidence).map { it[/\A\S+/] }
    expect(shown).to(eq((%w[@scanner.pos] * 6) + %w[scanner.pos @scanner.pos]))
    expect(findings.flat_map(&:evidence).map { it[/lines? (\d+)/, 1] }).to(eq(%w[12 13 14 15 16 17 18 19]))
  end

  it "reads __LINE__ as the line it is written on, so the same text on two lines is two values" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Builder
            def build
              @mod.class_eval(@first, __FILE__, __LINE__ + 1)
              @mod.class_eval(@second, __FILE__, __LINE__ + 1)
            end

            def twice = [__LINE__ + 1, __LINE__ + 1]

            def named = [File.basename(__FILE__), File.basename(__FILE__)]
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "__LINE__.+(1) × 2 (line 9)",
          "File.basename(__FILE__) × 2 (line 11)"
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
