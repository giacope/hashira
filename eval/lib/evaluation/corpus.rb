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

  def checks = runs.flat_map { |name, run| run.checks(name) }

  def measured = { "corpus" => metrics, "precision" => precision.summary }

  def park
    FileUtils.mkdir_p(@draw.pending)
    precision.pending.group_by(&:kind).each { |kind, list| shelve(kind, list) }
  end

  private

  def metrics = runs.to_h { |name, run| [name, run.metrics] }

  def precision = Evaluation::Precision.new(sightings, @settings.fetch("samples"), @draw)

  def sightings = runs.flat_map { |name, run| run.sightings(name) }

  def shelve(kind, list) = File.write(File.join(@draw.pending, "#{kind}.yml"), YAML.dump(list.map(&:entry)))

  def configs(name, home = Evaluation::Home.new) = home.join("tmp", "configs", "#{name}.yml")

  def runs = @_runs ||= @settings.fetch("projects").to_h { [it["name"], run(it)] }

  def run(project)
    home = checkout(project)
    Evaluation::Run.new(home, outcome(home, project))
  end

  def outcome(home, project)
    settings = project["config"]
    path = configs(project["name"])
    @tool.configure(settings, path)
    @tool.call(home, project.fetch("args") + @tool.arguments(settings, path) + ["--json"])
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
