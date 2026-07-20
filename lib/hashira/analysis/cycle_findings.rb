# frozen_string_literal: true

module Hashira
  module Analysis
    class CycleFindings < Rule
      KIND = "cycle"

      def list
        graph.packages.select { graph.cyclic?(it) }.sort.map { cycle_finding(it) }
      end

      private

      def cycle_finding(package)
        path = graph.cycle_path(package)
        finding(package:, cycle: path, evidence: evidence(path),
                message: message(package, path, graph.weakest_edge(path)))
      end

      def message(package, path, weak_edge)
        weak_from, weak_to = weak_edge
        weight = graph.weight(weak_from, weak_to)
        "#{package} can reach itself: #{path.join(" -> ")} — any change may ripple back " \
          "around. The lightest edge on this cycle is #{weak_from} -> #{weak_to} " \
          "(#{weight} ref#{"s" unless weight == 1})."
      end

      def evidence(path)
        path.each_cons(2).flat_map { |from, to| graph.evidence_for(from, to).to_a.first(2) }
      end
    end
  end
end
