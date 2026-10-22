module App
  class Jobs
    def initialize(job)
      @job = job
    end

    def claim
      @job.claim! if @job.state == :open
      true
    end

    def mark
      @job.mark(@job.state == :open ? 1 : 2)
      true
    end

    def run = @job.state == :open ? 1 : 2

    def retry
      @job.reload
      @job.state == :open ? 1 : 2
    end
  end
end
