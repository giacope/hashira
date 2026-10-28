class ReportsController
  def initialize(report)
    @report = report
  end

  def deliver
    ReportJob.new.perform(@report.id)
  end
end
