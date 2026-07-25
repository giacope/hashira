# frozen_string_literal: true

module Hashira
  module Duplication
    class Grouping
      def initialize(group)
        @group = group
      end

      def cluster
        sites = distinct
        Cluster.new(sites) if sites.size >= 2
      end

      private

      def distinct
        @group.sort_by { -it.mass }.each_with_object([]) do |fragment, kept|
          kept << fragment unless fragment.overlaps_any?(kept)
        end
      end
    end
  end
end
