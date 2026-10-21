module App
  module Guard
    class Critical
      PATHS = %w[app/api/client.rb].freeze

      def include?(path) = PATHS.any? { path.end_with?(it) }
    end
  end
end
