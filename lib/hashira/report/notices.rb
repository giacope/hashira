# frozen_string_literal: true

class Hashira::Report::Notices
  def initialize(io: $stderr)
    @io = io
  end

  def scanning(files) = interactive { @io.puts("hashira: reading #{files} files…") }

  def finished(files, seconds) = interactive { @io.puts("hashira: #{files} files in #{seconds}s") }

  def churn(label)
    @io.puts("hashira: no git history for #{label} — hotspots are ranked by cost alone")
  end

  def unparsed(count, sample)
    @io.puts("hashira: #{count} of the files did not parse — #{sample}")
  end

  private

  def interactive
    yield if @io.tty?
  end
end
