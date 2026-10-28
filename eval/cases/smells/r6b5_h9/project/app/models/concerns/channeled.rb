module Channeled
  def channel = Channel.named(to_param)
end
