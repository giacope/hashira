# frozen_string_literal: true

module Hashira::CLI::Only
  module_function

  def parse(value)
    return [] if value.empty?
    value.split(",").map { vet(it.strip) }
  end

  def vet(path)
    here = path.delete_prefix("#{Dir.pwd}/").delete_prefix("./")
    raise(Hashira::Error, "--only #{path.inspect} is not a file here") unless File.file?(here)
    here
  end
end
