# frozen_string_literal: true

class Hashira::CLI::Output
  ACTIONS = { update: :update, ratchet: :check, fail_on: :guard }
    .merge(json: :json, dot: :diagram, mermaid: :diagram).freeze

  private_constant :ACTIONS

  def initialize(mode, top, compact)
    @mode = mode
    @top = top
    @compact = compact
  end

  def action = ACTIONS.fetch(@mode, :text)

  def drawing(graph) = Hashira::Diagram::Source.new(graph, @mode)

  def layout = Hashira::Report::View::Layout.new(@top, @compact)

  def to_h = { mode: @mode, top: @top, compact: @compact }
end
