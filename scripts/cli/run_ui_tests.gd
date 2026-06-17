extends SceneTree
# Headless UI regression test — the liturgy-banner tap path.
#
# Run:  godot --headless --path . --script res://scripts/cli/run_ui_tests.gd
# Exit: 0 if every invariant holds, 1 otherwise.
#
# WHY THIS EXISTS
# A banner-art refactor (commit 17a4ba6, "Bannières liturgiques : refond assets
# et rendu runtime") reworked how the six liturgy banners are drawn, and soon
# after a tap on a banner stopped opening its liturgical card. The tap path is
# fragile and trivially broken by a change that looks purely visual, so this
# test pins the input invariants every banner must keep to stay tappable :
#
#   1. The banner panel is MOUSE_FILTER_STOP            (so it gets picked)
#   2. Its gui_input signal has a handler connected     (so the tap is handled)
#   3. Every descendant Control is MOUSE_FILTER_IGNORE  (no child eats the tap)
#   4. Nothing is drawn on top at the panel's centre    (no covering overlay)
#
# 1–3 are wired synchronously while the scene builds (in _build_liturgy_banners,
# run from Main._ready), so they are asserted right after instancing — no layout
# pass needed, which keeps them deterministic in CI. 4 needs real on-screen
# rects, so it runs after a few frames ; if layout hasn't settled (e.g. a
# zero-size headless viewport) it is reported SKIP rather than failing the build
# for a harness reason.
#
# NOTE : this guards the in-tree input WIRING. It cannot catch a regression that
# only manifests under the Web export / iPad Safari runtime — a headless desktop
# run exercises the same GDScript but not that environment.
#
# Mirrors the run_tests.gd conventions (SceneTree driver, PASS/FAIL lines, a
# "=== a/b PASS, c FAIL ===" summary the CI greps) so the same tooling applies.

var _pass := 0
var _fail := 0
var _skip := 0
var _lines: Array = []


func _initialize() -> void:
	# A concrete viewport size so the AspectRatioContainer lays the board out and
	# the banner panels resolve to non-zero rects for the coverage check.
	root.size = Vector2i(1280, 800)

	var scene: PackedScene = load("res://scenes/Main.tscn")
	if scene == null:
		_fail_line("load Main.tscn", "PackedScene failed to load")
		_finish()
		return
	# Untyped on purpose : we read Main's script var `_liturgy_banners`, which a
	# statically-typed Node base would reject at parse time.
	var main = scene.instantiate()
	if main == null:
		_fail_line("instantiate Main.tscn", "instantiate() returned null")
		_finish()
		return
	# Adding to the already-active root runs Main._ready synchronously, which
	# builds the banner panels — so the structural invariants are readable now.
	root.add_child(main)

	var banners: Dictionary = main._liturgy_banners
	_check_structure(banners)

	# Coverage needs laid-out rects ; let the container sort + anchor pass settle.
	for _i in 8:
		await process_frame
	_check_coverage(main, banners)

	_finish()


func _finish() -> void:
	for l in _lines:
		print(String(l))
	var total := _pass + _fail
	if _skip > 0:
		print("--- UI (banner input) : %d/%d PASS, %d SKIP ---" % [_pass, total, _skip])
	else:
		print("--- UI (banner input) : %d/%d PASS ---" % [_pass, total])
	print("=== %d/%d PASS, %d FAIL ===" % [_pass, total, _fail])
	quit(0 if _fail == 0 else 1)


func _ok(name: String) -> void:
	_pass += 1
	_lines.append("PASS  %s" % name)

func _fail_line(name: String, msg: String = "") -> void:
	_fail += 1
	_lines.append("FAIL  %s%s" % [name, "" if msg.is_empty() else " — " + msg])

func _assert(cond: bool, name: String, msg: String = "") -> void:
	if cond:
		_ok(name)
	else:
		_fail_line(name, msg)


# ─── Invariants 1–3 : per-banner input wiring (no layout needed) ──────────────

