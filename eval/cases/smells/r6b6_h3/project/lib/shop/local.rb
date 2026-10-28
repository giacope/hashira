module Shop
  class Local < Base
    def upload(name)
      dir_path.nil? ? name : File.join(dir_path, name)
    end
  end
end
