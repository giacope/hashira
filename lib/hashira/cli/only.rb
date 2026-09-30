# frozen_string_literal: true

module Hashira::CLI::Only
  module_function

  def parse(value)
    value.split(",").flat_map { expand(vet(it.strip)) }
  end

  def vet(path)
    here = path.delete_suffix("/").delete_prefix("#{Dir.pwd}/").delete_prefix("./")
    raise(Hashira::Error, "--only #{path.inspect} is not a file or directory here") unless File.exist?(here)
    here
  end

  def expand(path)
    return [path] if File.file?(path)
    found = Dir["#{path}/**/*.rb"].map { it.delete_prefix("./") }
    raise(Hashira::Error, "--only #{path.inspect} holds no Ruby files") if found.empty?
    found
  end
end
