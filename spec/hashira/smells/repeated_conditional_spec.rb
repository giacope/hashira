# frozen_string_literal: true

RSpec.describe(Hashira::Smells::RepeatedConditional, :aggregate_failures) do
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
    expect(findings.map { [it.package, it.evidence] })
      .to(eq([["App::Zone::Thing", ["@mode == :x × 3 (lines 4, 7, 12)"]]]))
    expect(message(findings.first)).to(include("branches on the same test 3 times", "zone/thing.rb:3"))
  end

  it "tolerates two repeats, plain truth tests, and predicateless cases" do
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

            def epsilon = @ready ? (@ready ? 1 : 2) : (@ready ? 3 : 4)

            def zeta = @mode == @last ? (@mode == @last ? 1 : 2) : (@mode == @last ? 3 : 4)

            def eta = @modes.include?(:x) ? (@modes.include?(:x) ? 1 : 2) : (@modes.include?(:x) ? 3 : 4)
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
            def a = @m == :on ? 1 : 2

            def b = @m == :on ? 3 : 4

            def c = @m == :on ? 5 : 6
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
            def alpha(all) = all == 0 ? 1 : 2

            def beta(all) = all == 0 ? 3 : 4

            def gamma(all) = all == 0 ? 5 : 6

            def delta(rows)
              return 1 if rows.size == 0
              rows.map { it.size == 0 ? 0 : 1 }
              rows.size == 0 ? 2 : 3
            end

            def epsilon(rows)
              rows.each { tick unless it == :skip }
              rows.each { tock unless it == :skip }
              rows.each { tuck unless it == :skip }
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
              return (all == 1 ? 1 : 2) if all == 1
              all == 1 ? 3 : 4
            end

            def beta
              return (@mode == 1 ? 1 : 2) if @mode == 1
              @mode == 1 ? 3 : 4
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["all == 1 × 3 (lines 5, 6)", "@mode == 1 × 3 (lines 10, 11)"]))
  end

  it "counts a test on the object's own state across blocks too, lines in order" do
    findings = branching(<<~RUBY)
      module App
        module Zone
          class Thing
            def alpha(rows)
              rows.map { @mode == :on ? 1 : 2 }
              return 3 if @mode == :on
              rows.map { |row| row.size if @mode == :on }
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["@mode == :on × 3 (lines 5, 6, 7)"]))
  end

  it "judges a reopened class once, across every file that opens it" do
    findings = sniffed(
      {
        "lib/app/zone/thing.rb" => "class Thing\n  def a = @m == 1 ? 1 : 2\n\n  def b = @m == 1 ? 3 : 4\nend\n",
        "lib/app/zone/thing/more.rb" => "class Thing\n  def c = @m == 1 ? 5 : 6\nend\n"
      },
      "repeated_conditional"
    )
    expect(findings.size).to(eq(1))
    expect(findings.first.detail[:site]).to(eq("thing.rb:1"))
    expect(findings.first.evidence).to(eq(["@m == 1 × 3 (lines 2, 4)"]))
  end

  it "splits compound tests into their parts, so a flag tested alone and inside an || counts each time" do
    findings = branching(<<~RUBY)
      module App
        module Zone
          class Stream
            def read = @state == :closed ? nil : @io.read

            def write(text)
              @io.write(text) unless !(@state == :closed)
            end

            def pump
              return if @state == :closed || @exited
              @io.pump
            end
          end

          class Gate
            def a = (@kind == :open && @ready) ? 1 : 2

            def b = (@kind == :open && @ready) ? 3 : 4

            def c = (@kind == :open && @ready) ? 5 : 6

            def d = (not @shut) ? 7 : 8

            def e = () ? 9 : 10
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(["@state == :closed × 3 (lines 4, 7, 11)", "@kind == :open × 3 (lines 17, 19, 21)"])
    )
  end

  it "ignores tests that query the database or the file system, whose answer can change between checks" do
    findings = branching(<<~RUBY)
      module App
        module Zone
          class Thing
            def a = Lock.exists?(@key) == true ? 1 : 2

            def b = Lock.exists?(@key) == true ? 3 : 4

            def c = Lock.exists?(@key) == true ? 5 : 6

            def d = Order.where(id: @id).count == 0 ? 1 : 2

            def e = Order.where(id: @id).count == 0 ? 3 : 4

            def f = Order.where(id: @id).count == 0 ? 5 : 6

            def g = File.exist?(@path) == true ? 1 : 2

            def h = File.exist?(@path) == true ? 3 : 4

            def i = File.exist?(@path) == true ? 5 : 6

            def j = User.find_by(id: @id) == nil ? 1 : 2

            def k = User.find_by(id: @id) == nil ? 3 : 4

            def l = User.find_by(id: @id) == nil ? 5 : 6
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "ignores a recheck after a command on its receiver, or inside a block it runs (double-checked locking)" do
    findings = branching(<<~RUBY)
      module App
        module Zone
          class Thing
            def claim
              return false if @job.state == :claimed
              @job.lock!
              return false if @job.state == :claimed
              @job.claim!
            end

            def run
              return if @job.state == :claimed
              @job.with_lock do
                return if @job.state == :claimed
                work
              end
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  # A trailing condition runs before the statement written ahead of it, and an
  # argument before the call it is passed to, so neither is a recheck after it.
  it "counts a test in a trailing condition or in a command's argument as made before that command" do
    findings = branching(<<~RUBY)
      module App
        module Zone
          class Thing
            def claim
              @job.claim! if @job.state == :open
              true
            end

            def mark
              @job.mark(@job.state == :open ? 1 : 2)
              true
            end

            def run = @job.state == :open ? 1 : 2
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["@job.state == :open × 3 (lines 5, 10, 14)"]))
  end

  it "still counts a recheck when nothing on the receiver changed before it in that method" do
    findings = branching(<<~RUBY)
      module App
        module Zone
          class Thing
            def claim
              @job.lock!
            end

            def run
              return if @job.state == :claimed
              @log.write(1)
              kept = @job.reload
              touched = @job.each(&:touch)
              return if @job.state == :claimed
              done = @job.with_lock { work }
              @job.state == :claimed ? [kept, touched, done] : nil
            end

            def again
              @job.claim!
              state == :claimed ? 1 : 2
            end

            def other = state == :claimed ? 1 : 2

            def more = state == :claimed ? 1 : 2

            def release
              return if @job.state == :claimed
              @job.unlock!
              true
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(["@job.state == :claimed × 4 (lines 9, 13, 15, 28)", "state == :claimed × 3 (lines 20, 23, 25)"])
    )
  end

  it "counts type tests and the subject a case dispatches on, the tests polymorphism would replace" do
    findings = branching(<<~RUBY)
      class Billing
        def total = @owner.is_a?(Org) ? 1 : 2

        def label = @owner.is_a?(Org) ? "org" : "user"

        def mail = (@owner.is_a?(Org) ? 3 : 4) if @plan != Plan::FREE

        def fee = case @plan when Plan::FREE then 0 else 1 end

        def cap = case @plan when Plan::FREE then 0 else 1 end

        def tax = case @plan when Plan::FREE then 0 else 1 end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(["@owner.is_a?(Org) × 3 (lines 2, 4, 6)", "@plan × 3 (lines 8, 10, 12)"])
    )
  end
end
