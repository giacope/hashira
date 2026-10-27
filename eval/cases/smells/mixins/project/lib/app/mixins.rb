module App
  module Loud
    def shout = "#{@text.upcase}!"
  end

  module Trackable
    extend ActiveSupport::Concern

    included do
      after_save :track
    end

    def track = Analytics.event("#{self.class.name}.saved", id: id)
  end

  module Sized
    def resize(size)
      @size = size
    end
  end

  module Ordered
    include Comparable

    def <=>(other) = key <=> other.key
  end

  module Shared
    extend self

    def settings = @settings
  end

  class Message
    include Loud
    include Sized

    def initialize(text, subject, body)
      @text = text
      @subject = subject
      @body = body
    end

    def subject = @subject

    def body = @body

    def recipient = "all"
  end

  class UrgentMessage
    def initialize(origin)
      @origin = origin
    end

    def subject = "URGENT: #{@origin.subject}"

    def body = @origin.body

    def recipient = @origin.recipient
  end
end
