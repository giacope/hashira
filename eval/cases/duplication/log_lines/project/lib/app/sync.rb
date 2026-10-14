module App
  class Sync
    def run(job)
      job.perform(now: true, attempts: job.attempts + 1)
    rescue Timeout::Error => error
      @reporter.notify(error, context: { job: job.id, attempt: job.attempts })
    end
  end
end
