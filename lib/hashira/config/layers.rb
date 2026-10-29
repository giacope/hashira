# frozen_string_literal: true

class Hashira::Config::Layers
  Layer =
    Data.define(:name, :parts, :home, :marks, :rest) do
      def initialize(marks: [], rest: [], **) = super

      def holds?(file, package)
        parts.include?(package) || places.any? { file == it || file.start_with?("#{it}/") } || marks.any? do
          file.match?(it)
        end
      end

      def covers?(file) = rest.any? { file.start_with?("#{File.expand_path(it, home)}/") }

      def places = parts.map { File.expand_path(it, home) }
    end

  class Entry
    def initialize(item:, home:)
      @item = item
      @home = home
    end

    def layer
      name, parts = named
      listed = Array(parts)
      return Layer.new(name:, parts: listed, home:) if [name, *listed].all? { it.is_a?(String) && !it.empty? }
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

  PRESET = { "web" => { marks: PREVIEWS }, "app" => { rest: ["app"] } }.freeze

  INNER = %w[app domain].freeze

  def self.parse(raw, home = ".")
    preset = raw == "rails"
    layers = Array(preset ? RAILS : raw).map { Entry.new(item: it, home:).layer }
    new(preset ? layers.map { it.with(**PRESET.fetch(it.name, {})) } : layers, preset:).tap(&:vet)
  end

  def initialize(list, preset: false)
    @list = list
    @preset = preset
  end

  def any? = @list.any?

  def names = @list.map(&:name)

  def allows?(order) = !@preset || order.intersection(INNER) == INNER

  def rank(file, package)
    key = [file, package]
    ranks.fetch(key) { ranks[key] = ranked(File.expand_path(file), package) }
  end

  def vet
    raise(Hashira::Error, "layers needs at least two layers to order") if @list.one?
    twice = repeats(names) + repeats(@list.flat_map(&:parts))
    raise(Hashira::Error, "layers names #{twice.first.inspect} more than once") unless twice.empty?
  end

  private

  def ranks = @_ranks ||= {}

  def ranked(path, package) = @list.index { it.holds?(path, package) } || @list.index { it.covers?(path) }

  def repeats(words) = words.tally.select { |_, count| count > 1 }.keys
end
