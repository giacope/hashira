# frozen_string_literal: true

class Hashira::Complexity::MethodScore
  OWNER = /[#.]/

  def initialize(subject, file, line, charges)
    @subject = subject
    @file = file
    @line = line
    @charges = charges
  end

  def cognitive = @charges.total

  def owner = @subject.split(OWNER, 2).first

  def charge = [@file, cognitive]

  def finding = Hashira::Complexity::MethodFinding.new(@subject, "#{@file}:#{@line}", @charges).to_finding

  def to_h = { subject: @subject, file: @file, line: @line, cognitive:, calls: @charges.count }

  def to_a = [@subject, cognitive, @charges.count, "#{@file}:#{@line}"]
end
