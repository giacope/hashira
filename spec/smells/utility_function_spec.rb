# frozen_string_literal: true

RSpec.describe(Hashira::Smells::UtilityFunction) do
  def utility(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "utility_function")
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

  it "exempts extend self modules like module_function ones, and advises a module function elsewhere" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          module Tools
            extend self

            def loud(word) = word.to_s
          end

          module Kit
            extend Tools
            Kit.extend self

            def quiet(word) = word.to_s
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Kit#quiet"]))
    expect(message(findings.first)).to(end_with("Move it onto the object it serves, or make it a module function."))
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

  it "traces a finding by the code it names, so a rename still matches and a different method does not" do
    shop = ->(name, body) { "module App\n  class Shop\n    def #{name}(price) = #{body}\n  end\nend\n" }
    traced = ->(name, body) { sniffed({ "lib/app/shop.rb" => shop[name, body] }, "utility_function").first.trace }
    tax = traced["tax", "price.round(2)"]
    alike = [traced["levy", "price.round(2)"], traced["discount", "price.floor(9)"]].map { it == tax }
    expect(alike).to(eq([true, false]))
  end

  it "treats what a concern defines for its host class as class-level" do
    findings = utility(<<~RUBY)
      module App
        module Zone
          module Greets
            included do
              private

              def veiled(word) = word.to_s
            end

            class_methods do
              def summon(word) = word.to_s
            end

            module ClassMethods
              def gather(word) = word.to_s
            end

            def greet(word) = word.to_s
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Greets#greet"]))
  end
end
