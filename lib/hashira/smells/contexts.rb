# frozen_string_literal: true

require "prism"

module Hashira
  module Smells
    class Parameters
      NAMELESS = [Prism::ForwardingParameterNode, Prism::ImplicitRestNode, Prism::NoKeywordsParameterNode].freeze

      OPTIONAL = [Prism::OptionalParameterNode, Prism::OptionalKeywordParameterNode].freeze

      def initialize(definition)
        @definition = definition
      end

      def names = parts.flat_map { expand(it) }

      def arguments = parts.grep_v(Prism::BlockParameterNode).flat_map { expand(it) }

      def named(kinds) = parts.select { kinds.include?(it.class) }.flat_map { expand(it) }

      def nils = parts.select { OPTIONAL.include?(it.class) && it.value.is_a?(Prism::NilNode) }.flat_map { expand(it) }

      private

      def parts
        node = @definition.parameters
        return [] unless node
        node.requireds + node.optionals + node.posts + node.keywords +
          [node.rest, node.keyword_rest, node.block].compact
      end

      def expand(part)
        case part
        when Prism::MultiTargetNode then pieces(part).flat_map { expand(it) }
        when *NAMELESS then []
        else [part.name].compact
        end
      end

      def pieces(part) = part.lefts + Array(part.rest&.expression) + part.rights
    end

    class Sort
      LEVEL = "::ClassMethods"

      private_constant :LEVEL

      def initialize(kind, handed, claimed)
        @kind = kind
        @handed = handed
        @claimed = claimed
      end

      def class? = @kind == :class

      def claimed? = @claimed

      def owner(name) = @kind == :module && @handed ? name.delete_suffix(LEVEL) : name

      def walk(node)
        @handed ? Hashira::Analysis::TypeWalk.new(node).sections : Hashira::Analysis::TypeWalk.new(node).written
      end
    end

    class Seat
      def initialize(name, node, file, sort)
        @name = name
        @node = node
        @file = file
        @sort = sort
      end

      def at(line = @node.location.start_line) = "#{@file}:#{line}"

      def named?
        short, long = [spelled(@file.delete_suffix(".rb"), "/"), spelled(@name, "::")].sort_by(&:size)
        long.last(short.size) == short
      end

      def class? = @sort.class?

      def claimed? = @sort.claimed?

      private

      def spelled(text, separator) = text.downcase.delete("_").split(separator)
    end

    class Locus
      def initialize(file, node)
        @file = file
        @node = node
      end

      def to_s = @file

      def site = at([line])

      def at(lines) = "#{@file}:#{lines.uniq.join(", ")}"

      def line = @node.location.start_line

      def shape = Shape.new([@node.parameters, @node.body].compact.flat_map { Marks.new(it).to_a })
    end

    class Standing
      def initialize(node, section, protocol)
        @node = node
        @section = section
        @protocol = protocol
      end

      def public? = @section == :public && !singleton?

      def singleton? = @node.receiver.is_a?(Prism::Node) || @section == :singleton

      def polymorphic? = @protocol.include?(@node.name)

      def in?(sections) = sections.include?(@section)
    end

    class Home
      def initialize(owner, node, sort)
        @owner = owner
        @node = node
        @sort = sort
      end

      def to_s = @owner

      def accept(reader, *) = reader.new(@node, *)

      def class? = @sort.class?

      def neighbors = Hashira::Analysis::TypeWalk.new(@node).sections.map { |definition, _| definition.name }
    end

    class Place
      def initialize(owner, file, node, sort)
        @owner = owner
        @file = file
        @node = node
        @sort = sort
      end

      def spot(definition) = Locus.new(@file, definition)

      def home = Home.new(@owner, @node, @sort)
    end

    class MethodContext
      def initialize(node, section, protocol, place)
        @node = node
        @section = section
        @protocol = protocol
        @place = place
      end

      def to_s = "#{home}#{standing.singleton? ? "." : "#"}#{@node.name}"

      def accept(reader, *) = reader.new(@node, *)

      def spot = @place.spot(@node)

      def standing = Standing.new(@node, @section, @protocol)

      def home = @place.home
    end

    class Lot
      def initialize(assigned, heirs)
        @assigned = assigned
        @heirs = heirs
      end

      def known? = @assigned.any?

      def assumed(reads) = (reads - fields).uniq.sort.reject { cache?(it) || computed?(it) }

      def installed(names) = names & @heirs

      def assigned?(name, &) = @assigned.fetch(0, &).include?(name)

      private

      def fields = @assigned.fetch(0, [])

      def cache?(name) = name.start_with?("@_")

      def computed?(name) = fields.grep(String).any? { name.start_with?(it) }
    end

    class Sketch
      def initialize(name, node, file, sort)
        @name = name
        @node = node
        @file = file
        @sort = sort
      end

      def to_s = @name

      def accept(reader, *) = reader.new(@node, *)

      def seat = Seat.new(@name, @node, @file, @sort)

      def settle(protocol, assigned, heirs)
        frame = Frame.new(@name, @file, @sort, protocol)
        TypeContext.new(@node, frame, assigned, heirs)
      end
    end

    class Frame
      def initialize(name, file, sort, protocol)
        @name = name
        @file = file
        @sort = sort
        @protocol = protocol
      end

      def to_s = @name

      def seat(node) = Seat.new(@name, node, @file, @sort)

      def routines(node)
        @sort.walk(node).map do |definition, section|
          owner = definition.receiver ? @name : @sort.owner(@name)
          MethodContext.new(definition, section, @protocol, Place.new(owner, @file, node, @sort))
        end
      end
    end

    class TypeContext
      include Enumerable

      def initialize(node, frame, assigned, heirs)
        @node = node
        @frame = frame
        @assigned = assigned
        @heirs = heirs
      end

      def to_s = @frame.to_s

      def accept(reader, *) = reader.new(@node, *)

      def each(&) = routines.each(&)

      def seat = @frame.seat(@node)

      def lot = Lot.new(@assigned, @heirs)

      private

      def routines = @_routines ||= @frame.routines(@node)
    end
  end
end
