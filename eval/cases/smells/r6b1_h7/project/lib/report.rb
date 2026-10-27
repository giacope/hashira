class Report
  def initialize(project)
    @project = project
  end

  def rows
    @project.taxons.reduce({}) do |acc, taxon|
      acc.merge(taxon.content_id => { name: taxon.name, parent_id: taxon.parent_node.try(:content_id) })
    end
  end
end
