# frozen_string_literal: true

module Hashira
  module Report
    class ComplexityTable
      TOP = 10
      METHOD_ROW = "%-44s %4s %6s  %s"
      CLASS_ROW = "%-32s %5s %8s %6s"

      def initialize(complexity, io: $stdout)
        @complexity = complexity
        @io = io
      end

      def print
        section(@complexity.methods, METHOD_ROW, %w[method Cog Calls Loc],
                "Cognitive complexity — worst methods (Cog = how hard to read, Calls = message sends)")
        section(@complexity.classes, CLASS_ROW, %w[class Cog Methods Peak],
                "Per-class rollup (Cog total survives extract-method; Peak is the worst method it hides)")
      end

      private

      def section(scores, row_format, columns, title)
        heading(row_format, columns, title)
        ranked(scores).each { @io.puts format(row_format, *it.cells) }
        @io.puts
      end

      def heading(row_format, columns, title)
        header = format(row_format, *columns)
        @io.puts "#{title}:\n\n"
        @io.puts header
        @io.puts "-" * header.length
      end

      def ranked(scores) = scores.select { it.cognitive.positive? }.first(TOP)
    end
  end
end
