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

  # The hotspot rollup: the files it ranked, and whether churn weighed them.
  Hotspots =
    Data.define(:files, :weighed) do
      def weighed? = weighed
    end
end
