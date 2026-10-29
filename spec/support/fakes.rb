# frozen_string_literal: true

# Small working stand-ins for hashira's collaborators, for specs that need an
# object with a collaborator's interface and none of its machinery.
module Fakes
  # A place a clone sits: the file it is in.
  Site = Data.define(:file)

  # A method's complexity: the file it is in and its cognitive score.
  Score = Data.define(:file, :cognitive)

  # The complexity analyzer: the method scores it ranked.
  Complexity = Data.define(:ranked)

  # The duplication analyzer: the clone mass it measured per file.
  Duplication = Data.define(:coverage)

  # A finding's detail: the fields it prints, and a phrase that names the package and the site.
  Detail =
    Data.define(:fields) do
      def to_h = fields

      def phrase(package) = "#{package} (#{fields[:site]})"
    end

  # A finding's CI mark, as the finding scores itself: its magnitude and its trace.
  Mark = Data.define(:magnitude, :trace)

  # A suppression directive that silences nothing and notes every anchor a finding asks it about.
  class Directive
    def initialize
      @asked = []
    end

    def covers?(_kind, anchor)
      @asked << anchor
      false
    end

    def to_a = @asked
  end

  # The hotspot rollup: the files it ranked, and whether churn weighed them.
  Hotspots =
    Data.define(:files, :weighed) do
      def weighed? = weighed
    end
end
