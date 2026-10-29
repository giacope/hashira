# frozen_string_literal: true

class Evaluation::Fixture
  def initialize(directory, project = Evaluation::Sandbox.new(File.join(directory, "project")))
    @directory = directory
    @project = project
  end

  def to_s = File.basename(@directory)

  def expect = YAML.safe_load_file(File.join(@directory, "expect.yml"))

  def copy(&) = @project.copy(&)
end
