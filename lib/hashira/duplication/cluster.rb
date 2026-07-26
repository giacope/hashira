# frozen_string_literal: true

module Hashira
  module Duplication
    Cluster = Data.define(:sites) do
      def canonical = sites.max_by { |site| [shape_count(site), site.mass] }

      def shape_count(site) = sites.count { |other| other.types == site.types }

      def others
        chosen = canonical
        sites.reject { |site| site.equal?(chosen) }
      end

      def exact_sites = sites.select { it.types == canonical.types }

      def mass = canonical.mass

      def size = sites.size

      def site_masses = sites.map { [it.file, mass] }

      def shape_only? = others.all? { Variance.new(canonical, it).shape_only? }
    end
  end
end
