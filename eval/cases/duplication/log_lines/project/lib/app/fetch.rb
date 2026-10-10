module App
  class Fetch
    def run(job)
      job.perform
    rescue Timeout::Error => error
      @reporter.notify(error, context: { job: job.id, attempt: job.attempts })
    end
  end
end
