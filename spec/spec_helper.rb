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
    trees = project.files.to_h { [_1, Prism.parse_file(_1).value] }
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
end

RSpec.configure do |config|
  config.include FixtureHelper
  config.disable_monkey_patching!
  config.order = :random
end
