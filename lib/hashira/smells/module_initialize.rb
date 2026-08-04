# frozen_string_literal: true

class Hashira::Smells::ModuleInitialize < Hashira::Smells::Check
  def self.judge? = true

  private

  def smelly? = subject.kind == :module && flagged

  def flagged = subject.owned.any? { it.node.name == :initialize }
end
