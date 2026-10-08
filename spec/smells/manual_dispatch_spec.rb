# frozen_string_literal: true

RSpec.describe(Hashira::Smells::ManualDispatch) do
  it "flags respond_to? probes and lists every probing line" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            class Thing
              def poke(duck)
                duck.honk if duck.respond_to?(:honk)
                duck.moo if duck.respond_to?(:moo)
              end

              def plain(duck) = duck.honk
            end
          end
        end
      RUBY
    }
    findings = sniffed(files, "manual_dispatch")
    expect(findings.size).to(eq(1))
    expect(findings.first.package).to(eq("App::Zone::Thing#poke"))
    expect(message(findings.first)).to(include("dispatches manually via respond_to?", "zone/thing.rb:5, 6"))
  end

  it "flags a bare capability check, but not a proxy's method_missing and respond_to_missing? pair" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            class Thing
              def method_missing(name, *) = @target.respond_to?(name) ? @target.public_send(name, *) : super

              def respond_to_missing?(name, all = false) = @target.respond_to?(name, all) || super

              def probe(duck) = duck.respond_to?(:honk)
            end

            class Half
              def method_missing(name, *) = @target.respond_to?(name) ? @target.public_send(name, *) : super
            end
          end
        end
      RUBY
    }
    expect(sniffed(files, "manual_dispatch").map(&:package)).to(
      eq(%w[App::Zone::Thing#probe App::Zone::Half#method_missing])
    )
  end

  def dispatched(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "manual_dispatch")

  it "lets Ruby's conversion, IO and enumeration protocols be probed" do
    findings = dispatched(<<~RUBY)
      module App
        module Zone
          class Thing
            def release(body)
              body.close if body.respond_to?(:close)
              body.rewind if body.respond_to?(:rewind)
              body.read if body.respond_to?(:read)
              body.pos if body.respond_to?(:pos)
            end

            def coerce(value)
              return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
              return value.to_hash if value.respond_to?(:to_hash)
              value.each { @seen << it } if value.respond_to?(:each)
              value.call if value.respond_to?(:call)
            end

            def named(duck, name) = duck.respond_to?(name)

            def blank(duck) = duck.respond_to?
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#named App::Zone::Thing#blank]))
  end

  it "lets a rescued library exception or another library object be probed, but not one the codebase raises" do
    findings = dispatched(<<~RUBY)
      module App
        module Zone
          class Failure < StandardError; end

          class Thing
            def fetch
              @http.get
            rescue => e
              @log.warn(e.code) if e.respond_to?(:code)
            end

            def named
              @http.get
            rescue Faraday::Error => error
              error.response if error.respond_to?(:response)
            end

            def ours
              @http.get
            rescue Failure => error
              error.response if error.respond_to?(:response)
            end

            def fetched(url)
              reply = Faraday.get(url)
              reply.headers if reply.respond_to?(:headers)
            end

            def guarded(node)
              return unless node.is_a?(Prism::CallNode)
              node.block if node.respond_to?(:block)
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#ours]))
  end

  it "takes a probe for a core value's method as a nil or type check in disguise, unless the codebase defines it" do
    findings = dispatched(<<~RUBY)
      module App
        module Zone
          class Thing
            def limit(value) = value.respond_to?(:positive?) && value.positive?

            def size(value) = value.respond_to?(:zero?) && value.zero?
          end

          class Counter
            def zero? = @count.zero?
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#size]))
  end

  it "doubts a probe on what the request carries, and trusts one on self, an ivar or an injected collaborator" do
    findings = dispatched(<<~RUBY)
      module App
        module Zone
          class Thing
            def upload = params[:file].respond_to?(:honk)

            def body
              raw = request.body
              copy = raw
              copy.respond_to?(:honk)
            end

            def mine = respond_to?(:honk) && self.respond_to?(:moo)

            def held = @duck.respond_to?(:honk)

            def initialize(store)
              @store = store
              store.respond_to?(:honk)
            end

            def handed(duck) = duck.respond_to?(:honk)

            def looped
              node = node.parent
              node.respond_to?(:honk)
            end

            def helped = helper.respond_to?(:honk)

            def built
              raw = params[:file]
              duck = @factory.build(raw)
              duck.respond_to?(:honk)
            end

            def mixed(duck) = respond_to?(:honk) && duck.respond_to?(:honk)

            def partly(duck) = params.respond_to?(:honk) && duck.respond_to?(:honk)
          end
        end
      end
    RUBY
    expect(findings.to_h { [it.package.split("#").last, it.confidence] }).to(
      eq(
        "upload" => :low, "body" => :low, "mine" => :high, "held" => :high, "initialize" => :high,
        "handed" => nil, "looped" => nil, "helped" => nil, "built" => nil, "mixed" => nil, "partly" => nil
      )
    )
  end

  it "flags a case or is_a? ladder over two or more of the codebase's own classes" do
    findings = dispatched(<<~RUBY)
      module App
        module Zone
          class Circle; end
          class Square; end
          LIMIT = 1
          OTHER = 2

          class Thing
            def area(shape)
              case shape
              when Circle then @pi
              when Square then @side
              end
            end

            def edges(shape)
              if shape.is_a?(Circle)
                0
              elsif shape.kind_of?(App::Zone::Square)
                4
              end
            end

            def lone(shape) = shape.is_a?(Circle) ? @pi : @side

            def bounded(count)
              case count
              when LIMIT then @a
              when OTHER then @b
              end
            end

            def parsed(node)
              case node
              when Prism::CallNode then @a
              when Prism::DefNode then @b
              end
            end

            def own = is_a?(Circle) || is_a?(Square) || is_a?
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#area App::Zone::Thing#edges]))
    expect(findings.map(&:evidence)).to(
      eq([["shape: Circle, Square (lines 11, 12)"], ["shape: Circle, App::Zone::Square (lines 17, 19)"]])
    )
    expect(message(findings.first)).to(
      include("dispatches manually via a type check (zone/thing.rb:11, 12)", "let polymorphism pick")
    )
  end

  it "flags a case over a status, state, type or kind value with two or more literal arms" do
    findings = dispatched(<<~RUBY)
      module App
        module Zone
          class Thing
            def label(order)
              case order.status
              when :paid then @paid
              when :open, :held then @open
              end
            end

            def step
              case @state
              when "a" then @a
              when "b" then @b
              end
            end

            def pick(payment_kind)
              case payment_kind
              when 1 then @a
              when 2 then @b
              end
            end

            def paint(color)
              case color
              when :red then @a
              when :blue then @b
              end
            end

            def single(status)
              case status
              when :paid then @a
              when PAID then @b
              end
            end

            def loose
              case
              when @a then @b
              when @c then @d
              end
            end

            def computed(order)
              case order.kinds.first
              when :a then @a
              when :b then @b
              end
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#label App::Zone::Thing#step App::Zone::Thing#pick]))
    expect(findings.first.evidence).to(eq(["order.status: :paid, :open, :held (lines 6, 7)"]))
    expect(message(findings.first)).to(include("dispatches manually via a status switch"))
  end

  it "names every way one method dispatches, and leaves the confidence to the switch" do
    findings = dispatched(<<~RUBY)
      module App
        module Zone
          class Circle; end
          class Square; end

          class Thing
            def draw(shape, kind)
              return @canvas.paint(shape) if respond_to?(:paint)
              case shape
              when Circle then @a
              when Square then @b
              end
              case kind
              when :a then @a
              when :b then @b
              end
            end
          end
        end
      end
    RUBY
    finding = findings.first
    expect(message(finding)).to(
      include("via respond_to? and a type check and a status switch (zone/thing.rb:8, 10, 11, 14, 15)")
    )
    expect(finding.confidence).to(be_nil)
  end
end
