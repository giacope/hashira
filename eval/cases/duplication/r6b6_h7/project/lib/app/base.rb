module Shop
  class Base
    def path = File.join(directory, file_name)

    def directory = "/tmp"

    def file_name
      raise NotImplementedError,
            "The #{self.class} class must implement the #{__method__} method."
    end

    def render
      raise NotImplementedError,
            "The #{self.class} class must implement the #{__method__} method."
    end
  end
end
