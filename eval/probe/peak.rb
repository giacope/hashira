# frozen_string_literal: true

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

at_exit do
  report = ENV.fetch("EVALUATION_PEAK", nil)
  if report
    seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    kilobytes = File.read("/proc/self/status")[/VmHWM:\s+(\d+)/, 1].to_i
    File.write(report, "#{seconds} #{kilobytes}")
  end
end
