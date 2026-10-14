# frozen_string_literal: true
# Builds the blind fragmentation-readability item set. Deterministic (seed 42).
require "prism"
require "json"

S = "/tmp/claude-0/-home-user/826c9fc5-a8b5-53c7-bdbc-e3d4f5d63b82/scratchpad"
OUT = "#{S}/verify/frag2"
SOURCES = {
  "kimera"      => { group: "H", roots: ["#{S}/kimera-work/base/lib"] },
  "hashira"     => { group: "H", roots: ["#{S}/hashira-work/base/lib"] },
  "rubocop"     => { group: "C", roots: ["/home/user/hashira/eval/tmp/corpus/rubocop/lib"] },
  "faraday"     => { group: "C", roots: ["/home/user/hashira/eval/tmp/corpus/faraday/lib"] },
  "rubygems.org"=> { group: "C", roots: ["/home/user/hashira/eval/tmp/corpus/rubygems.org/app",
                                          "/home/user/hashira/eval/tmp/corpus/rubygems.org/lib"] },
}
PER_SOURCE = { "kimera" => 15, "hashira" => 15, "rubocop" => 10, "faraday" => 10, "rubygems.org" => 10 }
CAP = 120
ROOTS = %w[Kimera Hashira RuboCop Faraday].freeze # top-level project namespaces: header would name the origin
IMPLICIT_PRIVATE = %i[initialize initialize_copy initialize_dup initialize_clone respond_to_missing? method_missing].freeze
SEND = %i[send public_send __send__ method].freeze

# A method definition record.
Meth = Struct.new(:source, :ns, :kind, :name, :file, :node, :outer, :visibility, :sclass, :header, keyword_init: true)

def const_name(node)
  case node
  when Prism::ConstantReadNode then node.name.to_s
  when Prism::ConstantPathNode then [node.parent && const_name(node.parent), node.name.to_s].compact.join("::")
  else "?"
  end
end

def last_seg(name) = name.split("::").last

class Collector
  attr_reader :meths

  def initialize(source, file, src, comments)
    @source, @file, @src, @comments = source, file, src, comments
    @meths = []
  end

  def walk(stmts, ns:, header:, kind:, sclass:)
    vis = :public
    modfn = false
    (stmts&.body || []).each do |st|
      case st
      when Prism::ClassNode, Prism::ModuleNode
        name = const_name(st.constant_path)
        full = name.start_with?("::") ? name[2..] : [ns, name].compact.join("::")
        hdr = "#{st.is_a?(Prism::ClassNode) ? "class" : "module"} #{last_seg(full)}"
        walk(st.body.is_a?(Prism::StatementsNode) ? st.body : nil, ns: full, header: hdr, kind: :instance, sclass: false)
      when Prism::SingletonClassNode
        if st.expression.is_a?(Prism::SelfNode) && ns
          walk(st.body.is_a?(Prism::StatementsNode) ? st.body : nil, ns: ns, header: header, kind: :singleton, sclass: true)
        end
      when Prism::DefNode
        add(st, st, ns, header, kind, sclass, modfn ? :public : vis)
      when Prism::CallNode
        next unless st.receiver.nil?
        args = st.arguments&.arguments || []
        case st.name
        when :private, :protected, :public
          if args.empty?
            vis = st.name
            modfn = false
          else
            args.each do |a|
              if a.is_a?(Prism::DefNode)
                add(a, st, ns, header, kind, sclass, st.name)
              elsif a.is_a?(Prism::SymbolNode)
                @meths.select { _1.ns == ns && _1.kind == kind && _1.name == a.unescaped.to_sym }.each { _1.visibility = st.name }
              end
            end
          end
        when :module_function
          if args.empty? then modfn = true
          else args.each { |a| add(a, st, ns, header, kind, sclass, :public) if a.is_a?(Prism::DefNode) }
          end
        when :def_node_matcher, :def_node_search
          if (a = args.first).is_a?(Prism::SymbolNode) && ns
            @meths << Meth.new(source: @source, ns: ns, kind: kind, name: a.unescaped.to_sym, file: @file, node: st,
                               outer: st, visibility: vis, sclass: sclass, header: header)
          end
        when :private_class_method
          args.each do |a|
            if a.is_a?(Prism::DefNode) then add(a, st, ns, header, :singleton, sclass, :private)
            elsif a.is_a?(Prism::SymbolNode)
              @meths.select { _1.ns == ns && _1.kind == :singleton && _1.name == a.unescaped.to_sym }.each { _1.visibility = :private }
            end
          end
        end
      end
    end
  end

  def add(defn, outer, ns, header, kind, sclass, vis)
    return unless ns
    k = defn.receiver.is_a?(Prism::SelfNode) ? :singleton : kind
    return if defn.receiver && !defn.receiver.is_a?(Prism::SelfNode)
    @meths << Meth.new(source: @source, ns: ns, kind: k, name: defn.name, file: @file, node: defn,
                       outer: outer, visibility: vis, sclass: sclass && !defn.receiver, header: header)
  end
end

