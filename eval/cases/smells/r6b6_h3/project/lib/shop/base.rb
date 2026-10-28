module Shop
  class Base
    def initialize(dir)
      @dir = dir
    end

    def within(dir)
      @dir = dir
    end

    private

    def dir_path
      if @dir.empty?
        nil
      else
        File.join(@dir)
      end
    end
  end
end
