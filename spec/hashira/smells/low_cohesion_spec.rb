# frozen_string_literal: true

RSpec.describe(Hashira::Smells::LowCohesion, :aggregate_failures) do
  def split(source, rules = Fixtures::NONE)
    within("lib/app/account.rb" => source) do
      project = Hashira::Project.new(["lib/app"])
      trees = project.files.to_h { [it, Prism.parse_file(it).value] }
      return Hashira::Smells::Report.new(project, trees, Hashira::Boundaries.new([], trees), rules).findings.select { it.kind == "low_cohesion" }
    end
  end

  def account(extra = "", head = "class Account") = <<~RUBY
    #{head}
      def initialize(balance, mailer)
        @balance = balance
        @mailer = mailer
      end

      def deposit(sum) = @balance += sum
      def withdraw(sum) = @balance -= sum
      def balance = @balance
      def notify(text) = @mailer.deliver(text)
      def remind = @mailer.deliver("due")
      def ping = @mailer.ping
      #{extra}
    end
  RUBY

  it "joins the fields an inherited constructor takes from one argument, as it does its own" do
    base = <<~RUBY
      class Policy
        def initialize(context, record)
          @user = context[:user]
          @account = context[:account]
          @membership = context[:membership]
          @record = record
        end
      end

    RUBY
    portal = <<~RUBY
      class PortalPolicy < Policy
        def update? = @membership.admin?
        def edit? = @membership.admin?
        def destroy? = @membership.owner?
        def index? = @account.active? && @user.verified?
        def show? = @account.active?
        def status? = @user.verified?
      end
    RUBY
    apart = base.sub("context, record", "user, account, membership, record").gsub(/context\[:(\w+)\]/, '\\1')
    expect([split(base + portal), split(apart + portal)].map(&:size)).to(eq([0, 1]))
  end

  it "flags a class whose methods fall into groups that share no field and never call each other" do
    finding = split(account).first
    expect([finding.package, finding.detail, finding.evidence]).to(
      eq(
        [
          "Account", { site: "account.rb:1", count: 2, size: 6 },
          ["deposit, withdraw, balance (@balance)", "notify, remind, ping (@mailer)"]
        ]
      )
    )
  end

  it "says how many groups it found and what to do" do
    said = "Account splits into 2 groups of methods that share no state (account.rb:1). " \
      "Split the class along that seam."
    expect(message(split(account).first)).to(eq(said))
  end

  it "joins the groups through a method that touches both fields, or calls into both" do
    joins = [
      "def audit = @mailer.deliver(@balance)", "def audit = [balance, ping]",
      "def audit = [send(:balance), method(:remind)]"
    ]
    expect(joins.map { split(account(it)) }).to(all(be_empty))
  end

  it "joins through self-calls, readers and writers named for a field, and fields a delegator forwards to" do
    joins = ["def audit = [self.balance, ping]", "attr_writer :mailer\n  def audit = self.mailer = balance"]
    joins << "attr_reader :mailer\n  def audit = [mailer, balance]"
    joins << "extend Forwardable\n  def_delegators :@mailer, :deliver, :ping\n  def audit = [deliver, balance]"
    expect(joins.map { split(account(it)) }).to(all(be_empty))
  end

  it "reads a delegator to a reader as forwarding to the reader's field" do
    source = account("extend Forwardable\n  def_delegators :mailer, :deliver\n  def audit = [deliver, balance]")
    expect(split(source)).to(be_empty)
  end

  it "joins fields the constructor derives from one input or from a method of the other group" do
    derived = account.sub("@mailer = mailer", "@mailer = Mailer.new(balance)")
    computed = account("def statement = @balance.to_s").sub("@mailer = mailer", "@mailer = Mailer.new(statement)")
    expect([split(derived), split(computed)]).to(all(be_empty))
  end

  it "joins nothing through a send without a literal name, or a bare delegator" do
    delegators = "extend Forwardable\n  def_delegators\n  def_delegators :@mailer, *NAMES"
    source = account("#{delegators}\n  def audit = [send, public_send(name), method]")
    expect(split(source).size).to(eq(1))
  end

  def dispatched
    table = "COMMANDS = { \"remind\" => :remind, \"deposit\" => :deposit }.freeze\n  "
    [
      "#{table}def run(name) = __send__(COMMANDS.fetch(name))", "#{table}def run(name) = public_send(\"\#{name}\")",
      "def run(name) = public_send(name)\n  def names = %i[ping]", "def audit = [send(:balance), :ping]",
      "def run = send\n  def names = %i[balance remind]"
    ]
  end

  it "joins a computed send to the methods the class names as symbols, its dispatch table" do
    expect(dispatched.map { split(account(it)).size }).to(eq([0, 0, 1, 1, 1]))
  end

  def assigned(writers) = account("#{writers}\n  #{applied}")

  def applied = "def apply(values) = values.each { |name, value| send(\"\#{name}=\", value) }"

  it "joins a computed send of a writer name to every writer, minted or hand-written, and so to their fields" do
    writers = ["attr_writer :balance, :mailer", "attr_accessor :mailer\n  attr_writer :balance"]
    writers << "attr_writer :balance\n  def mailer=(value)\n    @mailer = value\n  end"
    lone = account("def apply(values) = values.each { |name, value| send(\"\#{name}_at\", value) }")
    expect(writers.map { split(assigned(it)).size } + [split(lone).size]).to(eq([0, 0, 0, 1]))
  end

  def mixed(body, head = "") = "#{head}#{account("#{body}\n  def audit = [bridge, held, ping]")}"

  it "joins methods through a project module the class includes, whose methods call back into the class" do
    bridge = "module Bridge\n  def bridge = [balance, ping]\nend\nmodule Held\n  def held = @balance\nend\n"
    groups = ["deposit, withdraw, balance (@balance)", "notify, remind, ping, audit (@mailer)"]
    found = [mixed("include Bridge", bridge), mixed("include Held", bridge), mixed("include Comparable")]
      .map { split(it) }
    expect([found[0], found[1], found[2].first.evidence]).to(eq([[], [], groups]))
  end

  it "joins every group through a method that reads fields by computed name, in the class or a module it includes" do
    serialized = "module Serialized\n  def serialized = FIELDS.map { instance_variable_get(it) }\nend\n"
    found = [
      account("def dump = instance_variables.map { 1 }"), account("def dump = instance_variable_get(:\"@\#{name}\")"),
      mixed("include Serialized\n  def bridge = serialized", serialized),
      account("def dump = instance_variable_get(:@balance)"), account("def dump = other.instance_variables"),
      account("def dump = instance_variable_get")
    ]
    expect(found.map { split(it).size }).to(eq([0, 0, 0, 1, 1, 1]))
  end

  it "keeps groups apart that a constructor only stores separately" do
    blank = account.sub("@mailer = mailer\n", "@mailer = mailer\n    @log = []\n")
    expect(split(blank).size).to(eq(1))
  end

  it "counts a group only with two methods and a field some method reads" do
    lone = account.sub(
      "def remind = @mailer.deliver(\"due\")\n  def ping = @mailer.ping\n",
      "def remind = 1\n  def ping = 2\n"
    )
    written = account.gsub("@mailer.", "@sent = ").sub(
      "def initialize(balance, mailer)",
      "def initialize(balance, sent)"
    )
    expect([split(lone), split(written)]).to(all(be_empty))
  end

  it "needs six methods besides the constructor, a threshold a setting moves" do
    small = account.sub("  def ping = @mailer.ping\n", "")
    rules = Hashira::Config::Rules.parse({ "low_cohesion" => { "threshold" => 5 } }, ["low_cohesion"])
    expect([split(small).size, split(small, rules).size]).to(eq([0, 1]))
  end

  it "leaves modules alone, and classes whose owned root extends a framework class" do
    framed = account("", "class Account < ApplicationRecord")
    expect([split(account.sub("class Account", "module Account")), split(framed)]).to(all(be_empty))
  end
end
