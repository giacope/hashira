# frozen_string_literal: true

class Hashira::Config::Layers
  Layer =
    Data.define(:name, :parts, :home) do
      def holds?(file, package) = parts.include?(package) || places.any? { file == it || file.start_with?("#{it}/") }

      def places = parts.map { File.expand_path(it, home) }
    end

  Entry =
    Data.define(:item, :home) do
      def layer
        name, parts = named
        listed = Array(parts)
        return Layer.new(name:, parts: listed, home:) if [name, *listed].all? { it.is_a?(String) && !it.empty? }
        raise(Hashira::Error, "layers takes a list, outermost first, of names or name: [packages or paths]")
      end

      def named
        case item
        when String then [item, [item]]
        when Hash then item.one? ? item.first : []
        else Array(item)
        end
      end
    end

  def self.parse(raw, home = ".") = new(Array(raw).map { Entry.new(item: it, home:).layer }).tap(&:vet)

  def initialize(list)
    @list = list
  end

  def any? = @list.any?

  def names = @list.map(&:name)

  def rank(file, package)
    key = [file, package]
    ranks.fetch(key) { ranks[key] = ranked(File.expand_path(file), package) }
  end

  def vet
    raise(Hashira::Error, "layers needs at least two layers to order") if @list.one?
    twice = repeated(names) || repeated(@list.flat_map(&:parts))
    raise(Hashira::Error, "layers names #{twice.inspect} more than once") if twice
  end

  private

  def ranks = @_ranks ||= {}

  def ranked(path, package) = @list.index { it.holds?(path, package) }

  def repeated(words) = words.tally.find { |_, count| count > 1 }&.first
end

Hashira::Config::Layers::NONE = Hashira::Config::Layers.new([])
