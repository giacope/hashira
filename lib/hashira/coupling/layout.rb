# frozen_string_literal: true

class Hashira::Coupling::Layout
  def initialize(folders)
    @folders = folders
  end

  def root = @folders.root
end