func _check_structure(banners: Dictionary) -> void:
	_assert(banners.size() == 6, "six liturgy banners built", "got %d" % banners.size())
	for st in banners.keys():
		var label := "station %d" % int(st)
		var panel = banners[st]
		if not (panel is Control) or not is_instance_valid(panel):
			_fail_line("%s : panel is a valid Control" % label, "got %s" % str(panel))
			continue
		var p: Control = panel
		_assert(p.mouse_filter == Control.MOUSE_FILTER_STOP,
			"%s : panel mouse_filter STOP" % label,
			"mouse_filter=%d (expected STOP=%d)" % [p.mouse_filter, Control.MOUSE_FILTER_STOP])
		_assert(p.gui_input.get_connections().size() >= 1,
			"%s : panel gui_input connected" % label,
			"no gui_input handler wired — taps reach nothing")
		var offenders := _non_ignore_descendants(p)
		_assert(offenders.is_empty(),
			"%s : every child is MOUSE_FILTER_IGNORE" % label,
			"non-IGNORE descendants would swallow the tap before the panel: %s" % str(offenders))


# Descendant Controls whose mouse_filter isn't IGNORE — any of them, drawn over
# the panel, intercepts the press before the panel's gui_input ever sees it.
func _non_ignore_descendants(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Control and (c as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			out.append(String(c.name))
		out.append_array(_non_ignore_descendants(c))
	return out


# ─── Invariant 4 : nothing covers the panel at its centre ─────────────────────

func _check_coverage(main: Node, banners: Dictionary) -> void:
	# Draw order ≈ pre-order tree position (single CanvasLayer, no z_index here),
	# so a Control later in the walk paints on top. The topmost non-IGNORE control
	# containing a banner's centre must be the banner panel itself ; anything
	# drawn above it would be picked first and steal the tap.
	var order: Dictionary = {}
	var seq: Array = [0]
	_index_draw_order(main, order, seq)

	for st in banners.keys():
		var label := "station %d" % int(st)
		var panel = banners[st]
		if not (panel is Control) or not is_instance_valid(panel):
			continue
		var p: Control = panel
		var rect: Rect2 = p.get_global_rect()
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			_skip += 1
			_lines.append("SKIP  %s : not-covered (panel rect not laid out yet: %s)"
				% [label, str(rect.size)])
			continue
		var coverer := _topmost_blocker_over(main, rect.get_center(), p, order)
		_assert(coverer == null,
			"%s : panel not covered at centre" % label,
			"" if coverer == null else "covered by %s (mouse_filter=%d)"
				% [String(coverer.get_path()), coverer.mouse_filter])


func _index_draw_order(node: Node, order: Dictionary, seq: Array) -> void:
	order[node] = seq[0]
	seq[0] += 1
	for c in node.get_children():
		# Popups / dialogs are Windows — they render in their own viewport, not
		# in the board's pick stack, so they can't cover a banner. Skip them
		# (a resume dialog may be open during a local run with a save file).
		if c is Window:
			continue
		_index_draw_order(c, order, seq)


# Topmost Control that would intercept a press at `point` instead of `panel` :
# visible, non-IGNORE, contains the point, painted after the panel, and neither
# the panel nor one of its descendants. Returns null when nothing covers it.
func _topmost_blocker_over(main: Node, point: Vector2, panel: Control, order: Dictionary) -> Control:
	var worst: Control = null
	var worst_order: int = int(order.get(panel, -1))
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if c is Window:
				continue  # subwindow — separate viewport, never covers the board
			stack.push_back(c)
		if not (n is Control):
			continue
		var ctl: Control = n
		if ctl == panel or _is_descendant_of(ctl, panel):
			continue
		if not ctl.is_visible_in_tree():
			continue
		if ctl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if not ctl.get_global_rect().has_point(point):
			continue
		var o: int = int(order.get(ctl, -1))
		if o > worst_order:
			worst_order = o
			worst = ctl
	return worst


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var p: Node = node.get_parent()
	while p != null:
		if p == ancestor:
			return true
		p = p.get_parent()
	return false
