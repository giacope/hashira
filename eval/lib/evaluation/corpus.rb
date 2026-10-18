# frozen_string_literal: true

class Evaluation::Corpus
  SUITE = "corpus"

  LIST = File.join(Evaluation::ROOT, "corpus.yml")

  def self.build(tool, root, draw) = new(tool, root, YAML.safe_load_file(LIST), draw)

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

  def runs = @_runs ||= @settings.fetch("projects").to_h { [it["name"], run(it)] }

  def run(project)
    home = checkout(project)
    path = File.join(Evaluation::ROOT, "tmp", "configs", "#{project["name"]}.yml")
    settings = @tool.configured(project["config"], path)
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
