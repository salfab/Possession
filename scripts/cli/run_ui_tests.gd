extends SceneTree
# Headless UI regression test — the liturgy-banner tap path.
#
# Run:  godot --headless --path . --script res://scripts/cli/run_ui_tests.gd
# Exit: 0 if every invariant holds, 1 otherwise.
#
# WHY THIS EXISTS
# A banner-art refactor (commit 17a4ba6, "Bannières liturgiques : refond assets
# et rendu runtime") reworked how the six liturgy banners are drawn, and a tap
# on a banner was reported as no longer opening its liturgical card. The tap
# path is fragile and trivially broken by a change that looks purely visual, so
# this test pins the input invariants every banner must keep to stay tappable :
#
#   1. The banner panel is MOUSE_FILTER_STOP            (so it gets picked)
#   2. Its gui_input signal has a handler connected     (so the tap is handled)
#   3. Every descendant Control is MOUSE_FILTER_IGNORE  (no child eats the tap)
#   4. No STOP control is drawn on top at the panel centre (nothing steals it)
#
# Timing : Main._ready() does NOT run synchronously on add_child, and the demon
# side-panels lay themselves out from the viewport size via a size_changed
# handler. So we add the scene, force a known landscape viewport, drive a
# re-layout, and let several frames settle BEFORE asserting anything.
#
# Invariant 4 only counts STOP controls : MOUSE_FILTER_PASS receives the event
# but lets it fall through to the control behind, so a PASS overlay does not
# block the banner — only a STOP one does.
#
# NOTE : this guards the in-tree input WIRING + on-screen layout. It cannot
# catch a regression that only manifests under the Web export / iPad Safari
# runtime — a headless desktop run exercises the same GDScript, not that env.
#
# Mirrors run_tests.gd conventions (SceneTree driver, PASS/FAIL lines, a
# "=== a/b PASS, c FAIL ===" summary the CI greps) so the same tooling applies.

const VIEWPORT := Vector2i(1280, 800)   # landscape, matches the project default

var _pass := 0
var _fail := 0
var _skip := 0
var _lines: Array = []


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	if scene == null:
		_fail_line("load Main.tscn", "PackedScene failed to load")
		_finish()
		return
	# Untyped on purpose : we read Main's script var `_liturgy_banners` and call
	# its layout helper, which a statically-typed Node base would reject.
	var main = scene.instantiate()
	if main == null:
		_fail_line("instantiate Main.tscn", "instantiate() returned null")
		_finish()
		return
	root.add_child(main)

	# _ready runs on the next idle frames, not synchronously — let it build the
	# overlays + load the board texture.
	for _i in 6:
		await process_frame
	# Force a known landscape viewport, then re-run the demon-panel layout so the
	# panels land where they would on a real landscape screen (left sidebar) and
	# the board occupies the right — otherwise they keep a degenerate first-layout
	# rect and the coverage check measures nonsense.
	root.size = VIEWPORT
	for _i in 4:
		await process_frame
	if main.has_method("_layout_player_transgression_panels"):
		main._layout_player_transgression_panels()
	for _i in 4:
		await process_frame

	var banners: Dictionary = main._liturgy_banners
	_dump_geometry(main, banners)
	_check_structure(banners)
	_check_coverage(main, banners)
	# Card-action button : in a separate load()'d class so its autoload
	# references (GameEnums / TransgressionData) resolve — they don't in this
	# --script body.
	var card_res: Dictionary = load("res://scripts/cli/card_action_check.gd").new().check(main)
	for l in card_res.get("lines", []):
		_lines.append(String(l))
	_pass += int(card_res.get("pass", 0))
	_fail += int(card_res.get("fail", 0))

	# New-game options (Codex / Missel toggles) → fresh GameState. Runs last : it
	# calls new_game() which resets state, so it must not precede other checks.
	var ng_res: Dictionary = load("res://scripts/cli/new_game_options_check.gd").new().check(main)
	for l in ng_res.get("lines", []):
		_lines.append(String(l))
	_pass += int(ng_res.get("pass", 0))
	_fail += int(ng_res.get("fail", 0))

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


# ─── Diagnostics ──────────────────────────────────────────────────────────────

func _dump_geometry(main: Node, banners: Dictionary) -> void:
	_lines.append("GEOM  viewport=%s  banners=%d" % [str(root.size), banners.size()])
	for st in banners.keys():
		var panel = banners[st]
		if panel is Control and is_instance_valid(panel):
			_lines.append("GEOM  station %d rect=%s mf=%d"
				% [int(st), str((panel as Control).get_global_rect()), (panel as Control).mouse_filter])


# ─── Invariants 1–3 : per-banner input wiring ─────────────────────────────────

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


# ─── Invariant 4 : no STOP control covers the panel centre ────────────────────

func _check_coverage(main: Node, banners: Dictionary) -> void:
	# Draw order ≈ pre-order tree position (single CanvasLayer, no z_index here),
	# so a Control later in the walk paints on top. A tap resolves to the topmost
	# STOP control under the point ; that must be the banner panel itself. PASS
	# controls are transparent to blocking (they fall through), so we ignore them.
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
		var top := _topmost_stop_at(main, rect.get_center(), order)
		_assert(top == p,
			"%s : panel is the topmost tap target at its centre" % label,
			"" if top == p else "covered by STOP control %s (rect=%s)"
				% [String(top.get_path()) if top != null else "<none>",
				   str(top.get_global_rect()) if top != null else "?"])


func _index_draw_order(node: Node, order: Dictionary, seq: Array) -> void:
	order[node] = seq[0]
	seq[0] += 1
	for c in node.get_children():
		# Popups / dialogs are Windows — they render in their own viewport, not
		# in the board's pick stack, so they can't cover a banner. Skip them.
		if c is Window:
			continue
		_index_draw_order(c, order, seq)


# Topmost (latest-painted) STOP Control whose global rect contains `point`. With
# all banner children IGNORE, this resolves to the banner panel itself unless a
# STOP control is layered on top of it — exactly what would steal the tap.
func _topmost_stop_at(main: Node, point: Vector2, order: Dictionary) -> Control:
	var top: Control = null
	var top_order: int = -1
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
		if not ctl.is_visible_in_tree():
			continue
		if ctl.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue  # PASS falls through, IGNORE is invisible to picking
		if not ctl.get_global_rect().has_point(point):
			continue
		var o: int = int(order.get(ctl, -1))
		if o > top_order:
			top_order = o
			top = ctl
	return top
