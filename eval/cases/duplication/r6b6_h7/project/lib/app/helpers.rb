module Shop
  module Helpers
    def relative(file) = (root + file).relative_path_from(directory)

    private

    def directory
      raise NotImplementedError,
            "The #{self.class} class must implement the #{__method__} method."
    end

    def root
      raise NotImplementedError,
            "The #{self.class} class must implement the #{__method__} method."
    end
  end
end
