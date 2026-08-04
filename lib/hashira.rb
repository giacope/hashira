# frozen_string_literal: true

module Hashira
  module Analysis
  end

  module CI
  end

  module Coupling
  end

  module Complexity
  end

  module Diagram
  end

  module Duplication
  end

  module Hotspots
  end

  module Report
  end

  module Smells
  end
end

require_relative "hashira/analysis/finding"
require_relative "hashira/analysis/node_walk"
require_relative "hashira/analysis/syntax"
require_relative "hashira/analysis/type_walk"
require_relative "hashira/churn"
require_relative "hashira/ci/accepted"
require_relative "hashira/ci/baseline"
require_relative "hashira/ci/diff"
require_relative "hashira/ci/edge_diff_report"
require_relative "hashira/ci/finding_diff_report"
require_relative "hashira/ci/gate"
require_relative "hashira/ci/improvement"
require_relative "hashira/ci/ratchet"
require_relative "hashira/ci/ratchet_report"
require_relative "hashira/cli"
require_relative "hashira/cli/arguments"
require_relative "hashira/cli/command_line"
require_relative "hashira/cli/fail_on"
require_relative "hashira/cli/options"
require_relative "hashira/cli/package_by"
require_relative "hashira/cli/run"
require_relative "hashira/cli/skip"
require_relative "hashira/cli/usage"
require_relative "hashira/complexity/boolean_run"
require_relative "hashira/complexity/cognitive_score"
require_relative "hashira/complexity/if_chain"
require_relative "hashira/complexity/method_finding"
require_relative "hashira/complexity/method_score"
require_relative "hashira/complexity/rescue_scan"
require_relative "hashira/complexity/rollup"
require_relative "hashira/complexity/scores"
require_relative "hashira/coupling/audiences"
require_relative "hashira/coupling/catalog"
require_relative "hashira/coupling/census"
require_relative "hashira/coupling/constant_registry"
require_relative "hashira/coupling/cycle_findings"
require_relative "hashira/coupling/cycle_search"
require_relative "hashira/coupling/cycles"
require_relative "hashira/coupling/definition"
require_relative "hashira/coupling/definitions"
require_relative "hashira/coupling/edge"
require_relative "hashira/coupling/edge_map"
require_relative "hashira/coupling/folder_placement"
require_relative "hashira/coupling/folding"
require_relative "hashira/coupling/graph"
require_relative "hashira/coupling/metric"
require_relative "hashira/coupling/mixed_audience_findings"
require_relative "hashira/coupling/namespace_placement"
require_relative "hashira/coupling/namespace_prefix"
require_relative "hashira/coupling/naming"
require_relative "hashira/coupling/no_folding"
require_relative "hashira/coupling/placement"
require_relative "hashira/coupling/references"
require_relative "hashira/coupling/report"
require_relative "hashira/coupling/roll_call"
require_relative "hashira/coupling/roll_call_findings"
require_relative "hashira/coupling/roster"
require_relative "hashira/coupling/rule"
require_relative "hashira/coupling/scope"
require_relative "hashira/coupling/sdp_check"
require_relative "hashira/coupling/sdp_violation_findings"
require_relative "hashira/coupling/wide_edge_findings"
require_relative "hashira/coupling/words"
require_relative "hashira/diagram/dot"
require_relative "hashira/diagram/mermaid"
require_relative "hashira/diagram/source"
require_relative "hashira/duplication/clones"
require_relative "hashira/duplication/cluster"
require_relative "hashira/duplication/clusters"
require_relative "hashira/duplication/delta"
require_relative "hashira/duplication/duplication_finding"
require_relative "hashira/duplication/fragment"
require_relative "hashira/duplication/grouping"
require_relative "hashira/duplication/harvest"
require_relative "hashira/duplication/index"
require_relative "hashira/duplication/maximal"
require_relative "hashira/duplication/near_miss"
require_relative "hashira/duplication/sequence"
require_relative "hashira/duplication/similarity"
require_relative "hashira/duplication/union_find"
require_relative "hashira/duplication/variance"
require_relative "hashira/error"
require_relative "hashira/hotspots/file_cost"
require_relative "hashira/hotspots/rollup"
require_relative "hashira/pipeline"
require_relative "hashira/project"
require_relative "hashira/report/complexity_table"
require_relative "hashira/report/dependency_map"
require_relative "hashira/report/finding_lines"
require_relative "hashira/report/graph_payload"
require_relative "hashira/report/hotspot_table"
require_relative "hashira/report/json"
require_relative "hashira/report/metrics_table"
require_relative "hashira/report/phrases"
require_relative "hashira/report/smell_phrases"
require_relative "hashira/report/text"
require_relative "hashira/report/view"
require_relative "hashira/smells/census"
require_relative "hashira/smells/check"
require_relative "hashira/smells/conditions"
require_relative "hashira/smells/contexts"
require_relative "hashira/smells/control_parameter"
require_relative "hashira/smells/data_clump"
require_relative "hashira/smells/duplicate_method_call"
require_relative "hashira/smells/feature_envy"
require_relative "hashira/smells/instance_variable_assumption"
require_relative "hashira/smells/manual_dispatch"
require_relative "hashira/smells/module_initialize"
require_relative "hashira/smells/nil_check"
require_relative "hashira/smells/param_check"
require_relative "hashira/smells/refs"
require_relative "hashira/smells/repeated_conditional"
require_relative "hashira/smells/report"
require_relative "hashira/smells/scope"
require_relative "hashira/smells/too_many_instance_variables"
require_relative "hashira/smells/utility_function"
require_relative "hashira/smells/visibility"
require_relative "hashira/version"
