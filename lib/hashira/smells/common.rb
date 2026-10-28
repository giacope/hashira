# frozen_string_literal: true

class Hashira::Smells::Common
  PERSISTENCE = %i[
    save save! update update! destroy destroy! delete reload persisted? new_record? destroyed? valid? invalid?
    errors touch lock! changed? changes attributes id
  ].freeze

  private_constant :PERSISTENCE

  def initialize(persistence = PERSISTENCE, messages = Hashira::Runtime::Messages.new)
    @persistence = persistence
    @messages = messages
  end

  def include?(name) = @persistence.include?(name) || @messages.universal?(name)
end
