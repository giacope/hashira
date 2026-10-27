class Hit < ApplicationRecord
  def error?
    http_status == "404"
  rescue StandardError
    raise
  end

  def archive?
    http_status == "410"
  end

  def redirect?
    http_status == "301"
  end

  def homepage?
    path == "/"
  rescue StandardError
    raise
  end

  def default_url
    "http://#{hostname}#{path}"
  end

  def short_path
    path.first(10)
  end
end
