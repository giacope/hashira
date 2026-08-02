# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/"
  minimum_coverage line: 99, branch: 99
end

require "hashira"
require "tmpdir"

module FixtureHelper
  def within(files, &)
    Dir.mktmpdir do |dir|
      files.each do |path, source|
        full = File.join(dir, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, source)
      end
      Dir.chdir(dir, &)
    end
  end

  def pipeline(directories, packaging: :folder)
    project = Hashira::Project.new(directories)
    trees = project.files.to_h { [it, Prism.parse_file(it).value] }
    census = Hashira::Analysis::Census.new(project, trees, packaging:)
    [project, census, Hashira::Analysis::Graph.new(project, trees, census)]
  end

  def analyze(files, directories: ["lib/app"], packaging: :folder)
    within(files) { yield(*pipeline(directories, packaging:)) }
  end

  def with_pipeline(&)
    within(FixtureHelper::CYCLIC_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      yield(pipeline.project, pipeline.graph, Hashira::CI::Accepted.new([]).screen(pipeline.findings))
    end
  end

  def complexity(files, directories: ["lib/app"])
    within(files) do
      project = Hashira::Project.new(directories)
      yield(Hashira::Complexity::Analyzer.new(project, project.files.to_h { [it, Prism.parse_file(it).value] }))
    end
  end

  def smells(files, directories: ["lib/app"])
    within(files) do
      project = Hashira::Project.new(directories)
      yield(Hashira::Smells::Analyzer.new(project, project.files.to_h { [it, Prism.parse_file(it).value] }))
    end
  end

  def sniffed(files, kind)
    smells(files) { |analyzer| return analyzer.findings.select { it.kind == kind } }
  end

  def fragments(sources)
    project = Object.new
    def project.relative(path) = path
    sources.flat_map { |name, source| Hashira::Duplication::Extractor.new(project, { name => Prism.parse(source).value }).fragments }
  end

  def cluster(sources) = Hashira::Duplication::Clusterer.new(fragments(sources)).clusters.first

  def duplication(files, directories: ["lib/app"])
    within(files) do
      project = Hashira::Project.new(directories)
      yield(Hashira::Duplication::Analyzer.new(project, project.files.to_h { [it, Prism.parse_file(it).value] }, Hashira::Churn.new({})))
    end
  end

  def capture
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  CYCLIC_FILES = {
    "lib/app/alpha/one.rb" => <<~RUBY,
      module App
        module Alpha
          class One
            def call = Beta::Two.new
            def support = Core::Util.help
          end
        end
      end
    RUBY
    "lib/app/beta/two.rb" => <<~RUBY,
      module App
        module Beta
          class Two
            def call = Alpha::One.new
            def other = App::Alpha::One.name
          end
        end
      end
    RUBY
    "lib/app/core/util.rb" => <<~RUBY
      module App
        module Core
          class Util
            def self.help = 1
          end
        end
      end
    RUBY
  }.freeze

  NESTED_FILES = {
    "lib/app/core/search/finder.rb" => <<~RUBY,
      module App
        module Core
          module Search
            class Finder
              def run = Walk::Stepper.new
            end
          end
        end
      end
    RUBY
    "lib/app/core/walk/stepper.rb" => <<~RUBY
      module App
        module Core
          module Walk
            class Stepper
              def step = 1
            end
          end
        end
      end
    RUBY
  }.freeze

  RAILS_FILES = {
    "config/application.rb" => "module Sample; class Application; end; end\n",
    "app/models/billing/invoice.rb" => "module Billing\n  class Invoice\n    def pay = Ci::Runner.new\n  end\nend\n",
    "app/models/user.rb" => "class User < ApplicationRecord\n  def bill = Billing::Invoice.new\nend\n",
    "app/models/application_record.rb" => "class ApplicationRecord\n  def self.abstract = true\nend\n",
    "app/jobs/ci/runner.rb" => "module Ci\n  class Runner\n    def go = 1\n  end\nend\n"
  }.freeze

  SANDBOX_FILES = {
    "app/models/sandbox.rb" => "class Sandbox\n  def run = 1\nend\n",
    "app/models/sandbox/lifecycle.rb" => "module Sandbox::Lifecycle\n  def cycle = 1\nend\n",
    "app/resources/sandbox_resource.rb" =>
      "class SandboxResource < ApplicationResource\n  attributes :name\nend\n"
  }.freeze

  NOTIFY_FILES = {
    "app/models/notification.rb" => "class Notification\n  def read = 1\nend\n",
    "app/notifications/account_notification.rb" =>
      "class AccountNotification < Notification\n  def deliver = Billing::Invoice.new\nend\n",
    "app/notifications/grace_notification.rb" =>
      "class GraceNotification < AccountNotification\n  def deliver = 2\nend\n"
  }.freeze

  MIRROR_FILES = {
    "app/controllers/admin/accounts_controller.rb" => <<~RUBY,
      module Admin
        class AccountsController
          def show = Admin::Account.find(1)
        end
      end
    RUBY
    "app/controllers/agent/skills_controller.rb" => <<~RUBY,
      module Agent
        class SkillsController
          def index = Skill.all
        end
      end
    RUBY
    "app/models/admin/account.rb" => <<~RUBY,
      module Admin
        class Account
          def audit = Admin::AccountsController.log(self)
        end
      end
    RUBY
    "app/models/admin/settings.rb" => <<~RUBY,
      module Admin
        class Settings
          def flag = 1
        end
      end
    RUBY
    "app/models/agent/skill.rb" => <<~RUBY,
      module Agent
        class Skill
          def name = "skill"
        end
      end
    RUBY
    "app/models/agent/settings.rb" => <<~RUBY
      module Agent
        class Settings
          def flag = 2
        end
      end
    RUBY
  }.freeze

  COMPLEX_FILES = {
    "lib/app/knot/tangle.rb" => <<~RUBY
      module App
        module Knot
          class Tangle
            def self.helper = 1

            def simple = value

            def tangled(a, b, c, d)
              if a
                if b
                  if c
                    if d
                      e && f && g || h
                    end
                  end
                end
              end
            end
          end
        end
      end
    RUBY
  }.freeze

  DUPLICATION_FILES = {
    "lib/app/orders/checkout.rb" => <<~RUBY,
      module App
        module Orders
          class Checkout
            def run(gateway)
              gateway.configure(fetch(:host), fetch(:port))
              gateway.connect(retries: 3, timeout: 30)
              gateway.authorize(token: load(:tok), scope: :sale)
            end
          end
        end
      end
    RUBY
    "lib/app/billing/refund.rb" => <<~RUBY
      module App
        module Billing
          class Refund
            def run(gateway)
              gateway.configure(fetch(:host), fetch(:port))
              gateway.connect(retries: 3, timeout: 30)
              gateway.authorize(token: load(:tok), scope: :refund)
            end
          end
        end
      end
    RUBY
  }.freeze
end

RSpec.configure do |config|
  config.include(FixtureHelper)
  config.disable_monkey_patching!
  config.order = :random
end
