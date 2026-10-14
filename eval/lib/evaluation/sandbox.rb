# frozen_string_literal: true

module Evaluation::Sandbox
  module_function

  def open(files)
    Dir.mktmpdir("evaluation") do |root|
      files.each { |path, text| write(File.join(root, path), text) }
      yield(root)
    end
  end

  def copy(fixture)
    Dir.mktmpdir("evaluation") do |root|
      FileUtils.cp_r("#{fixture}/.", root)
      yield(root)
    end
  end

  def write(path, text)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  def expectations(root) = Dir["#{root}/*/expect.yml"].map { File.dirname(it) }
end
