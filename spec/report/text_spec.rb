# frozen_string_literal: true

RSpec.describe Hashira::Report::Text do
  it "prints the full report verbatim" do
    with_pipeline do |project, graph, findings|
      output = capture_stdout { described_class.new(project, graph, findings).print }

      expect(output).to eq(<<~TEXT)
        Package (layer) metrics for lib/app  (3 packages, 3 files)

        package       TC  Ca  Ce     I  Cyc
        ----------------------------------------
        core           1   1   0  0.00  -#{"  "}
        beta           1   1   1  0.50  YES
        alpha          1   1   2  0.67  YES

        Legend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),
                I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)

        Dependencies (DependsUpon(refs) -> | <- UsedBy):
          alpha        -> beta(1), core(1)                 <- beta
          beta         -> alpha(2)                         <- alpha
          core         -> (none)                           <- alpha

        Findings (3):
          cycle: alpha can reach itself: alpha -> beta -> alpha — any change may ripple back around. The lightest edge on this cycle is alpha -> beta (1 ref).
              · alpha/one.rb:4: Beta::Two
              · beta/two.rb:4: Alpha::One
              · beta/two.rb:5: App::Alpha::One
          cycle: beta can reach itself: beta -> alpha -> beta — any change may ripple back around. The lightest edge on this cycle is alpha -> beta (1 ref).
              · beta/two.rb:4: Alpha::One
              · beta/two.rb:5: App::Alpha::One
              · alpha/one.rb:4: Beta::Two
          sdp_violation: beta (I=0.50) depends on the LESS stable alpha (I=0.67) — churn in alpha will force churn in beta. Invert the edge or extract the stable part of alpha that beta needs.
              · beta/two.rb:4: Alpha::One
              · beta/two.rb:5: App::Alpha::One

          Full evidence + machine format: hashira --json
      TEXT
    end
  end

  it "reports a healthy structure verbatim" do
    files = { "lib/app/solo/solo.rb" => "module App; class Solo; def a = 1; end; end\n" }
    within_project(files) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      screened = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      output = capture_stdout { described_class.new(pipeline.project, pipeline.graph, screened).print }
      expect(output).to eq(<<~TEXT)
        Package (layer) metrics for lib/app  (1 packages, 1 files)

        Only one package found — there are no boundaries to analyze. Pass subdirectories to set them (e.g. hashira lib/gem/*/).

        package       TC  Ca  Ce     I  Cyc
        ----------------------------------------
        solo           1   0   0  0.00  -#{"  "}

        Legend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),
                I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)

        Dependencies (DependsUpon(refs) -> | <- UsedBy):
          solo         -> (none)                           <- (none)

        Findings (0):
          none ✓ — structure is healthy
      TEXT
    end
  end

  it "truncates long evidence lists with an overflow marker" do
    files = (1..7).to_h do |n|
      succ = (n % 7) + 1
      ["lib/app/c#{n}/x.rb", "module App; module C#{n}; class X; def c = C#{succ}::X; end; end; end\n"]
    end
    within_project(files) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"]))
      screened = Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      output = capture_stdout { described_class.new(pipeline.project, pipeline.graph, screened).print }
      expect(output).to include("· … (3 more)")
    end
  end
end
