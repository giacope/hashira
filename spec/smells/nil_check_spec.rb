# frozen_string_literal: true

RSpec.describe(Hashira::Smells::NilCheck) do
  def checked(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "nil_check")
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

  it "flags safe navigation on a value the codebase itself leaves nil, and not on a caller's nil default" do
    findings = checked(<<~RUBY)
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
    expect(findings.map { it.package.split("#").last }).to(eq(%w[held found]))
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
end
