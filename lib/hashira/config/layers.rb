# frozen_string_literal: true

class Hashira::Config::Layers
  class Reach
    def initialize(marks = [], rest = [])
      @marks = marks
      @rest = rest
    end

    def marked?(file) = @marks.any? { file.match?(it) }

    def covers?(file, home) = @rest.any? { file.start_with?("#{File.expand_path(it, home)}/") }
  end

  class Layer
    def initialize(name, parts, home, reach = Hashira::Config::Layers::Reach.new)
      @name = name
      @parts = parts
      @home = home
      @reach = reach
    end

    def holds?(file, package)
      @parts.include?(package) || places.any? { file == it || file.start_with?("#{it}/") } || @reach.marked?(file)
    end

    def covers?(file) = @reach.covers?(file, @home)

    def preset(reaches) = Hashira::Config::Layers::Layer.new(@name, @parts, @home, reaches.fetch(@name, @reach))

    def to_s = @name

    def to_a = @parts

    private

    def places = @parts.map { File.expand_path(it, @home) }
  end

  class Entry
    def initialize(item:, home:)
      @item = item
      @home = home
    end

    def layer
      name, parts = named
      listed = Array(parts)
      return Layer.new(name, listed, home) if [name, *listed].all? { it.is_a?(String) && !it.empty? }
      raise(Hashira::Error, "layers takes a list, outermost first, of names or name: [packages or paths]")
    end

    def named
      case item
      when String then [item, [item]]
      when Hash then item.one? ? item.to_a.fetch(0) : []
      else Array(item)
      end
    end

    private

    attr_reader :item, :home
  end

  RAILS = [
    {
      "web" => %w[
        app/controllers app/views app/helpers app/components app/serializers app/presenters app/decorators
        app/policies app/avo app/dashboards app/mailers app/mailboxes app/channels
      ]
    },
    { "app" => %w[app/jobs app/workers app/services] },
    { "domain" => %w[app/models app/validators lib] }
  ].freeze

  PREVIEWS = [%r{/mailers/previews/}, /_preview\.rb\z/].freeze

  PRESET = { "web" => Reach.new(PREVIEWS), "app" => Reach.new([], ["app"]) }.freeze

  INNER = %w[app domain].freeze

  def self.parse(raw, home = ".")
    preset = raw == "rails"
    layers = Array(preset ? RAILS : raw).map { Entry.new(item: it, home:).layer }
    new(preset ? layers.map { it.preset(PRESET) } : layers, preset:).tap(&:vet)
  end

  def initialize(list, preset: false)
    @list = list
    @preset = preset
  end

  def names = @list.map(&:to_s)

  def allows?(order) = !@preset || order.intersection(INNER) == INNER

  def rank(file, package)
    key = [file, package]
    ranks.fetch(key) { ranks[key] = ranked(File.expand_path(file), package) }
  end

  def vet
    raise(Hashira::Error, "layers needs at least two layers to order") if @list.one?
    twice = repeats(names) + repeats(@list.flat_map(&:to_a))
    raise(Hashira::Error, "layers names #{twice.first.inspect} more than once") unless twice.empty?
  end

  private

  def ranks = @_ranks ||= {}

  def ranked(path, package) = @list.index { it.holds?(path, package) } || @list.index { it.covers?(path) }

  def repeats(words) = words.tally.select { |_, count| count > 1 }.keys
end