# Self-calls inside a node, in source order: [[name, offset], ...]
def self_calls(node, acc = [])
  case node
  when Prism::CallNode
    if node.receiver.nil? || node.receiver.is_a?(Prism::SelfNode)
      acc << [node.name, node.location.start_offset]
      if SEND.include?(node.name) && (a = node.arguments&.arguments&.first).is_a?(Prism::SymbolNode)
        acc << [a.unescaped.to_sym, a.location.start_offset]
      end
    end
  end
  node.compact_child_nodes.each { |c| self_calls(c, acc) unless c.is_a?(Prism::DefNode) }
  acc
end

def calls_of(m)
  return [] unless m.node.is_a?(Prism::DefNode)
  acc = []
  m.node.compact_child_nodes.each { |c| self_calls(c, acc) unless c.is_a?(Prism::DefNode) }
  acc.sort_by(&:last).map(&:first)
end

meths = []
files_src = {}
SOURCES.each do |source, cfg|
  cfg[:roots].flat_map { Dir.glob("#{_1}/**/*.rb") }.sort.each do |file|
    src = File.read(file)
    res = Prism.parse(src)
    next unless res.success?
    files_src[file] = [src, res.comments]
    c = Collector.new(source, file, src, res.comments)
    c.walk(res.value.statements, ns: nil, header: nil, kind: :instance, sclass: false)
    meths.concat(c.meths)
  end
end

# Class table: (source, ns, kind) -> {name => Meth}; last definition wins.
table = Hash.new { |h, k| h[k] = {} }
meths.each { table[[_1.source, _1.ns, _1.kind]][_1.name] = _1 }

# Call-site counts per class (all methods of that class/kind, all files).
sites = Hash.new { |h, k| h[k] = Hash.new(0) }
callmap = {}
table.each do |key, by_name|
  by_name.each_value do |m|
    cs = calls_of(m).select { by_name.key?(_1) && _1 != m.name }
    callmap[m] = cs
    cs.each { sites[key][_1] += 1 }
  end
end

def reach(entry, table, callmap)
  by_name = table[[entry.source, entry.ns, entry.kind]]
  order = []
  depth = {}
  seen = { entry.name => true }
  dfs = lambda do |m|
    callmap[m].uniq.each do |n|
      next if seen[n]
      seen[n] = true
      order << by_name[n]
      dfs.call(by_name[n])
    end
  end
  dfs.call(entry)
  # BFS shortest hop distance
  frontier = [entry.name]
  dist = { entry.name => 0 }
  until frontier.empty?
    nxt = []
    frontier.each do |n|
      callmap[by_name[n]].uniq.each do |c|
        next if dist.key?(c)
        dist[c] = dist[n] + 1
        nxt << c
      end
    end
    frontier = nxt
  end
  [order, dist.values.max || 0]
end

# Last source line of a node, counting heredoc bodies that extend past it.
def last_line(node)
  best = node.location.end_line
  if node.respond_to?(:closing_loc) && node.closing_loc && node.respond_to?(:opening_loc) &&
     node.opening_loc&.slice&.start_with?("<<")
    best = [best, node.closing_loc.end_line - (node.closing_loc.slice.end_with?("\n") ? 1 : 0)].max
  end
  node.compact_child_nodes.each { best = [best, last_line(_1)].max }
  best
end

def stripped_lines(m, files_src)
  src, comments = files_src[m.file]
  node = m.outer
  start_line = node.location.start_line
  end_line = last_line(node)
  lines = src.lines
  line_starts = [0]
  lines.each { line_starts << line_starts.last + _1.bytesize }
  text = src.byteslice(line_starts[start_line - 1], line_starts[end_line] - line_starts[start_line - 1]).dup
  base = line_starts[start_line - 1]
  orig = text.lines
  cs = comments.select { _1.location.start_offset >= base && _1.location.end_offset <= base + text.bytesize }
  cs.sort_by { -_1.location.start_offset }.each do |c|
    s = c.location.start_offset - base
    text = text.byteslice(0, s) + text.byteslice(c.location.end_offset - base..)
  end
  out = text.lines.map(&:rstrip)
  # drop lines that were non-blank and became blank (comment-only lines)
  kept = []
  out.each_with_index { |l, i| kept << l unless l.strip.empty? && !orig[i].to_s.strip.empty? }
  kept = kept.each_with_object([]) { |l, a| a << l unless l.strip.empty? && a.last.to_s.strip.empty? }
  indent = kept.reject { _1.strip.empty? }.map { _1[/\A */].size }.min || 0
  first_col = node.location.start_column
  kept.map { _1.strip.empty? ? "" : _1[[indent, first_col].min..] }
end

def render(header, methods, files_src)
  out = [header]
  in_s = false
  methods.each_with_index do |m, i|
    if m.sclass && !in_s
      out << "" if i > 0
      out << "  class << self"
      in_s = true
    elsif !m.sclass && in_s
      out << "  end"
      in_s = false
    end
    out << "" if i > 0 && !(m.sclass && out.last == "  class << self")
    pad = in_s ? "    " : "  "
    stripped_lines(m, files_src).each { out << (_1.empty? ? "" : pad + _1) }
  end
  out << "  end" if in_s
  out << "end"
  out.join("\n") + "\n"
