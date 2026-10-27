class ReportJob
  include Sidekiq::Job

  def perform(report_id)
    Report.find(report_id).deliver
  end
end
