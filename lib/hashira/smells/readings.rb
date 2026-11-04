# frozen_string_literal: true

require "prism"

class Hashira::Smells::Readings
  MINIMUM = 2

  class Use
    def initialize(user, names, line)
      @user = user
      @names = names
      @line = line
    end

    def fields = @names.map(&:to_s)

    def spot = @user.spot.at([@line])

    def to_s = "#{@user} reads #{fields.map { "'#{it}'" }.join(", ")} (#{spot})"
  end

  def initialize(methods, names, common = Hashira::Smells::Common.new)
    @methods = methods
    @names = names
    @common = common
  end

  def of(bag)
    @methods.select { bag.outside?(owner(it)) }.flat_map { |method| readings(method, bag) }
  end

  private

  def readings(method, bag)
    held(method).filter_map do |holder, calls|
      next unless bag.typed?(typed(holder, method))
      read = calls.map(&:name).uniq.select { bag.reads?(it, @common) }
      Use.new(method, read, calls.first.location.start_line) if read.size >= MINIMUM
    end
  end

  def owner(method) = (@_owners ||= {}.compare_by_identity)[method] ||= method.home.to_s

  def held(method)
    known = @_held ||= {}.compare_by_identity
    known.fetch(method) do
      calls = method.accept(Hashira::Smells::Scope).inside.grep(Prism::CallNode)
      copied = copies(calls)
      known[method] = calls.select { plain_read?(it) && copied.none?(it) }.group_by { holder(it.receiver) }.except(nil)
    end
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
    Hashira::Smells::Naming.new(holder).types.flat_map { @names.place(it, owner(method)) }.first(1)
  end
end
