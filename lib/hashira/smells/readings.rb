# frozen_string_literal: true

require "prism"

class Hashira::Smells::Readings
  PERSISTENCE = %i[
    save save! update update! destroy destroy! delete reload persisted? new_record? destroyed? valid? invalid?
    errors touch lock! changed? changes attributes id
  ].freeze

  MINIMUM = 2

  Use =
    Data.define(:user, :fields, :line) do
      def spot = "#{user.file}:#{line}"

      def to_s = "#{user.subject} reads #{fields.map { "'#{it}'" }.join(", ")} (#{spot})"
    end

  def initialize(methods)
    @methods = methods
  end

  def of(bag)
    home = bag.name.sub(/::[^:]+\z/, "")
    @methods.reject { [bag.name, home].include?(it.owner) }.flat_map { |method| readings(method, bag) }
  end

  private

  def readings(method, bag)
    held(method).filter_map do |holder, calls|
      next unless typed(holder, method) == bag.name
      read = calls.map(&:name).uniq.select { reader?(it, bag) }
      Use.new(user: method, fields: read.map(&:to_s), line: calls.first.location.start_line) if read.size >= MINIMUM
    end
  end

  def reader?(name, bag)
    bag.fields ? bag.fields.include?(name) : !PERSISTENCE.include?(name) && !Hashira::Analysis::UNIVERSAL.include?(name)
  end

  def held(method)
    calls = Hashira::Smells::Scope.new(method.node).inside.grep(Prism::CallNode)
    copied = copies(calls)
    calls.select { plain_read?(it) && copied.none?(it) }.group_by { holder(it.receiver) }.except(nil)
  end

  def copies(calls) = calls.select { it.name == :new }.flat_map { Array(it.arguments&.arguments) }

  def plain_read?(call) = !call.arguments && !call.block && call.name.match?(/\A[a-z_]\w*\z/)

  def holder(receiver)
    case receiver
    when Prism::InstanceVariableReadNode then receiver.name.to_s.delete_prefix("@")
    when Prism::LocalVariableReadNode then receiver.name.to_s
    end
  end

  def typed(holder, method)
    Hashira::Smells::Naming.new(holder).types.filter_map { method.ownership.place(it, method.owner) }.first
  end
end
