# frozen_string_literal: true

RSpec.describe(Hashira::Smells::UtilityFunction, :aggregate_failures) do
  def utility(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "utility_function")
  def opaque(body) = utility("class App::Thing\n  def go(string)\n    #{body}\n    string.to_s\n  end\nend")

  it "never calls stateless a method whose body holds code hashira cannot read" do
    bodies = [
      "`self.write_proc(string)`", "%x{ $deny(\#{string}) }", 'eval("@x + string")', 'class_eval("string")',
      "binding.local_variable_get(:string)", "local_variables.size + string.size", "string.instance_eval(&:size)"
    ]
    expect(bodies.map { opaque(it).size }).to(eq([0, 0, 0, 0, 0, 0, 1]))
  end

  it "judges a class reopened by a block in an earlier file as the class it is" do
    files = {
      "lib/app/a_ext.rb" => "App::Thing.class_eval do\n  def extra(word) = word.to_s\nend\n",
      "lib/app/thing.rb" =>
        "module App\n  class Thing\n    def initialize = @x = 1\n    def shout(word) = word.to_s\n  end\nend\n"
    }
    later = files.transform_keys { it.sub("a_ext", "z_ext") }
    found = [files, later].map { sniffed(it, "utility_function").map(&:package) }
    expect(found).to(eq([%w[App::Thing#shout App::Thing#extra]] * 2))
  end

  it "flags a public instance method that never touches instance state" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Thing
            def shout(word)
              word.to_s.upcase
            end
          end
        end
      end
    RUBY
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(finding.package).to(eq("App::Zone::Thing#shout"))
    expect(message(finding)).to(end_with("(zone/thing.rb:4). Move it onto the object it serves, or make it private."))
  end

  it "exempts a role its siblings fill through the mixins they include" do
    findings = utility(<<~RUBY)
      module App
        class Monitor
          def initialize(name) = @name = name

          module Suffixed
            def field_key(field) = "\#{field.path}.graphql"
          end

          module Prefixed
            def field_key(field) = "graphql.\#{field.path}"
          end
        end

        class Datadog < Monitor
          include Monitor::Suffixed
        end

        class Sentry < Monitor
          include Monitor::Prefixed
        end

        class Relic < Monitor
          def field_key(field) = "Field/\#{field.path}"
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "leaves private helpers, module functions, and singleton methods alone" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Thing
            def self.build(word) = word.to_s

            private

            def quiet(word) = word.to_s
          end

          module Bare
            module_function

            def loud(word) = word.to_s
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "exempts methods defined inside class << self" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Thing
            class << self
              LIMIT = 3

              def scrub(text) = text.strip
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "requires at least one call and zero self references" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Thing
            def blank = 1

            def stateful(word)
              @word = word.to_s
            end

            def implicit(word)
              tidy(word)
            end
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "reads a method its kin also define as polymorphism, not a utility function" do
    jobs = <<~RUBY
      module App
        module Zone
          class Base
            def run(word) = raise(word.to_s)
          end

          class Fetch < Base
            def run(word) = word.to_s

            def tidy(word) = word.strip
          end

          class Send < ApplicationJob
            def perform(id) = Feed.find(id)
          end

          class Pull < ::ApplicationJob
            def perform(id) = Feed.find(id)

            def lonely(id) = Feed.find(id)
          end

          class Drain
            def run(id) = @pull.lonely(id)
          end

          class Solo
            def perform(id) = Feed.find(id)
          end
        end
      end
    RUBY
    speech = <<~RUBY
      module App
        module Zone
          module Speaker
            def speak(word) = word.to_s
          end

          class Dog
            include Speaker

            def speak(word) = word.upcase
          end
        end
      end
    RUBY
    findings = sniffed({ "lib/app/zone/jobs.rb" => jobs, "lib/app/zone/speech.rb" => speech }, "utility_function")
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Fetch#tidy App::Zone::Pull#lonely App::Zone::Solo#perform]))
  end

  it "takes the subclasses of one class for kin however each spells its parent" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Task
            def initialize(log) = @log = log
          end

          class Mail < Task
            def handle(id) = Feed.find(id)
          end

          class Ping < App::Zone::Task
            def handle(id) = Feed.find(id)
          end

          class Solo
            def handle(id) = Feed.find(id)
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Zone::Solo#handle]))
  end

  it "takes the classes built on one computed parent, or on one library class however rooted, for kin" do
    findings = utility(<<~RUBY)
      module App
        class IndexJob < App.parent_job.constantize
          def perform(id) = Feed.find(id).index
        end

        class PurgeJob < App.parent_job.constantize
          def perform(id) = Feed.find(id).purge
        end

        class QueueJob < App.parent_job.constantize
          def perform(id) = IndexJob.new.perform(id)
        end

        class Stray < App.other_job.constantize
          def perform(id) = Feed.find(id)
        end

        class Mail < ::Library::Task
          def handle(id) = Feed.find(id)
        end

        class Ping < Library::Task
          def handle(id) = Feed.find(id)
        end

        class User
          def go = @task.handle(1) && @job.perform(1)
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Stray#perform]))
  end

  it "takes the classes one array literal builds side by side for peers, so their shared methods are protocol" do
    findings = utility(<<~RUBY)
      module App
        class HelpEntry
          def initialize(user) = @user = user
          def link = App.routes.help_path
          def note = App.routes.note_path
        end

        class OrdersEntry
          def initialize(user) = @user = user
          def link = App.routes.orders_path(@user.id)
        end

        class Menu
          def initialize(user) = @entries = [HelpEntry.new(user), OrdersEntry.new(user), 1]
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::HelpEntry#note]))
  end

  it "takes a class attribute's default and the classes assigned to it for peers that share a protocol" do
    findings = utility(<<~RUBY)
      module App
        class Debouncer
          def initialize(delay:) = @delay = delay
          def debounce(&) = @task = Task.run(@delay, &)
        end

        class ImmediateDebouncer
          def initialize(delay:) = nil
          def debounce(&block) = block.call
          def pause(&block) = block.call
        end

        class Threaded
          class_attribute :debouncer_class, instance_writer: false, default: Debouncer

          def initialize(delay) = @debouncer = debouncer_class.new(delay:)
        end

        module Setup
          def self.testing! = Threaded.debouncer_class = ImmediateDebouncer
        end

        class Lone
          def debounce(&block) = block.call
        end

        module Picker
          def self.pick(config) = config.fetch(:debouncer_class, default: Lone)
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::ImmediateDebouncer#pause App::Lone#debounce]))
  end

  it "takes a class that hands itself to a decorator, or seeds a chain of them, for the peer of what wraps it" do
    findings = utility(<<~RUBY)
      module App
        class Layer
          def initialize(stack) = @stack = stack
          def request_call(datum) = @stack.request_call(datum)
          def response_call(datum) = @stack.response_call(datum)
        end

        class Connection
          def initialize(layers) = @layers = layers
          def request(datum) = @layers.inject(self) { |inner, layer| layer.new(inner) }.request_call(datum)
          def request_call(datum) = datum.merge(sent: true)
          def response_call(datum) = datum.merge(read: true)
          def label(datum) = datum.fetch(:name)
        end

        class Probe
          def initialize(layers) = @layers = layers
          def wrapped = Layer.new(self)
          def response_call(datum) = datum.merge(probed: true)
        end

        class Spawn
          def initialize(kind) = @kind = kind
          def child = @kind.new(self)
          def response_call(datum) = datum.merge(spawned: true)
          def scheduled?(job) = job.next_time.nil?
          def format(datum) = datum.to_s
        end

        class Formatter
          def format(datum) = datum.merge(formatted: true)
        end

        class Copier
          def initialize(source) = @copy = source.dup
          def format(datum) = @copy.format(normal(datum))

          private

          def normal(datum) = datum.compact
        end

        class Loose
          def initialize(rows) = @rows = rows
          def total = @rows.reduce(self) { |sum, row| sum.add(row) }
          def response_call(datum) = datum.merge(loose: true)
        end

        class Job
          def initialize(scheduler, at) = (@scheduler = scheduler; @at = at)
          def scheduled? = @scheduler.scheduled?(self)
        end

        class Scheduler
          def initialize(kind) = @kind = kind
          def schedule(at) = @kind.new(self, at)
          def scheduled?(job) = job.next_time.nil?
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(
        %w[
          App::Connection#label App::Spawn#scheduled? App::Spawn#format App::Formatter#format App::Loose#response_call
          App::Scheduler#scheduled?
        ]
      )
    )
  end

  it "reads a fold seeded with self that builds what it folds, in its block or its receiver, as a decorator chain" do
    findings = utility(<<~RUBY)
      module App
        class Layer
          def initialize(stack) = @stack = stack
          def request_call(datum) = @stack.request_call(datum)
        end

        class Chain
          def initialize(layers) = @layers = layers
          def stack = @layers.map { |layer| ->(inner) { layer.new(inner) } }.inject(self) { |inner, wrap| wrap.call(inner) }
          def request_call(datum) = datum.merge(chained: true)
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "takes the classes one table holds, as classes or as the objects it builds, for peers that share a protocol" do
    findings = utility(<<~RUBY)
      module App
        class Plain
          def initialize(color:) = @color = color
          def sent(message) = @color.paint(message)
          def shown(message) = @color.paint(message)
        end

        class Json
          def initialize(color:) = @color = color
          def sent(message) = JSON.generate(message)
          def shown(message) = JSON.generate(message)
          def received(message) = JSON.generate(message)
        end

        class Csv
          def initialize(color:) = @color = color
          def shown(message) = CSV.generate_line(message)
        end

        class Xml
          def shown(message) = message.to_xml
        end

        class Log
          FORMATS = { plain: Plain, json: Json }.freeze
          def initialize(format) = @formatter = FORMATS.fetch(format).new(color: true)
          def views = { plain: Plain.new(color: @formatter), csv: Csv.new(color: 1), xml: Xml.build, **FORMATS }
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Json#received App::Xml#shown]))
  end

  it "keeps an override of a core ancestor's method a hook, though the project sends that message too" do
    findings = utility(<<~RUBY)
      module App
        class Error < StandardError
        end

        class AuthError < Error
          def message = I18n.t("app.errors.auth")

          def hint = I18n.t("app.errors.hint")
        end

        class Set < Library::Base
        end

        class Tags < Set
          def add(tag) = Log.write(tag)
        end

        class Handler
          def handle(error) = @log.warn([error.message, error.hint, @tags.add(1)])
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::AuthError#hint App::Tags#add]))
  end

  it "leaves the equality, ordering and printing Ruby asks of every object to it, at the arity Ruby calls them" do
    findings = utility(<<~RUBY)
      module App
        class Nothing
          def eql?(other) = other.is_a?(Nothing)
          def hash = Nothing.name.hash
          def <=>(other) = other.is_a?(Nothing) ? 0 : -1
          def ===(other) = other.nil?
          def inspect = "Nothing".dup.freeze
          def to_s(*) = String.new("Nothing")
          def coerce(number) = [Nothing.new, number.to_i]
          def digest(password) = Digest::SHA256.hexdigest(password)
          def display(page) = Printer.print(page)
        end

        class Vault
          def hash(password) = Digest::SHA256.hexdigest(password)
          def ==(*) = Vault.name.frozen?
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(%w[App::Nothing#digest App::Nothing#display App::Vault#hash App::Vault#==]))
  end

  it "reads what nothing here calls on a class built on a library's ancestor as a hook the library calls" do
    plugin = <<~RUBY
      module App
        class Plugin < LintRoller::Plugin
          def about = LintRoller::About.new(name: "app")

          def supported?(context) = context.engine == :rubocop

          def label(name) = name.to_s

          def badge(name) = name.to_s
        end

        class Base < Library::Thing
        end

        class Leaf < Base
          def hook(name) = name.to_s
        end

        class Mixed
          include Library::Hooks

          def setup(name) = name.to_s
        end

        class Plain
          def orphan(name) = name.to_s
        end

        class User
          def show(names) = @plugin.label(names.map(&:badge))
        end
      end
    RUBY
    findings = sniffed({ "lib/app/plugin.rb" => plugin }, "utility_function")
    expect(findings.map(&:package)).to(eq(%w[App::Plugin#label App::Plugin#badge App::Plain#orphan]))
  end

  it "keeps a library hook a hook when the project only sends its name to a class, as a macro" do
    validator = <<~RUBY
      module App
        class NewestOnly < ActiveModel::Validator
          def validate(record) = record.errors.add(:base, "stale") unless record.newest?

          def check(record) = record.errors.add(:base, "stale")
        end

        class Place < ActiveRecord::Base
          validates_with NewestOnly
          validate :paired
          check :paired

          def newest? = @newest
        end

        class Audit
          def run(record) = NewestOnly.new.check(record)
        end
      end
    RUBY
    findings = sniffed({ "lib/app/place.rb" => validator }, "utility_function")
    expect(findings.map(&:package)).to(eq(%w[App::NewestOnly#check App::Audit#run]))
  end

  def jobs(extra, head = "PublishJob") = <<~RUBY
    module App
      class BaseJob
        def run(id) = id.to_s
      end

      module Retried
        def again(id) = id.to_s
      end

      class #{head}
        include Sidekiq::Job

        def perform(id) = Tag.find(id).publish
      end

      class UrgentJob < PublishJob
      end

      class ListPublisher
        def initialize(tag) = @tag = tag

        def perform = @tag.publish

        def run = perform
      end

      class Lists
        def create = ListPublisher.new(@tag).perform
        def other = Library::Runner.new.perform
        def settle = { perform: true }.merge(@tag)
        def pick = ListPublisher.perform(@tag)
        #{extra}
      end
    end
  RUBY

  def performs?(source)
    sniffed({ "lib/app/jobs.rb" => source }, "utility_function").map(&:package).include?("App::PublishJob#perform")
  end

  it "keeps a library hook a hook unless the project sends its name to an object of the class's own lineage" do
    sent = [
      "", "def again(id) = PublishJob.new.perform(id)", "def later(id) = UrgentJob.new.perform(id)",
      "def any(job) = job.perform(1)", "def told(job) = job.send(:perform)", "def own = PublishJob.perform(1)",
      "def found = Registry.find(1).perform"
    ]
    expect(sent.map { performs?(jobs(it)) }).to(eq([false, true, true, true, true, true, true]))
  end

  it "counts a bare call to a library hook as sent to the class only from its own lineage" do
    lineage = [
      jobs("", "PublishJob < BaseJob").sub("def run(id) = id.to_s", "def run(id) = perform(id)"),
      jobs("", "PublishJob\n    include Retried").sub("def again(id) = id.to_s", "def again(id) = self.perform(id)")
    ]
    expect(lineage.map { performs?(it) }).to(eq([true, true]))
  end

  it "reads a hash key or a keyword argument as a label, not a message, so a validator keeps its hook" do
    validator = <<~RUBY
      module App
        class SlugValidator < ActiveModel::Validator
          def validate(record) = record.errors.add(:slug, "bad") unless record.slug
        end

        class Page < ActiveRecord::Base
          validates_with SlugValidator
          def import! = save!(validate: false)
          def check(record) = validate(record)
        end
      end
    RUBY
    told = validator.sub("def check(record) = validate(record)", "def check(checker) = checker.validate(self)")
    flagged = [validator, told].map { sniffed({ "lib/app/page.rb" => it }, "utility_function").map(&:package) }
    expect(flagged.map { it.include?("App::SlugValidator#validate") }).to(eq([false, true]))
  end

  it "traces a finding by the code it names, so a rename still matches and a different method does not" do
    shop = ->(name, body) { "module App\n  class Shop\n    def #{name}(price) = #{body}\n  end\nend\n" }
    traced = ->(name, body) { sniffed({ "lib/app/shop.rb" => shop[name, body] }, "utility_function").first.trace }
    tax = traced["tax", "price.round(2)"]
    alike = [traced["levy", "price.round(2)"], traced["discount", "price.floor(9)"]].map { it == tax }
    expect(alike).to(eq([true, false]))
  end

  it "leaves a module alone, whether a mixin, a concern or a helper, since its methods are meant to lend behavior" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          module Greets
            def greet(word) = word.to_s
          end

          module Helpers
            extend self

            def loud(word) = word.to_s
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "reads classes offered as alternatives at one site as peers, so a fake's shared methods are protocol" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Launcher
            def launch(job) = job.to_s

            def warm(job) = job.to_s

            def stop(job) = job.to_s

            def drain(job) = job.to_s

            def pause(job) = job.to_s

            def halt(job) = job.to_s
          end

          class FakeLauncher
            def launch(job) = job.inspect

            def note(job) = job.inspect
          end

          class Idle
            def warm(job) = job.inspect
          end

          class Spare
            def stop(job) = job.inspect
          end

          class Mute
            def drain(job) = job.inspect
          end

          class Calm
            def pause(job) = job.inspect
          end

          class Loose
            def launch(job) = job.inspect
          end

          class Boot
            def start
              @launcher = live? ? Launcher.new : FakeLauncher.new
              @idle = if live? then Launcher.new(1) else Idle.new end
              @spare = (Spare.new unless live?) || Launcher.new
              @mute = unless live? then Mute.new else (Launcher.new) end
              @calm = if live? then Calm.new elsif warm? then Launcher.new end
              @loose = live? ? Loose.build : Launcher.new
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(%w[App::Zone::Launcher#halt App::Zone::FakeLauncher#note App::Zone::Loose#launch])
    )
  end

  it "reads a same-named class under a stand-in namespace as a peer of the real one" do
    findings = utility(<<~RUBY)
      class Courier
        def hand(mail) = mail.to_s
      end

      module App
        module Zone
          class Mailer
            def deliver(mail) = mail.to_s
          end

          class Courier
            def hand(mail) = mail.inspect
          end

          module Fakes
            class Mailer
              def deliver(mail) = mail.inspect

              def peek(mail) = mail.inspect
            end
          end

          module Admin
            class Mailer
              def deliver(mail) = mail.inspect
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(%w[Courier#hand App::Zone::Courier#hand App::Zone::Fakes::Mailer#peek App::Zone::Admin::Mailer#deliver])
    )
  end

  it "reads a Fake, Null, or Stub class whose public methods a project class also offers as that class's peer" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          class Logger
            def info(line) = line.to_s

            def warn(line) = line.to_s

            def error(line) = line.to_s

            def tidy(line) = line.to_s
          end

          class NullLogger
            def initialize(sink) = @sink = sink

            def info(line) = line.inspect

            def warn(line) = line.inspect

            private

            def flush(line) = line.inspect
          end

          class LoggerStub
            def error(line) = line.inspect
          end

          class FakeClock
            def info(line) = line.inspect

            def travel(line) = line.inspect
          end

          class Quiet
            def warn(line) = line.inspect
          end

          class StubCache
            private

            def tidy(line) = line.inspect
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(%w[App::Zone::Logger#tidy App::Zone::FakeClock#info App::Zone::FakeClock#travel App::Zone::Quiet#warn])
    )
  end
end
