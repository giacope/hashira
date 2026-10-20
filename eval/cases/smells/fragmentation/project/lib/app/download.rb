module App
  class Download
    def initialize(url, directory)
      @url = url
      @directory = directory
    end

    def delete = File.delete(file_path)

    def size = File.size(file_path)

    def file_path = File.join(@directory, local_name)

    private

    def local_name = key + extension

    def extension = File.extname(@url)

    def key = @url.hash.to_s
  end
end
