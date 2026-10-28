module Shop
  class Remote < Base
    def upload(name)
      dir_path.nil? ? name : File.join(dir_path, name)
    end
  end
end
