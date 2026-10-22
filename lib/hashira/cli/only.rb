# frozen_string_literal: true

class Hashira::CLI::Only
  def initialize(flag)
    @flag = flag
  end

  def parse(value) = value.split(",").flat_map { expand(vet(it.strip)) }

  private

  def vet(path)
    here = path.delete_suffix("/").delete_prefix("#{Dir.pwd}/").delete_prefix("./")
    raise(Hashira::Error, "#{@flag} #{path.inspect} is not a file or directory here") unless File.exist?(here)
    here
  end

  def expand(path)
    return [path] if File.file?(path)
    found = Dir["#{path}/**/*.rb"].map { it.delete_prefix("./") }
    raise(Hashira::Error, "#{@flag} #{path.inspect} holds no Ruby files") if found.empty?
    found
  end
end
