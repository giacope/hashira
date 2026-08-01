# frozen_string_literal: true

class Hashira::CLI::Arguments
  def initialize(argv)
    @argv = argv.dup
  end

  def take(flag, default)
    position = @argv.index(flag)
    return default unless position
    _flag, value = @argv.slice!(position, 2)
    raise(Hashira::Error, "#{flag} needs a value") unless value
    value
  end

  def delete(flag) = @argv.delete(flag)

  def rest
    stray = @argv.find { it.start_with?("-") }
    raise(Hashira::Error, "unknown option #{stray}") if stray
    @argv
  end
end
