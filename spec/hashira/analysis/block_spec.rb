# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Block, :aggregate_failures) do
  def owners(source)
    Hashira::Analysis::TypeWalk.new(Prism.parse(source).value).to_enum(:walk).map do |node, full, _stack, lexical|
      [full.join("::"), lexical.join("::"), Hashira::Analysis::TypeWalk.new(node).sections.map { it.first.name }]
    end
  end

  it "gives the defs of a DSL block the constant its call names, or an owner of their own, never the module's" do
    source = <<~RUBY
      module Auth
        Feature.define(:login, :Login) do
          def login = 1
          class Error < StandardError; end
        end
        Feature.define(:jwt, "Jwt", "jwt") { def jwt = 1 }
        configure do
          def tuned = 1
        end
        def own
          configure { def nested = 1 }
        end
        setting(:x) { 1 }
      end
      Toplevel.describe do
        def helper = 1
      end
    RUBY
    expect(owners(source)).to(
      eq(
        [
          ["Auth", "Auth", %i[own]], ["Auth::Login", "Auth", %i[login]], ["Auth::Error", "Auth::Error", []],
          ["Auth::Jwt", "Auth", %i[jwt]], ["Auth::(configure block, line 7)", "Auth", %i[tuned]]
        ]
      )
    )
  end

  it "keeps the owner of a block that reopens the class or builds one, and gives a constant the blocks it opens" do
    source = <<~RUBY
      module Kept
        included do
          def a = 1
        end
        class_methods do
          def b = 1
        end
        concerning(:Tags) { def c = 1 }
        class_eval { def d = 1 }
        self.class_eval { def e = 1 }
        Struct.new(:x) { def f = 1 }
        ::Class.new { def g = 1 }
        Data.define(:y) { def h = 1 }
        Other.class_eval { def j = 1 }
        Data.new { def k = 1 }
        ::Rack::Request.prepend(Module.new { def m = 1 })
        Other.include(Module.new, Module.new { def n = 1 })
        Other.extend(Module.new { def o = 1 })
      end
    RUBY
    expect(owners(source)).to(
      eq(
        [
          ["Kept", "Kept", %i[a b c d e f g h n o]], ["Other", "Other", %i[j]],
          ["Kept::(new block, line 15)", "Kept", %i[k]], ["Rack::Request", "Rack::Request", %i[m]]
        ]
      )
    )
  end

  it "gives the class the defs of a block it evaluates in itself, and names a refinement by what it refines" do
    source = <<~RUBY
      class Cli < Thor
        no_tasks { def helper = 1 }
        no_commands { def other = 1 }
      end
      class Web < Sinatra::Base
        helpers do
          def money = 1
        end
      end
      class Site < Middleman::Extension
        helpers do
          def link = 1
        end
      end
      module Ext
        refine ::String do
          def shout = 1
        end
      end
      class Bare
        helpers do
          def plain = 1
        end
      end
    RUBY
    expect(owners(source)).to(
      eq(
        [
          ["Cli", "Cli", %i[helper other]], ["Web", "Web", %i[money]], ["Site", "Site", []],
          ["Site::(helpers block, line 11)", "Site", %i[link]], ["Ext", "Ext", []],
          ["Ext refine ::String", "Ext", %i[shout]], ["Bare", "Bare", []],
          ["Bare::(helpers block, line 21)", "Bare", %i[plain]]
        ]
      )
    )
  end
end
