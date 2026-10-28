class Topic < ApplicationRecord
  has_many :lists
  has_many :list_items, through: :lists

  def curated?
    lists.any?
  end

  def sort_mode
    curated? ? :curated : :a_to_z
  end

  def lists_without(item)
    lists.reject { |list| list.include?(item) }
  end

  def curated_paths
    list_items.map(&:base_path)
  end

  def uncurated(documents)
    documents.reject { |document| curated_paths.include?(document.base_path) }
  end

  def item_for(path)
    list_items.find { |item| item.base_path == path }
  end
end
