# frozen_string_literal: true

class Evaluation::Corpus
  def self.build(tool, root, draw, sizes = {})
    settings = Evaluation::Home.new.yaml("corpus.yml")
    new(tool, root, sizes.empty? ? settings : settings.merge("samples" => sizes), draw)
  end

  def initialize(tool, root, settings, draw)
    @tool = tool
    @root = root
    @settings = settings
    @draw = draw
  end

  def metrics = runs.to_h { |name, run| [name, run.metrics] }

  def checks = runs.flat_map { |name, run| run.checks(name) }

  def precision
    Evaluation::Precision.new(sightings, @settings.fetch("samples"), @draw)
  end

  def sightings = runs.flat_map { |name, run| run.sightings(name) }

  private

  def configs(name, home = Evaluation::Home.new) = home.join("tmp", "configs", "#{name}.yml")

  def runs = @_runs ||= @settings.fetch("projects").to_h { [it["name"], run(it)] }

  def run(project)
    home = checkout(project)
    settings = @tool.configured(project["config"], configs(project["name"]))
    Evaluation::Run.new(home, @tool.call(home, project.fetch("args") + settings + ["--json"]))
  end

  def checkout(project)
    home = File.join(@root, project["name"])
    clone(project, home) unless Dir.exist?(home)
    pinned = Open3.capture2("git", "-C", home, "rev-parse", "HEAD").first.strip
    raise(ArgumentError, "#{home} is at #{pinned}, not #{project["sha"]}") unless pinned == project["sha"]
    home
  end

  def clone(project, home)
    system("git", "clone", "--quiet", project["url"], home, exception: true)
    system("git", "-C", home, "checkout", "--quiet", project["sha"], exception: true)
  end
end
