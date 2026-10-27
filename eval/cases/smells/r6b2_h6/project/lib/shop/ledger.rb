# frozen_string_literal: true

module Shop
  class Ledger
    attr_writer :total

    def initialize(total, mailer)
      @total = total
      @mailer = mailer
    end

    def add(sum) = @total += sum

    def take(sum) = @total -= sum

    def balance = @total

    def notify(text) = @mailer.deliver(text)

    def remind = @mailer.deliver("due")

    def ping = @mailer.ping

    def log(values) = values.each { |name, value| send("#{name}_at", value) }
  end
end
