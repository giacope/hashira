module App
  class Fetch
    def run(job)
      @queue.push(job.source.fetch(limit: 10))
    rescue Timeout::Error => error
      @reporter.notify(error, context: { job: job.id, attempt: job.attempts })
    end
  end
end
