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
  def within_project(files, &)
    Dir.mktmpdir do |dir|
      files.each do |path, source|
        full = File.join(dir, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, source)
      end
      Dir.chdir(dir, &)
    end
  end

  def build_pipeline(directories)
    project = Hashira::Project.new(directories)
    trees = project.files.to_h { [it, Prism.parse_file(it).value] }
    census = Hashira::Analysis::Census.new(project, trees)
    [project, census, Hashira::Analysis::Graph.new(project, trees, census)]
  end

  def analyze(files, directories: ["lib/app"])
    within_project(files) { yield(*build_pipeline(directories)) }
  end

  def with_pipeline(&)
    within_project(FixtureHelper::CYCLIC_FILES) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      yield(pipeline.project, pipeline.graph, Hashira::CI::Accepted.new([]).screen(pipeline.findings))
    end
  end

  def analyze_complexity(files, directories: ["lib/app"])
    within_project(files) do
      project = Hashira::Project.new(directories)
      trees = project.files.to_h { [it, Prism.parse_file(it).value] }
      yield Hashira::Complexity::Analyzer.new(project, trees)
    end
  end

  def fragments_for(sources)
    project = Object.new
    def project.relative(path) = path
    sources.flat_map { |name, source| Hashira::Duplication::Extractor.new(project, { name => Prism.parse(source).value }).fragments }
  end

  def cluster_for(sources) = Hashira::Duplication::Clusterer.new(fragments_for(sources)).clusters.first

  def analyze_duplication(files, directories: ["lib/app"])
    within_project(files) do
      project = Hashira::Project.new(directories)
      trees = project.files.to_h { [it, Prism.parse_file(it).value] }
      yield Hashira::Duplication::Analyzer.new(project, trees, Hashira::Churn.new({}))
    end
  end

  def capture_stdout
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

  # A class whose `tangled` method scores 12 (four nested ifs + a mixed boolean
  # run), alongside a trivial method and a singleton method for subject shapes.
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

  # Two methods identical but for one symbol literal (:sale vs :refund) — an
  # exact clone the duplication analyzer should cluster and classify as literal.
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
  config.include FixtureHelper
  config.disable_monkey_patching!
  config.order = :random
end
