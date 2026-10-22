# frozen_string_literal: true

class Evaluation::Sandbox
  def initialize(source)
    @source = source
  end

  def open
    Dir.mktmpdir("evaluation") do |root|
      @source.each { |path, text| write(File.join(root, path), text) }
      yield(root)
    end
  end

  def copy
    Dir.mktmpdir("evaluation") do |root|
      FileUtils.cp_r("#{@source}/.", root)
      yield(root)
    end
  end

  def expectations = Dir["#{@source}/*/expect.yml"].map { File.dirname(it) }

  private

  def write(path, text)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end
end
