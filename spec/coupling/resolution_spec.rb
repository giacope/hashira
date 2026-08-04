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
  it "still couples to a core class the project reopens at top level" do
    files = {
      "app/ext/string.rb" => "class String\n  def shout = upcase\nend\n",
      "app/models/note.rb" => "class Note\n  def s = String\nend\n"
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
end