end

entries = []
table.each do |key, by_name|
  by_name.each_value do |m|
    next unless m.visibility == :public && m.node.is_a?(Prism::DefNode)
    next if IMPLICIT_PRIVATE.include?(m.name)
    next if ROOTS.include?(m.ns)
    order, depth = reach(m, table, callmap)
    next unless order.size >= 2 && depth >= 2
    entries << [m, order, depth]
  end
end
entries.sort_by! { |m, *| [m.source, m.file, m.node.location.start_offset] }
DEV = JSON.parse(File.read("#{S}/verify/frag/key.json")).values.map { _1["entry"] }
entries.reject! { |m, *| DEV.include?("#{m.ns}#{m.kind == :singleton ? "." : "#"}#{m.name}") }

rng = Random.new(1729)
items = []
stats = Hash.new { |h, k| h[k] = { eligible: 0, oversize_skipped: 0, same_class_skipped: 0 } }
entries.each { stats[_1[0].source][:eligible] += 1 }
PER_SOURCE.each do |source, n|
  pool = entries.select { _1[0].source == source }.shuffle(random: rng)
  taken = 0
  used = {}
  pool.each do |m, order, depth|
    break if taken == n
    if used[[m.ns, m.kind]]
      stats[source][:same_class_skipped] += 1
      next
    end
    code = render(m.header, [m] + order, files_src)
    if code.lines.size > CAP
      stats[source][:oversize_skipped] += 1
      next
    end
    key = [m.source, m.ns, m.kind]
    all = [m] + order
    lens = all.map { stripped_lines(_1, files_src).reject(&:empty?).size }
    single = order.count { sites[key][_1.name] == 1 }
    items << {
      group: SOURCES[source][:group], source: source, file: m.file,
      entry: "#{m.ns}#{m.kind == :singleton ? "." : "#"}#{m.name}",
      code: code,
      metrics: {
        helpers: order.size, max_depth: depth,
        mean_lines_per_method: (lens.sum.to_f / lens.size).round(2),
        single_use_share: (single.to_f / order.size).round(3),
        methods_shown: all.size, excerpt_lines: code.lines.size,
        helper_names: order.map { _1.name.to_s }
      }
    }
    used[[m.ns, m.kind]] = true
    taken += 1
  end
  stats[source][:sampled] = taken
  warn "WARNING: #{source} only #{taken}/#{n}" if taken < n
end

items.shuffle!(random: rng)
items.each_with_index { |it, i| it[:id] = format("Q%02d", i + 1) }

File.write("#{OUT}/items.json", JSON.pretty_generate(items.map { { id: _1[:id], code: _1[:code] } }))
File.write("#{OUT}/key.json", JSON.pretty_generate(items.to_h { [_1[:id], { group: _1[:group], source: _1[:source], source_file: _1[:file], entry: _1[:entry], metrics: _1[:metrics] }] }))

puts JSON.pretty_generate(stats)
%w[H C].each do |g|
  gi = items.select { _1[:group] == g }
  mean = ->(k) { (gi.sum { _1[:metrics][k] }.to_f / gi.size).round(2) }
  med = ->(k) { v = gi.map { _1[:metrics][k] }.sort; ((v[(v.size - 1) / 2] + v[v.size / 2]) / 2.0).round(2) }
  puts "#{g} n=#{gi.size} helpers=#{mean[:helpers]} (med #{med[:helpers]}) depth=#{mean[:max_depth]} (med #{med[:max_depth]}) " \
       "lines/method=#{mean[:mean_lines_per_method]} (med #{med[:mean_lines_per_method]}) single_use=#{mean[:single_use_share]} (med #{med[:single_use_share]}) " \
       "excerpt_lines=#{mean[:excerpt_lines]}"
end

# Population context (all eligible entries, not only sampled ones); does not affect outputs.
if ENV["POP"]
  %w[H C].each do |g|
    es = entries.select { SOURCES[_1[0].source][:group] == g }
    h = es.sum { _1[1].size }.to_f / es.size
    d = es.sum { _1[2] }.to_f / es.size
    lpm = es.sum { |m, o, _| l = ([m] + o).map { stripped_lines(_1, files_src).reject(&:empty?).size }; l.sum.to_f / l.size } / es.size
    su = es.sum { |m, o, _| o.count { sites[[m.source, m.ns, m.kind]][_1.name] == 1 }.to_f / o.size } / es.size
    puts "POP #{g} n=#{es.size} helpers=#{h.round(2)} depth=#{d.round(2)} lines/method=#{lpm.round(2)} single_use=#{su.round(3)}"
  end
end
SOURCES.each_key do |src|
  es = entries.select { _1[0].source == src }
  hit = es.count { |m, o, _| l = ([m] + o).map { stripped_lines(_1, files_src).reject(&:empty?).size }; o.size >= 4 && l.sum.to_f / l.size <= 3.5 }
  puts "RULE #{src} eligible=#{es.size} hits=#{hit} (#{(100.0 * hit / [es.size, 1].max).round(1)}%)"
end
