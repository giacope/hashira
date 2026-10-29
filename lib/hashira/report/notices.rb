# frozen_string_literal: true

class Hashira::Report::Notices
  ISSUES = "https://github.com/giacope/hashira/issues"

  def initialize(io: $stderr)
    @io = io
  end

  def scanning(files, label) = progress("reading #{files} files in #{label}…")

  def finished(files, seconds) = progress("#{files} files in #{seconds}s")

  def crashed(error)
    @io.puts("hashira: internal error — #{error.class}: #{error.message}")
    @io.puts("  at #{error.backtrace.first}")
    @io.puts("  this is a bug in hashira — please report it at #{ISSUES}")
  end

  private

  def progress(line)
    @io.puts("hashira: #{line}") if @io.tty?
  end
end
