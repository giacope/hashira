module App
  module Pricing
    class Quote
      def promo = Promo::Code.new
      def again = Promo::Code.new
      def tax = Tax::Rule.new
      def levy = Tax::Rule.new
    end
  end
end
