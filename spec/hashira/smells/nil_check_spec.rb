# frozen_string_literal: true

RSpec.describe(Hashira::Smells::NilCheck, :aggregate_failures) do
  def checked(source, rules: Hashira::Config::Rules::ALL)
    sniffed({ "lib/app/zone/thing.rb" => source }, "nil_check", rules:)
  end
  it "flags nil?, nil comparisons, and when-nil clauses with their lines" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            private

            def query(x) = x.nil? && @a

            def compare(x) = x == nil || nil == x

            def strict(x) = x === nil

            def branch(x)
              case x
              when nil then @a
              else @b
              end
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(%w[App::Zone::Thing#query App::Zone::Thing#compare App::Zone::Thing#strict App::Zone::Thing#branch])
    )
    expect(message(findings.first)).to(include("checks for nil", "zone/thing.rb:6"))
  end

  it "takes a bare call's nil for the project's only when the class or its owned ancestors answer it" do
    source = <<~RUBY
      module App
        class Error < StandardError
          class << self
            def label = name.nil? ? "anonymous" : name
            def code = slug.nil? ? 0 : slug
            def slug = nil
          end
        end

        module Labels
          def tag = title.nil? ? "none" : title
        end

        class Item
          def initialize(title) = @title = title
          def name = @title
          def title = @title
        end
      end
    RUBY
    findings = sniffed({ "lib/app/error.rb" => source }, "nil_check")
    expect(findings.map(&:package)).to(eq(%w[App::Error.code App::Labels#tag]))
  end

  it "takes a reader that answers a literal, or memoizes one, for a value that is never nil" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def successors = @successors ||= {}

            def states
              @states ||= []
            end

            def label = "thing"

            def lazy = @lazy ||= load

            def guarded
              return if @off
              @guarded ||= []
            end

            def drop(from) = successors.nil? ? @a : successors.delete(from)
            def known(state) = states.nil? ? @a : states.include?(state)
            def shown = label.nil? ? @a : label
            def loaded = lazy.nil? ? @a : lazy
            def watched = guarded.nil? ? @a : guarded
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#loaded App::Zone::Thing#watched]))
  end

  it "leaves a nil to Ruby when an owned constant only holds a core value, and owns what an owned class answers" do
    findings = checked(<<~'RUBY')
      module App
        module Zone
          class Thing
            PATTERN = %r{\A/(?<slug>[a-z]+)\z}
            NAMES = %w[a b].freeze

            def initialize(text) = @text = text

            def slug
              parts = PATTERN.match(@text)
              parts.nil? ? "" : parts[:slug]
            end

            def name = NAMES.first.nil? ? "" : @text

            def found = Finder.lookup(@text).nil? ? "" : @text
          end

          class Finder
            def self.lookup(text) = text
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Thing#found]))
  end

  it "reaches methods defined inside blocks and class << self" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            concerning :Checks do
              def check = @a.nil?
            end

            class << self
              def peek = @cache.nil?
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#check", "App::Zone::Thing.peek"]))
  end

  it "leaves a value that arrives from outside to the boundary: a public argument, a payload, a library's answer" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def keyed(params) = params[:name].nil?

            def header(request)
              token = request.headers["X-Token"]
              token.nil?
            end

            def parsed(body)
              data = JSON.parse(body)
              case data
              when nil then @a
              end
            end

            def handed(value) = value.nil?

            def ruled(node) = node.receiver.nil?

            def flipped(params) = nil == params[:name]

            def mixed(params) = params["id"] == nil || @cache.nil?

            def optional(given, rest = nil) = given.nil?

            def self.parse(text) = text.nil?

            module_function

            def shared(text) = text.nil?
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#mixed"]))
    expect(findings.first.detail[:site]).to(eq("zone/thing.rb:24"))
  end

  it "flags a value the method built or fetched from an owned class, but not a nil it never named" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def built
              result = { id: nil }
              result[:id].nil?
            end

            def mine = nil?

            def owned
              record = Thing.find(1)
              record.nil?
            end

            def blind
              case
              when nil then @a
              end
            end

            def resolved(dependency) = dependency.target.nil?

            def looked = lookup.nil?

            private

            def lookup = @index

            def unknown(dependency) = dependency.source.nil?
          end

          class Dependency
            attr_reader :target
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[built owned resolved looked]))
  end

  it "ignores comparisons that never involve nil" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            private

            def fine(x)
              case x
              when :a then @a
              else x == :b ? @b : @c
              end
            end

            def odd(x) = x.==
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "skips a validator's guard on attributes a presence validation or a required belongs_to already reports" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Booking
            validates :starts_at, :ends_at, presence: true
            validates_presence_of :room
            belongs_to :owner
            validate :ordered
            validate :owned, :roomy, :logged
            before_save
            private

            def ordered
              return if starts_at.nil? || ends_at.nil?
              errors.add(:ends_at, :before_start) if ends_at < starts_at
            end

            def owned = owner.nil? || owner_id.nil?

            def logged
              log.add(:skipped) if starts_at.nil?
            end

            def roomy = room.nil?
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags a nil check no presence validation answers for, or one that reports the error itself" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Booking
            validates :starts_at, presence: true
            validates :ends_at, length: { maximum: 3 }, presence: false
            validates :note, "presence" => true, **STRICT
            belongs_to :owner, optional: true
            validate :ordered, :owned, :noted, :reported, :selfish

            def ordered = ends_at.nil?

            def owned = owner.nil?

            def noted = note.nil?

            def reported
              errors.add(:starts_at, :blank) if starts_at.nil? || @strict
            end

            def selfish = self.starts_at.nil?

            def unregistered = starts_at.nil?
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[ordered owned noted reported selfish unregistered]))
  end

  it "leaves a default given where a parameter or payload value enters, which is the remedy itself" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            private

            def ttl(params)
              return DEFAULT_TTL if params[:ttl].nil?
              params[:ttl].to_i
            end

            def limit(value) = value.nil? ? 60 : value

            def fallback(value)
              return DEFAULT_TTL if value.nil?
              value
            end

            def tags(value) = value == nil ? [] : value
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "still flags a boundary check with no default, or a default for a value the object holds" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def held
              return DEFAULT_TTL if @ttl.nil?
              @ttl
            end

            private

            def bare(ttl)
              return if ttl.nil?
              @ttl = ttl
            end

            def computed(value)
              return @fallback if value.nil?
              value
            end

            def empty(ttl)
              if ttl.nil?
              end
            end
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[held bare computed empty]))
    expect(findings.first(2).map(&:evidence)).to(eq([["@ttl (line 5)"], ["ttl (line 12)"]]))
  end

  it "leaves a library's object to its own nil contract, and doubts a value only partly the codebase's" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Failure < StandardError; end

          class Thing
            def rescued
              @http.get
            rescue Faraday::Error => error
              error.code.nil?
            end

            def fetched(url)
              reply = Faraday.get(url)
              reply.body.nil?
            end

            def guarded(node)
              return unless node.is_a?(Prism::CallNode)
              node.receiver.nil?
            end

            def ours
              @http.get
            rescue Failure => error
              error.code.nil?
            end

            def mixed(url)
              reply = Faraday.get(url)
              reply.body.nil? || @body.nil?
            end

            def bare = receiver.nil?

            def unbound(url)
              reply = nil
              reply = Faraday.get(url) if url
              return unless reply
              reply || {}
            end

            def shadowed(url)
              reply = Faraday.get(url)
              self.reply.nil? && reply
            end

            def reply = @reply
          end
        end
      end
    RUBY
    doubts = findings.map { [it.package.split("#").last, it.doubted?] }
    expect(doubts).to(eq([["mixed", false], ["unbound", true], ["shadowed", false]]))
  end

  it "advises exists? when a predicate fetches a record only to test it for nil, and lets one answer its own nil" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Record; end

          class Thing
            def deleted? = Record.find_by(id: @id).nil?

            def record = Record.find_by(id: @id).nil?

            def gone? = Record.find_by(id: @id).nil? || @cache.nil?

            def empty? = Record.where(id: @id).first.nil?

            def missing? = lookup(@id).nil?

            def lookup(id) = id
          end
        end
      end
    RUBY
    expect(findings.map { it.detail[:origin] }).to(eq([:absence, nil, :absence]))
    expect(message(findings.first)).to(include("checks for nil", "exists? instead of fetching a record"))
  end

  it "flags safe navigation on a value the codebase itself leaves nil, a parameter's nil default under strict" do
    source = <<~RUBY
      module App
        module Zone
          class Thing
            def initialize(node)
              @user = nil
              @node = node
              @flag = nil
              @flag = true
            end

            def held = @user&.name

            def found
              match = nil
              @items.each { match = it if it.ok? }
              match&.name
            end

            def optional(label = nil) = label&.upcase

            def keyword(label: nil) = label&.upcase

            def given = @node&.name

            def called = parent&.name

            def flagged = @flag&.to_s

            def handed(label) = label&.upcase
          end
        end
      end
    RUBY
    found = [checked(source), checked(source, rules: Fixtures::STRICT)].map { |all| all.map { it.package.split("#").last } }
    expect(found).to(eq([%w[held found], %w[held found optional keyword]]))
  end

  it "flags blank? on a value the object holds, but not on a public argument or a method's result" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def named(name) = name.blank?

            def titled = @title.blank?

            def called = title.blank?

            def bare = blank?
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[titled]))
  end

  it "flags a literal fallback for a value the codebase leaves nil, but not memoization or a computed fallback" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @limit = nil
            end

            def limit = @limit || 10

            def cache
              found = nil
              found = @store.read if @warm
              found || {}
            end

            def label(name) = name || "anonymous"

            def computed = @limit || fallback

            def memo = @memo ||= 1
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[limit cache]))
  end

  it "reads a guard whose only statement fills the value it tests as memoization, like ||=" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def flag(name)
              @invalid = Set.new if @invalid.nil?
              @invalid << name
            end

            def local(name)
              seen = @store.read(name)
              seen = Set.new if seen == nil
              seen
            end

            def other(name)
              @marks = Set.new if @invalid.nil?
              @marks << name
            end

            def twice(name)
              if @notes.nil?
                @notes = Set.new
                @log.write(name)
              end
            end

            def otherwise(name)
              if @tags.nil?
                @tags = Set.new
              else
                @log.write(name)
              end
            end

            def shared(name)
              @seen = Set.new if @seen.nil? && name
            end
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[other twice otherwise shared]))
  end

  it "flags unless on a value the codebase leaves nil, but not on a flag or a method's result" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def initialize
              @started = nil
              @done = nil
              @done = false
            end

            def start
              return unless @started
              @log.write(:start)
            end

            def finish
              return unless @done
              @log.write(:done)
            end

            def pick
              chosen = nil
              chosen = @items.first if @ready
              @log.write(chosen) unless chosen
            end

            def asked
              @log.write(:asked) unless ready?
            end
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[start pick]))
  end

  it "names what each check tests, and under safe navigation only the receiver it guards" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def merged(params)
              found = nil
              found = @cache.read if @warm
              found&.merge(params[:extra])
            end

            def pick(name)
              return DEFAULT if self.name.nil?
              name
            end

            def name = @name
          end
        end
      end
    RUBY
    expect(findings.map(&:evidence)).to(eq([["found (line 7)"], ["self.name (line 11)"]]))
  end

  it "leaves a check alone whose branch raises: the nil is what the guard asserts against" do
    findings = checked(<<~RUBY)
      class Builder
        def initialize = @adapter = nil

        def ensure! = (raise(ArgumentError, "no adapter") if @adapter.nil?)

        def check!
          fail("no adapter") unless !@adapter.nil?
        end

        def warn = (@log.warn("no adapter") if @adapter.nil?)
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["Builder#warn"]))
  end

  it "lets a one-line predicate answer its own nil test, but not one that branches or does more first" do
    findings = checked(<<~RUBY)
      class Box
        def initialize = @x = nil

        def empty? = @x.nil?

        def full?
          return false if @x.nil?
          true
        end

        def ready?
          log
          @x.nil?
        end

        def sized? = @x.nil? ? false : @x.any?
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[Box#full? Box#ready? Box#sized?]))
  end

  it "flags, under strict, a public method testing its own nil-defaulted parameter: two methods in one" do
    source = <<~RUBY
      module App
        class Price
          def initialize(cents) = @cents = cents

          def discounted(coupon = nil)
            return @cents if coupon.nil?
            @cents - coupon.cents
          end

          def tagged(label: nil) = label ? "\#{label}: \#{@cents}" : @cents.to_s

          def forced(force = false) = force.nil? ? 1 : 2

          def given(coupon) = coupon.nil? ? @cents : coupon.cents

          def fallback(ttl = nil) = ttl.nil? ? 60 : ttl
        end
      end
    RUBY
    findings = checked(source, rules: Fixtures::STRICT)
    expect(checked(source)).to(be_empty)
    expect(findings.map { [it.package, it.detail[:origin]] }).to(eq([["App::Price#discounted", ["coupon"]]]))
    expect(message(findings.first)).to(
      eq(
        "App::Price#discounted checks for nil (zone/thing.rb:6). 'coupon' defaults to nil, so callers may pass " \
          "nothing and the method is two in one: split it, or ask for a null object instead of nil."
      )
    )
  end

  it "names, under strict, an owned method that can answer nil as the source of a check on its answer" do
    files = {
      "lib/app/shop/catalog.rb" => <<~RUBY,
        module Shop
          class Catalog
            def initialize(items) = @items = items

            def find(code) = @items.detect { it.code == code }

            def fetch(code) = @items.fetch(code)

            def parent(code)
              return nil unless code
              @items[code]
            end
          end
        end
      RUBY
      "lib/app/shop/cart.rb" => <<~RUBY
        module Shop
          class Cart
            def initialize(catalog, codes) = (@catalog = catalog; @codes = codes)

            def total
              @codes.sum do |code|
                item = @catalog.find(code)
                item.nil? ? 0 : item.price
              end
            end

            def first = @catalog.find(@codes.first)&.price

            def sure = @catalog.fetch(@codes.first).nil?

            def held
              parent = Shop::Catalog.new(@codes).parent(1)
              return 0 if parent.nil?
              parent.price
            end

            def built
              catalog = Catalog.new(@codes)
              found = catalog.find(2)
              found || 0
            end

            def mixed(code)
              found = @catalog.find(code)
              found = @catalog.parent(code) if code.odd?
              found.nil? ? 0 : found.price
            end
          end
        end
      RUBY
    }
    expect(sniffed(files, "nil_check")).to(be_empty)
    expect(strictly(files, "nil_check").to_h { [it.package, it.detail[:sources].keys] }).to(
      eq(
        "Shop::Cart#total" => ["Shop::Catalog#find"], "Shop::Cart#first" => ["Shop::Catalog#find"],
        "Shop::Cart#held" => ["Shop::Catalog#parent"], "Shop::Cart#built" => ["Shop::Catalog#find"],
        "Shop::Cart#mixed" => []
      )
    )
  end

  def answers(body)
    store = "module Shop\n  class Store\n    def get\n    #{body}\n    end\n  end\nend\n"
    user = "module Shop\n  class User\n    def go = @store.get.nil?\n  end\nend\n"
    files = { "lib/app/shop/store.rb" => store, "lib/app/shop/user.rb" => user }
    [sniffed(files, "nil_check").any?, strictly(files, "nil_check").any?]
  end

  it "takes an owned method for a nil source only when its body can answer nil" do
    bodies = {
      "x if @y" => true, "case @y when 1 then 2 end" => true, "return if @y\n    1" => true, "@y&.size" => true,
      "@y.first" => true, "" => true, "@y ? 1 : nil" => true, "unless @y then 1 end" => true,
      "@y.fetch(1)" => false, "@y ? 1 : 2" => false, "return 2 if @y\n    1" => false, "@y.size" => false
    }
    expect(bodies.keys.map { answers(it) }).to(eq(bodies.values.map { [false, it] }))
  end

  it "lets a raising guard on a defaulted parameter or an owned answer stand, and never types a field as its class" do
    files = {
      "lib/app/shop/output.rb" =>
        "module Shop\n  class Output\n    def self.wait = nil\n    def wait = (@lines[0] if @ready)\n  end\nend\n",
      "lib/app/shop/process.rb" => <<~RUBY,
        module Shop
          class Process
            def url
              match = @output.wait
              raise ArgumentError, "timed out" unless match
              match
            end

            def odd = (@output || @spare).wait.nil?

            def key(source: nil)
              raise ArgumentError, "source needed" unless source
              source.key
            end
          end
        end
      RUBY
      "lib/app/shop/contexts.rb" => <<~RUBY
        module Shop
          class Contexts
            def [](id) = @contexts[id]

            def dispose(id)
              context = @contexts[id]
              return unless context
              context.close
            end
          end
        end
      RUBY
    }
    expect([sniffed(files, "nil_check"), strictly(files, "nil_check")]).to(all(be_empty))
  end

  it "takes an owned method's instance definition only, and names no source for its own call with arguments" do
    files = {
      "lib/app/shop/catalog.rb" =>
        "module Shop\n  class Catalog\n    def self.find = nil\n    def find(id) = @items.fetch(id)\n  end\nend\n",
      "lib/app/shop/cart.rb" => <<~RUBY
        module Shop
          class Cart
            def sure(code) = @catalog.find(code).nil?

            def own(count = nil) = self.count.nil?

            def count = @items.first

            def first = lookup(1).nil?

            def lookup(id) = @items[id]
          end
        end
      RUBY
    }
    found = [sniffed(files, "nil_check"), strictly(files, "nil_check")]
    told = found.map { |all| all.to_h { [it.package, [it.detail[:origin], it.detail[:sources].keys]] } }
    expect(told).to(eq([{ "Shop::Cart#own" => [nil, ["#count"]], "Shop::Cart#first" => [nil, []] }] * 2))
  end
end
