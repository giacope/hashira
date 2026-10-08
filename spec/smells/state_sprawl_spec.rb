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

  it "does not flag a handle whose fields the methods use together" do
    findings = crowded(<<~RUBY)
      module App
        module Zone
          class Stream
            def initialize(socket, &on_event)
              @socket = socket
              @reader = Reader.new(socket)
              @on_event = on_event
              @closed = false
              @exited = false
            end

            def each_event
              until @closed || @exited
                @on_event.call(@reader.next)
              end
            end

            def close
              @closed = true
              @socket.close
            end

            def exit! = @exited = true

            def self.open(path) = new(path)
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags constructor state that falls apart into separate groups across the methods" do
    findings = crowded(<<~RUBY)
      module App
        module Zone
          class Stream
            def initialize(socket, log)
              @socket = socket
              @reader = Reader.new(socket)
              @log = log
              @level = 1
              @closed = false
            end

            def each_event = @reader.each { @socket.ping unless @closed }

            def note(text)
              @log.write(text) if @level > 0
            end
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(%w[@closed @level @log @reader @socket]))
  end

  it "weighs a field first assigned outside the constructor double: an intermediate result parked between methods" do
    findings = crowded(<<~RUBY)
      module App
        module Zone
          class Import
            def initialize(path)
              @path = path
            end

            def run
              @rows = File.readlines(@path)
              @valid = @rows.select(&:ok?)
              summarize
            end

            def summarize = @summary = @valid.size

            def self.cache = @cache = {}
          end
        end
      end
    RUBY
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(message(finding)).to(include("holds 5 instance variables"))
    expect(finding.evidence).to(eq(%w[@cache @path @rows @summary @valid]))
  end

  def assigns(base)
    crowded(<<~RUBY)
      class Orders < #{base}
        def show
          @order = Order.find(params[:id])
          @items = @order.items
        end

        def edit = @form = OrderForm.new(@order)
      end
    RUBY
  end

  it "does not weigh a view's assigns double: a controller, mailer or component action hands them to a template" do
    expect(%w[ApplicationController ApplicationMailer Admin::BaseComponent].flat_map { assigns(it) }).to(be_empty)
  end

  it "weighs the same actions double on a class that renders no view" do
    expect(assigns("Pipeline::Step").map(&:package)).to(eq(["Orders"]))
  end

  it "counts a field a constructor helper assigns, or one set in the class body, as constructor state" do
    findings = crowded(<<~RUBY)
      module App
        module Zone
          class Index
            @registry = {}

            def self.reset = @registry = {}

            def initialize(rows)
              @rows = rows
              @size = rows.size
              build
            end

            def find(key) = @by_key[key] || @rows.first

            private

            def build
              @by_key = @rows.to_h { [it.key, it] }
            end
          end

          class Parked
            def initialize(rows)
              @rows = rows
            end

            def find(key) = @by_key[key] || @other

            def warm
              @by_key = @rows.to_h { [it.key, it] }
              @other = @rows.last
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Parked"]))
  end
end
