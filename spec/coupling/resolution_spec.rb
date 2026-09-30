# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Census, "#resolve") do
  it "resolves a bare constant to the nested definition, not a top-level namesake" do
    files = {
      "app/models/user.rb" => "class User\n  include Authentication\n  def a = 1\nend\n",
      "app/models/user/authentication.rb" => "module User::Authentication\n  def b = 1\nend\n",
      "app/controllers/concerns/authentication.rb" => "module Authentication\n  def c = 1\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges).to(be_empty)
    end
  end

  it "resolves through the enclosing namespace when the bare name is globally ambiguous" do
    files = {
      "app/controllers/admin/dashboard.rb" => "module Admin\n  class Dashboard\n    def s = Settings\n  end\nend\n",
      "app/models/admin/settings.rb" => "module Admin\n  class Settings\n    def f = 1\n  end\nend\n",
      "app/widgets/agent/settings.rb" => "module Agent\n  class Settings\n    def f = 2\n  end\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["controllers -> models"]))
    end
  end

  it "refuses to guess when the nested candidate is claimed by several packages" do
    files = {
      "app/controllers/admin/dashboard.rb" => "module Admin\n  class Dashboard\n    def s = Settings\n  end\nend\n",
      "app/models/admin/settings.rb" => "module Admin\n  class Settings\n    def f = 1\n  end\nend\n",
      "app/widgets/admin/settings.rb" => "module Admin\n  class Settings\n    def g = 2\n  end\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges).to(be_empty)
    end
  end

  it "walks outward through enclosing namespaces before falling back to top level" do
    files = {
      "lib/app/alpha/one.rb" => "module App\n  module Alpha\n    class One\n      def a = Helper\n    end\n  end\nend",
      "lib/app/beta/helper.rb" => "module App\n  class Helper\n    def x = 1\n  end\nend\n"
    }
    analyze(files) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["alpha -> beta"]))
    end
  end

  it "resolves a superclass outside the scope the class itself opens" do
    files = {
      "app/one/child.rb" => "class Child < Base\n  def a = 1\nend\n",
      "app/one/child/base.rb" => "class Child::Base\n  def b = 1\nend\n",
      "app/two/base.rb" => "class Base\n  def c = 1\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["one -> two"]))
    end
  end

  it "resolves a ::-anchored reference at top level, not through nesting" do
    files = {
      "app/models/user.rb" => "class User\n  def u = 1\nend\n",
      "app/widgets/admin/user.rb" => "module Admin\n  class User\n    def w = 1\n  end\nend\n",
      "app/controllers/admin/users_controller.rb" =>
        "module Admin\n  class UsersController\n    def show = ::User.new\n  end\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["controllers -> models"]))
    end
  end

  it "resolves a constant under a namespaced class through the enclosing scope" do
    files = {
      "app/controllers/admin/dashboard.rb" =>
        "module Admin\n  class Dashboard\n    def s = Invoice::STATES\n  end\nend\n",
      "app/models/admin/invoice.rb" => "module Admin\n  class Invoice\n    def i = 1\n  end\nend\n",
      "app/services/billing/exporter.rb" => "module Billing\n  class Exporter\n    def x = 1\n  end\nend\n",
      "app/widgets/format/text.rb" => "module Format\n  class Text\n    def t = 1\n  end\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["controllers -> models"]))
    end
  end

  it "anchors a compact reopen of a top-level class at top level" do
    files = {
      "app/models/foo.rb" => "class Foo\n  def f = 1\nend\n",
      "app/services/baz.rb" => "module Baz\n  class Foo::Bar\n    def call = Helper\n  end\nend\n",
      "app/helpers/helper.rb" => "class Helper\n  def h = 1\nend\n"
    }
    analyze(files, directories: ["app"], packaging: :namespace) do |_project, census, graph|
      expect(census.types["Foo"]).to(eq(2))
      expect(graph.edges.map(&:to_s)).to(eq(["Foo -> Helper"]))
    end
  end

  it "keeps a compact definition under an enclosing namespace that defines it" do
    files = {
      "lib/app/core.rb" => "module App\n  module Core\n    def self.c = 1\n  end\nend\n",
      "lib/app/core/thing.rb" => "module App\n  class Core::Thing\n    def t = 1\n  end\nend\n",
      "lib/app/edge.rb" => "module App\n  class Edge\n    def e = 1\n  end\nend\n"
    }
    analyze(files, packaging: :namespace) do |_project, census, _graph|
      expect(census.origins).to(have_key("Core::Thing"))
    end
  end

  it "resolves a constant assigned in the enclosing class, not a foreign namesake" do
    files = {
      "lib/app/session/lineage.rb" => <<~RUBY,
        module App
          module Session
            class Lineage
              Node = Struct.new(:path)
              def branch = Node.new
            end
          end
        end
      RUBY
      "lib/app/usage/kdl.rb" => <<~RUBY
        module App
          module Usage
            class Kdl
              class Node
                def n = 1
              end
            end
          end
        end
      RUBY
    }
    analyze(files) do |_project, _census, graph|
      expect(graph.edges).to(be_empty)
    end
  end

  it "leaves a bare core constant to Ruby, not a namespaced namesake" do
    files = {
      "app/models/tracker.rb" => "class Tracker\n  def pattern = Regexp\nend\n",
      "app/nodes/sql/regexp.rb" => "module Sql\n  class Regexp\n    def r = 1\n  end\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges).to(be_empty)
    end
  end

  it "leaves a core class to Ruby even where the project reopens it at top level" do
    files = {
      "app/ext/string.rb" => "class String\n  def shout = upcase\nend\n",
      "app/models/note.rb" => "class Note\n  def s = [String, ::String, String::Unknown]\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges).to(be_empty)
    end
  end

  it "still couples to a constant the project defines under a core namespace" do
    files = {
      "app/ext/file.rb" => "class File\n  class Lock < StandardError\n    def l = 1\n  end\nend\n",
      "app/models/note.rb" => "class Note\n  def s = File::Lock::Error\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["models -> ext"]))
    end
  end

  it "lets a lexical namesake shadow a core constant, as Ruby does" do
    files = {
      "app/nodes/sql/regexp.rb" => "module Sql\n  class Regexp\n    def r = 1\n  end\nend\n",
      "app/visitors/sql/to_sql.rb" => "module Sql\n  class ToSql\n    def r = Regexp\n  end\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["visitors -> nodes"]))
    end
  end

  it "does not pin an unknown path to a namespace known only by suffix" do
    files = {
      "app/models/billing/stripe/client.rb" =>
        "module Billing\n  module Stripe\n    class Client\n      def a = 1\n    end\n  end\nend",
      "app/jobs/sweep_job.rb" => "class SweepJob\n  def run = Stripe::RateLimitError\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, census, graph|
      expect(census.resolve(%w[Stripe RateLimitError])).to(be_nil)
      expect(graph.edges).to(be_empty)
    end
  end

  it "leaves a class's lexical scope behind once its body closes" do
    files = {
      "lib/app/alpha/one.rb" => <<~RUBY,
        module App
          module Alpha
            class One
              Util = 1
            end

            class Two
              def a = Util
            end
          end
        end
      RUBY
      "lib/app/core/util.rb" => "module App\n  class Util\n    def x = 1\n  end\nend\n"
    }
    analyze(files) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["alpha -> core"]))
    end
  end

  it "does not bind a bare name to a namespace that shares only its last segment" do
    files = {
      "app/lib/crm/i18n.rb" => "module Crm\n  module I18n\n    def self.t = 1\n  end\nend\n",
      "app/controllers/application_controller.rb" => "class ApplicationController\n  def t = I18n.t(:x)\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, census, graph|
      expect(graph.edges).to(be_empty)
      expect(census.resolve(%w[I18n], [%w[Crm]])).to(eq("lib"))
    end
  end

  it "resolves a constant inherited from a superclass, however far up" do
    files = {
      "app/base/parent.rb" => "class Parent\n  def a = 1\nend\n",
      "app/helpers/parent/helper.rb" => "class Parent::Helper\n  def h = 1\nend\n",
      "app/kids/child.rb" => "class Child < Parent\n  def h = Helper\nend\n",
      "app/grand/grand_child.rb" => "class GrandChild < Child\n  def h = Helper\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["grand -> helpers", "grand -> kids", "kids -> base", "kids -> helpers"]))
    end
  end

  it "resolves a ::-anchored superclass at top level before looking in it" do
    files = {
      "app/base/parent.rb" => "class Parent\n  class Helper\n    def h = 1\n  end\nend\n",
      "app/outer/outer.rb" => <<~RUBY
        module Outer
          class Parent
            def p = 1
          end

          class Child < ::Parent
            def h = Helper
          end
        end
      RUBY
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.evidence("outer", "base").to_a).to(eq(["outer/outer.rb:6: Parent", "outer/outer.rb:7: Helper"]))
    end
  end

  it "resolves a constant inherited from an included or prepended module" do
    files = {
      "app/mixins/mixin.rb" => "module Mixin\n  def m = 1\nend\n",
      "app/mixins/front.rb" => "module Front\n  def f = 1\nend\n",
      "app/tools/mixin/tool.rb" => "class Mixin::Tool\n  def t = 1\nend\n",
      "app/gears/front/gear.rb" => "class Front::Gear\n  def g = 1\nend\n",
      "app/models/user.rb" => "class User\n  include Mixin\n  prepend Front\n  def t = [Tool, Gear]\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["models -> gears", "models -> mixins", "models -> tools"]))
    end
  end

  it "looks only in modules the class itself includes, not ones it extends or sends include to" do
    files = {
      "app/mixins/side.rb" => "module Side\n  def s = 1\nend\n",
      "app/mixins/other.rb" => "module Other\n  def o = 1\nend\n",
      "app/tools/side/knob.rb" => "class Side::Knob\n  def k = 1\nend\n",
      "app/tools/other/lever.rb" => "class Other::Lever\n  def l = 1\nend\n",
      "app/models/user.rb" => "class User\n  include\n  extend Side\n  base.include Other\n  def t = [Knob, Lever]\nend"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["models -> mixins"]))
    end
  end

  it "does not climb into a superclass or constant reached through an expression" do
    files = {
      "app/base/parent.rb" => "class Parent\n  VERSIONS = 1\n  def a = 1\nend\n",
      "app/helpers/parent/helper.rb" => "class Parent::Helper\n  def h = 1\nend\n",
      "app/lookup/registry.rb" => "class Registry\n  def self.at = 1\nend\n",
      "app/kids/child.rb" => <<~RUBY
        class Child < factory::Parent
          def h = [Helper, namespace::Parent, self::VERSIONS, Registry.at::Parent]
        end
      RUBY
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["kids -> lookup"]))
    end
  end

  it "leaves a constant inherited from a class outside the project unresolved" do
    files = {
      "app/models/levels.rb" => "module Levels\n  ERROR = 1\n  def self.l = 1\nend\n",
      "app/lib/app_logger.rb" => "class AppLogger < ::Logger\n  def e = [ERROR, Levels]\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.evidence("lib", "models").to_a).to(eq(["lib/app_logger.rb:2: Levels"]))
    end
  end

  it "leaves a library namespace the project only reopens, in a file named for something else, to the library" do
    files = {
      "app/lib/huginn_scheduler.rb" => <<~RUBY,
        class Rufus::Scheduler
          TAG = "agent"

          class Job
            def agent = 1
          end
        end
      RUBY
      "app/runners/agent_runner.rb" =>
        "class AgentRunner\n  def s = [Rufus::Scheduler.new, Rufus::Scheduler::Job, Rufus::Scheduler::TAG]\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.evidence("runners", "lib").to_a).to(eq(["runners/agent_runner.rb:2: Rufus::Scheduler::TAG"]))
    end
  end

  it "does not let a namespace opened only to add autoloads claim the library's constants" do
    files = {
      "app/dispatch/action_dispatch.rb" =>
        "module Rack\n  autoload :Test, \"rack/test\"\nend\n\nmodule ActionDispatch\n  def self.d = 1\nend\n",
      "app/cable/cable.rb" => "class Cable\n  def c = [Rack, ::Rack::BodyProxy, Rack::Utils::OK, ActionDispatch]\nend"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.evidence("cable", "dispatch").to_a).to(eq(["cable/cable.rb:2: ActionDispatch"]))
    end
  end

  it "keeps a namespace the project derives classes in, whatever its file is named" do
    files = {
      "app/http/mime_type.rb" => "module Mime\n  class Type\n    def t = 1\n  end\n\n  class AllType < Type; end\nend",
      "app/controllers/renderer.rb" => "class Renderer\n  def r = Mime::Type\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["controllers -> http"]))
    end
  end

  it "owns what the project nests inside a class it derives under a core namespace, and nothing beside it" do
    files = {
      "app/ext/logging.rb" => <<~RUBY,
        class Logger
          class Tagged < Formatter
            class Hook
              def h = 1
            end
          end

          class Backend
            def b = 1
          end
        end
      RUBY
      "app/models/note.rb" => "class Note\n  def n = [Logger::Tagged::Hook, Logger::Backend, Logger]\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.evidence("models", "ext").to_a).to(eq(["models/note.rb:2: Logger::Tagged::Hook"]))
    end
  end

  it "counts a namespace as the project's own once it derives a class there, whatever the file is named" do
    files = {
      "app/ext/railtie.rb" => "module I18n\n  class Railtie < Base; end\n\n  class Backend\n    def b = 1\n  end\nend",
      "app/models/note.rb" => "class Note\n  def n = I18n::Backend\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["models -> ext"]))
    end
  end

  it "owns a constant the project assigns inside a core class it reopens" do
    files = {
      "app/ext/time.rb" => "class Time\n  DATE_FORMATS = {}\n\n  class Zone\n    def z = 1\n  end\nend\n",
      "app/models/note.rb" => "class Note\n  def n = [Time::DATE_FORMATS, Time::Zone, Time]\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.evidence("models", "ext").to_a).to(eq(["models/note.rb:2: Time::DATE_FORMATS"]))
    end
  end

  it "skips a class whose name did not parse when judging who owns what" do
    files = {
      "app/templates/helper.rb" => "module <%= class_name %>Helper\n  def x = 1\nend\n",
      "app/models/user.rb" => "class User\n  def u = 1\nend\n",
      "app/jobs/sweep.rb" => "class Sweep\n  def s = User\nend\n"
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.edges.map(&:to_s)).to(eq(["jobs -> models"]))
    end
  end

  it "resolves a superclass and a mixin in the scope that encloses them, then looks in them" do
    files = {
      "app/shop/base.rb" => "module Shop\n  class Base\n    class Helper\n      def h = 1\n    end\n  end\nend\n",
      "app/shop/tools.rb" => "module Shop\n  module Tools\n    class Wrench\n      def w = 1\n    end\n  end\nend\n",
      "app/models/user.rb" => "class User\n  def u = 1\nend\n",
      "app/kids/child.rb" => <<~RUBY
        module Shop
          class Child < Base
            include Tools

            def h = [Helper, Wrench]
          end
        end
      RUBY
    }
    analyze(files, directories: ["app"]) do |_project, _census, graph|
      expect(graph.weight("kids", "shop")).to(eq(4))
    end
  end
end
