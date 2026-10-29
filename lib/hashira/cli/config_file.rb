# frozen_string_literal: true

require "yaml"

class Hashira::CLI::ConfigFile
  DEFAULT = ".hashira.yml"
  FLAGS = %w[fail-on skip kind top package-by baseline].freeze
  KEYS = ["directories", "checks", "strict", "layers", "boundaries", *FLAGS].freeze

  SWITCHES = [true, false].freeze

  def initialize(argv, home, checks = Hashira::Checks.new)
    @argv = argv
    @home = home
    @checks = checks
  end

  def rules
    blamed do
      raw = settings["checks"]
      parsed = settings.key?("checks") ? Hashira::Config::Rules.parse(raw, @checks.to_a) : Hashira::Config::Rules.new({})
      draft = Hashira::CLI::Draft.new(parsed, layers, declared)
      strict? ? draft.chosen(strict: true) : draft
    end
  end

  def vet
    argv = directories + flags.flatten
    blamed { yield(argv) }
  end

  def widened(argv, named)
    base = named.empty? ? argv + directories : argv
    flags.reduce(base) do |kept, flag|
      tried = kept + flag
      yield(tried) ? tried : kept
    end
  end

  private

  def directories = setting("directories").split(",")

  def flags = FLAGS.filter_map { |key| ["--#{key}", placed(key)] if settings.key?(key) }

  def path = @_path ||= chosen

  def chosen
    arguments = Hashira::CLI::Arguments.new(@argv)
    named = arguments.take("--config", "")
    arguments.drop("--no-config") ? unread(named) : read(named)
  end

  def read(named) = named.empty? ? fallback : named

  def unread(named) = named.empty? ? "" : raise(Hashira::Error, "conflicting options: --config and --no-config")

  def fallback
    found = @home.join(DEFAULT)
    File.exist?(found) ? found : ""
  end

  def strict?
    chosen = settings.fetch("strict", false)
    return chosen if SWITCHES.include?(chosen)
    raise(Hashira::Error, "strict takes true or false, not #{chosen.inspect}")
  end

  def layers = Hashira::Config::Layers.parse(settings["layers"], @home.path)

  def declared
    boundaries = settings.fetch("boundaries", [])
    return boundaries if boundaries.is_a?(Array)
    raise(Hashira::Error, "boundaries takes a list of declarations (root, role, entrypoint, reason)")
  end

  def placed(key) = key == "baseline" ? @home.expand(setting(key)) : setting(key)

  def settings = @_settings ||= path.empty? ? {} : checked(loaded)

  def loaded
    raise(Hashira::Error, "--config #{path.inspect} is not a file here") unless File.file?(path)
    YAML.safe_load_file(path) || {}
  rescue Psych::Exception => error
    raise(Hashira::Error, "#{path} is not plain YAML (#{error.message.delete_prefix("(#{path}): ")})")
  end

  def checked(raw)
    raise(Hashira::Error, "#{path}: expected key: value settings, not #{raw.inspect}") unless raw.is_a?(Hash)
    stray = (raw.keys - KEYS).first
    raise(Hashira::Error, "#{path}: unknown setting #{stray.inspect} (use: #{KEYS.join(", ")})") if stray
    raw
  end

  def setting(key)
    raw = settings.fetch(key, [])
    words = Array(raw)
    return words.join(",") if words.all? { it.is_a?(String) || it.is_a?(Integer) }
    raise(Hashira::Error, "#{path}: #{key} takes a value or a list of values, not #{raw.inspect}")
  end

  def blamed
    yield
  rescue Hashira::Error => error
    raise(Hashira::Error, "#{path}: #{error.message}")
  end
end
