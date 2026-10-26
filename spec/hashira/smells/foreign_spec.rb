# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Foreign, :aggregate_failures) do
  def tree
    <<~RUBY
      module App
        class FileTree
          class Node
            attr_reader :parent, :name

            def initialize(parent, name)
              @parent = parent
              @name = name
            end
          end
        end
      end
    RUBY
  end

  def translator(body)
    <<~RUBY
      module App
        class Translator
          def initialize(source) = @source = source

          def run(node) = t?(node)

          private

          #{body}
        end
      end
    RUBY
  end

  def checked(body) = sniffed({ "lib/app/tree.rb" => tree, "lib/app/translator.rb" => translator(body) }, "nil_check")

  it "lets a case/when, a case/in or an is_a? guard on a library class outrank a local's name" do
    tests = [
      "def t?(node) = (case node when Prism::ConstantPathNode then node.parent.nil? end)",
      "def t?(node) = (case node in Prism::ConstantPathNode then node.parent.nil? end)",
      "def t?(node) = (case node in Prism::CallNode[name:] then node.parent.nil? end)",
      "def t?(node)\n  return false unless node.is_a?(Prism::ConstantPathNode)\n  node.parent.nil?\nend"
    ]
    expect(tests.map { checked(it) }).to(all(be_empty))
  end

  it "does not type a local by a name that resolves only by suffix to a class out of lexical sight" do
    expect(checked("def t?(node) = node.parent.nil?")).to(be_empty)
  end

  it "types a local by a type test against an owned class, whatever its name" do
    tested = "def t?(item) = (item.parent.nil? if item.is_a?(FileTree::Node))"
    found = sniffed({ "lib/app/tree.rb" => tree, "lib/app/translator.rb" => translator(tested) }, "nil_check")
    expect(found.map(&:package)).to(eq(["App::Translator#t?"]))
  end

  def inspector(body)
    <<~RUBY
      module App
        class Inspector
          def initialize(names) = @names = names

          #{body}
        end

        class Item
          def name = "item"
        end
      end
    RUBY
  end

  def probed(body) = sniffed({ "lib/app/inspector.rb" => inspector(body) }, "manual_dispatch").map(&:package)

  it "leaves a probe on a value of unknown type, and a probe of a computed message, alone" do
    untyped = "def show(variable)\n  value = instance_variable_get(variable)\n  value.respond_to?(:name)\nend"
    computed = "def home(scope, item = Item.new)\n  item.respond_to?(\"\#{scope}_path\", true)\nend"
    typed = "def show(item = Item.new) = item.respond_to?(:name)"
    expect([untyped, computed, typed].map { probed(it) }).to(eq([[], [], ["App::Inspector#show"]]))
  end

  it "leaves a probe on a method's result typed only by its name, and a probe of a message nothing defines, alone" do
    called = "def item = Item.new\n\ndef show = item.respond_to?(:name)"
    undefined = "def show\n  item = Item.new\n  item.respond_to?(:label)\nend"
    expect([called, undefined].map { probed(it) }).to(eq([[], []]))
  end

  it "leaves a probe on an exception rescued from a splatted list alone, as it does a library's" do
    rescued = "def show\n  Item.new.name\nrescue *FAILURES => item\n  item.respond_to?(:name)\nend"
    expect(probed(rescued)).to(be_empty)
  end

  it "takes a computed instance_variable_set with a literal prefix as assigning every read that starts with it" do
    core = <<~RUBY
      module App
        module Core
          def initialize(options = {}) = setup(options)

          def setup(options)
            options.each { |key, value| instance_variable_set("@app_\#{key}", value) }
            options.each { |key, value| instance_variable_set(:"@seen_\#{key}".to_sym, value) }
            options.each { |key, value| instance_variable_set("\#{key}", value) }
          end
        end

        class Storage
          include Core

          def url(path) = [path, @app_temp_url_key, @seen_region, @region]
        end
      end
    RUBY
    found = sniffed({ "lib/app/core.rb" => core }, "assumed_state")
    expect(found.map(&:evidence)).to(eq([["@region"]]))
  end

  it "links a method that sends a computed name to every method the name's literal parts can spell" do
    matcher = <<~RUBY
      module App
        class Matcher
          def from(sender) = @sender = sender
          def with_subject(subject) = @subject = subject
          def with_attachments(attachments) = @attachments = attachments
          def with_header(header) = @header = header

          def matches?(deliveries)
            %w[sender subject attachments].all? { |name| send("matches_on_\#{name}?", deliveries) } &&
              public_send(:"\#{deliveries}_header_check") && send("\#{deliveries}")
          end

          private

          def matches_on_sender?(delivery) = delivery.from.include?(@sender)
          def matches_on_subject?(delivery) = delivery.subject == @subject
          def matches_on_attachments?(delivery) = delivery.attachments == @attachments
          def any_header_check = @header
          def lonely_check = @header
        end
      end
    RUBY
    expect(sniffed({ "lib/app/matcher.rb" => matcher }, "low_cohesion")).to(be_empty)
  end

  it "exempts a bare Mock's or Fake's side of the protocol it shares with a class beside it" do
    compute = <<~RUBY
      module App
        class Compute
          class Real
            def initialize(connection) = @connection = connection
            def list_flavors(options = {}) = @connection.request(path: "flavors", query: options)
          end

          class %s
            def list_flavors(_options = {}) = Response.new(200, "flavors" => [])
            def reset_data(key) = key.to_s
          end

          Response = Struct.new(:status, :body)
        end
      end
    RUBY
    names = %w[Mock RecordingMock Fake Spare]
    found = names.map { sniffed({ "lib/app/compute.rb" => format(compute, it) }, "utility_function").map(&:package) }
    both = %w[RecordingMock Spare].map { |name| ["App::Compute::#{name}#list_flavors", "App::Compute::#{name}#reset_data"] }
    expect(found).to(eq([["App::Compute::Mock#reset_data"], both.first, ["App::Compute::Fake#reset_data"], both.last]))
  end

  it "links a computed send only to the methods both its literal ends spell, and to none when it has neither" do
    router = <<~RUBY
      module App
        class Router
          def a(x) = @a = x
          def on_a_done = @a
          def b(x) = @b = x
          def on_b = @b
          def c(x) = @c = x
          def c_done = @c
          def go(kind) = send("on_\#{kind}_done")
          def any(kind) = send("\#{kind}")
        end
      end
    RUBY
    expect(sniffed({ "lib/app/router.rb" => router }, "low_cohesion").map { it.detail[:count] }).to(eq([3]))
  end
end
