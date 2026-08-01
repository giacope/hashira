# frozen_string_literal: true

module Hashira
  module Duplication
    Cluster =
      Data.define(:sites) do
        def canonical = sites.max_by { |site| [shapes(site), site.mass] }

        def shapes(site) = sites.count { |other| other.types == site.types }

        def others
          chosen = canonical
          sites.reject { |site| site.equal?(chosen) }
        end

        def identical = sites.select { it.types == canonical.types }

        def mass = canonical.mass

        def size = sites.size

        def masses = sites.map { [it.file, mass] }

        def structural? = others.all? { Variance.new(canonical, it).structural? }
      end
  end
end
