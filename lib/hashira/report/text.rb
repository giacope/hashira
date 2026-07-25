# frozen_string_literal: true

module Hashira
  module Report
    class Text
      def initialize(view, io: $stdout)
        @view = view
        @io = io
      end

      def print
        coupling_sections if @view.graph
        complexity_section if @view.complexity
        hotspot_section if @view.hotspots
        findings_section
        0
      end

      private

      def coupling_sections
        graph = @view.graph
        header(graph)
        MetricsTable.new(graph, io: @io).print
        DependencyMap.new(graph, io: @io).print
      end

      def complexity_section = ComplexityTable.new(@view.complexity, io: @io).print

      def hotspot_section = HotspotTable.new(@view.hotspots, io: @io).print

      def header(graph)
        project = @view.project
        packages = graph.packages.size
        @io.puts "Package (layer) metrics for #{project.label}  " \
                 "(#{packages} packages, #{project.files.size} files)\n\n"
        single_package_note if packages == 1
      end

      def single_package_note
        @io.puts "Only one package found — there are no boundaries to analyze. " \
                 "Pass subdirectories to set them (e.g. hashira lib/gem/*/).\n\n"
      end

      def findings_section
        all = @view.findings.all
        @io.puts "\nFindings (#{all.size}):"
        print_findings(all)
        accepted_section
        @io.puts "\n  Full evidence + machine format: hashira --json" unless all.empty?
      end

      def print_findings(all)
        return @io.puts "  none ✓ — structure is healthy" if all.empty?

        all.each { FindingLines.new(it, indent: "  ", io: @io).print_with_overflow }
      end

      def accepted_section
        accepted = @view.findings.accepted
        return if accepted.empty?

        @io.puts "\nAccepted (#{accepted.size}):"
        accepted.each { |finding, reason| @io.puts "  ~ #{finding.kind}/#{finding.package} — #{reason}" }
      end
    end
  end
end
