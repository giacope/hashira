# frozen_string_literal: true

class Hashira::Complexity::Entry
  def initialize(kind, file, subject, node)
    @kind = kind
    @file = file
    @subject = subject
    @node = node
  end

  def finding(detail, cited)
    evidence = cited.map { |node, note| "#{node.name} (line #{node.location.start_line})#{note}" }
    proof = Hashira::Analysis::Finding::Proof.new(evidence, [spot])
    Hashira::Analysis::Finding.new(@kind, Hashira::Analysis::Finding::Name.new(@subject), detail, proof)
  end

  def spot = "#{@file}:#{@node.location.start_line}"
end
