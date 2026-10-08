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
              [rows.map { |list| list.size }, rows.select { |list| list.size }]
            end

            def numbered(left, right)
              [left.map { _1.name }, right.map { _1.name }]
            end

            def shadowed(name, rows)
              rows.each { |name| @out.puts(name.size) }
              name.size
            end

            def together(rows)
              rows.map { [it.name, it.name] }
            end

            def captured(node, rows)
              rows.map { node.name } + rows.select { node.name }
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["it.name × 2 (line 22)"]))
  end

  it "counts a variable reassigned between two calls as two values" do
    findings = repeated(<<~RUBY)
      module App
        module Zone
          class Thing
            def climb(parent)
              seen = parent.type
              parent = parent.parent while parent.type == :begin
              [seen, parent.type]
            end

            def bumped(count)
              before = count.succ
              count += 1
              between = count.succ
              count += 1
              [before, between, count.succ]
            end

            def swapped(node, rows)
              first = node.name
              rows.each { node = it }
              [first, node.name]
            end

            def walked(parent)
              until parent.type == :def
                parent = parent.parent
                @out.puts(parent.type)
              end
            end

            def steady(parent)
              while parent
                seen = parent.type
                @out.puts(seen, parent.type)
                parent = parent.parent
              end
            end

            def fenced(node)
              first = node.name
              def reset(node) = (node = nil)
              [first, node.name]
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["parent.type × 2 (lines 33, 34)", "node.name × 2 (lines 40, 42)"]))
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
              before = job.status
              return if flag
              [before, job.status]
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
          "@io.tick(3) × 2 (lines 25, 28)", "job.status × 2 (lines 32, 34)", "@io.tick(4) × 2 (line 38)",
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
              before = job.status
              @log.write(before)
              job.status == before
            end

            def sized(job)
              before = job.status
              Finalizer.run(job.id)
              job.status == before
            end

            def spread(job, **)
              before = job.status
              Finalizer.run(**)
              job.status == before
            end

            def apart(job, flag)
              if flag
                before = job.status
              else
                job.finalize!
              end
              job.status == before
            end

            def later(job, flag)
              before = job.status
              job.status == before
            ensure
              job.finalize!
            end

            def kept(job)
              before = job.status
              done = job.finalize!
              job.status == done
            end

            def told(job)
              before = job.status
              log(job.id)
              job.status == before
            end

            def wrapped(job)
              before = job.status
              job.log(job.status == before)
              nil
            end

            def itself(job) = [job.with(job).status, job.with(job).status]

            def shown(job) = { before: job.status, text: format(job), after: job.status }

            def settled(job, flag)
              before = job.status
              label = flag ? job : before
              [label, job.status]
            end

            def updated(job)
              before = job.status
              job.update job.status
              before
            end

            def blocked(job)
              before = job.status { job.reset!; 1 }
              [before, job.status { job.reset!; 1 }]
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "job.status × 2 (lines 5, 7)", "job.status × 2 (lines 11, 13)", "job.status × 2 (lines 17, 19)",
          "job.status × 2 (lines 24, 28)", "job.status × 2 (lines 32, 33)", "job.status × 2 (lines 39, 41)",
          "job.status × 2 (lines 45, 47)", "job.status × 2 (lines 51, 52)",
          "job.with(job).status × 2 (line 56)", "job.status × 2 (line 58)", "job.status × 2 (lines 61, 63)",
          "job.status × 2 (lines 67, 68)",
          "job.status { job.reset!; 1 } × 2 (lines 73, 74)"
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
            def reader(job) = [job.status, job.status]

            def keyed = [@params[:id], @params[:id], fetch("host"), fetch("host")]

            def both(job) = [job&.status, job&.status, params.dig(:a, :b), params.dig(:a, :b)]
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

            def cursor(page) = [page.current, page.current]
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
end
