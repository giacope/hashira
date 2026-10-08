# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Sink
  CALLS = %i[debug info warn error fatal report notify capture_exception capture_message notice_error].freeze
  OUTLETS = /log|error|exception|report|sentry|honeybadger|bugsnag|rollbar|airbrake|appsignal/i

  def initialize(node)
    @node = node
  end

  def sink? = @node.is_a?(Prism::CallNode) && CALLS.include?(@node.name) && OUTLETS.match?(@node.receiver&.slice)

  def message = strings.flat_map { walk(it).drop(1) }

  private

  def strings = walk(@node).grep(Prism::InterpolatedStringNode)

  def walk(node) = Hashira::Analysis::NodeWalk.collect(node)
end
