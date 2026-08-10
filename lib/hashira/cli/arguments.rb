# frozen_string_literal: true

class Hashira::CLI::Arguments
  def initialize(argv)
    @argv = argv.dup
  end

  def take(flag, default)
    position = @argv.index(flag)
    return default unless position
    _flag, value = @argv.slice!(position, 2)
    vet(flag, value)
  end

  def vet(flag, value)
    raise(Hashira::Error, "#{flag} needs a value") if value.to_s.strip.empty?
    raise(Hashira::Error, "#{flag} given more than once") if @argv.include?(flag)
    value
  end

  def delete(flag) = @argv.delete(flag)

  def rest
    stray = @argv.find { it.start_with?("-") }
    raise(Hashira::Error, "unknown option #{stray}") if stray
    @argv
  end
end
