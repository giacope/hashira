module Shop
  class Engine < ::Rails::Engine
    isolate_namespace Shop

    initializer "shop.broadcastable" do
      ActiveSupport.on_load(:active_record) { include Shop::Broadcastable }
    end

    initializer "shop.stray" do
      [1].each { include Shop::Stray }
    end
  end
end
