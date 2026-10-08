# frozen_string_literal: true

RSpec.describe(Hashira::Smells::NilCheck) do
  def checked(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "nil_check")
  it "flags nil?, nil comparisons, and when-nil clauses with their lines" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
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
    expect(message(findings.first)).to(include("checks for nil", "zone/thing.rb:4"))
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

  it "advises translating at the boundary when the nil-checked value arrives from outside" do
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

            def mixed(params) = params["id"] == nil || @cache.nil?
          end
        end
      end
    RUBY
    expect(findings.map { it.detail[:origin] }).to(eq(%i[outside outside outside both]))
    expect(message(findings.first)).to(include("comes from outside", "where it enters, at the boundary"))
    expect(message(findings.last)).to(include("where it enters; elsewhere prefer a null object"))
  end

  it "keeps the null-object advice for values the method made or was handed" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def built
              result = { id: nil }
              result[:id].nil?
            end

            def handed(value) = value.nil?

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
          end
        end
      end
    RUBY
    expect(findings.map(&:detail).uniq(&:keys).map(&:keys)).to(eq([[:site]]))
    expect(findings.size).to(eq(5))
  end

  it "ignores comparisons that never involve nil" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
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
            def ttl(params)
              return DEFAULT_TTL if params[:ttl].nil?
              params[:ttl].to_i
            end

            def limit(value) = value.nil? ? 60 : value

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
            def bare(params)
              return if params[:ttl].nil?
              @ttl = params[:ttl]
            end

            def computed(value)
              return @fallback if value.nil?
              value
            end

            def held
              return DEFAULT_TTL if @ttl.nil?
              @ttl
            end

            def empty(params)
              if params[:ttl].nil?
              end
            end
          end
        end
      end
    RUBY
    expect(findings.map { it.package.split("#").last }).to(eq(%w[bare computed held empty]))
  end

  it "doubts a nil check on a library's object, whose nil contract the codebase cannot design away" do
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
          end
        end
      end
    RUBY
    doubted = findings.select(&:doubted?).map { it.package.split("#").last }
    expect([doubted, findings.size]).to(eq([%w[rescued fetched guarded unbound], 7]))
  end

  it "advises exists? when a predicate fetches a record only to test it for nil" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Record; end

          class Thing
            def deleted? = Record.find_by(id: @id).nil?

            def record = Record.find_by(id: @id).nil?

            def gone? = Record.find_by(id: @id).nil? || @cache.nil?

            def empty? = Record.where(id: @id).first.nil?
          end
        end
      end
    RUBY
    expect(findings.map { it.detail[:origin] }).to(eq([:absence, nil, nil, nil]))
    expect(message(findings.first)).to(include("checks for nil", "exists? instead of fetching a record"))
  end

  it "flags safe navigation on a value the codebase itself leaves nil" do
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
    expect(findings.map { it.package.split("#").last }).to(eq(%w[held found optional keyword]))
  end

  it "flags blank? on a local, an ivar or a parameter, but not on a method's result" do
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
    expect(findings.map { it.package.split("#").last }).to(eq(%w[named titled]))
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

  it "judges an argument passed under safe navigation apart from the value it guards, and a nil on the left alike" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def merged(params)
              found = nil
              found = @cache.read if @warm
              found&.merge(params[:extra])
            end

            def flipped(params) = nil == params[:name]
          end
        end
      end
    RUBY
    expect(findings.map { it.detail[:origin] }).to(eq([nil, :outside]))
  end
end
