class Entry < ApplicationRecord
  belongs_to :site
  delegate :hostname, :launch_date, to: :site

  def old_url
    "http://#{hostname}#{path}"
  end

  def launched?
    launch_date.present?
  end

  def label
    "#{hostname} (#{path})"
  end

  def organisation
    site.organisation
  end

  def tna_timestamp
    site.tna_timestamp
  end

  def site_title
    site.title
  end
end
