# frozen_string_literal: true

class Hashira::Report::Notices
  ISSUES = "https://github.com/giacope/hashira/issues"

  def initialize(io: $stderr)
    @io = io
  end

  def scanning(files) = interactive { @io.puts("hashira: reading #{files} files…") }

  def finished(files, seconds) = interactive { @io.puts("hashira: #{files} files in #{seconds}s") }

  def rails
    @io.puts("hashira: this looks like a Rails root — `hashira app` reads the application, not just lib/")
  end

  def churn(label)
    @io.puts("hashira: no git history for #{label} — hotspots are ranked by cost alone")
  end

  def crashed(error)
    @io.puts("hashira: internal error — #{error.class}: #{error.message}")
    @io.puts("  at #{error.backtrace.first}")
    @io.puts("  this is a bug in hashira — please report it at #{ISSUES}")
  end

  def unparsed(count, sample)
    @io.puts("hashira: #{count} of the files did not parse — #{sample}")
  end

  private

  def interactive
    yield if @io.tty?
  end
end
