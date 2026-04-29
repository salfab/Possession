extends Control

const SAVE_PATH := "user://save_game.json"

# Gothic palette
const C_BG        := Color(0.039, 0.051, 0.102)
const C_PANEL     := Color(0.082, 0.098, 0.157)
const C_PANEL2    := Color(0.118, 0.141, 0.196)
const C_BORDER    := Color(0.165, 0.196, 0.314)
const C_TEXT      := Color(0.925, 0.894, 0.824)
const C_MUTED     := Color(0.600, 0.569, 0.510)
const C_RED       := Color(0.784, 0.196, 0.298)
const C_BLUE      := Color(0.235, 0.420, 0.784)
const C_GOLD      := Color(0.831, 0.655, 0.239)
const C_GREEN     := Color(0.255, 0.627, 0.353)
const C_SEALED    := Color(0.941, 0.753, 0.251)
const C_PENITENCE := Color(0.376, 0.565, 0.753)

var state: GameState
var manager: TurnManager
var pending_action: int = -1

var _status_label: Label
var _station_label: Label
var _ascendant_label: Label
var _ascendant_red: ColorRect
var _ascendant_blue: ColorRect
var _res_labels: Dictionary = {}
var _prompt_label: Label
var _prompt_box: VBoxContainer
var _actions_flow: HFlowContainer
var _domains_grid: GridContainer
var _log_rtl: RichTextLabel
var _debug_rtl: RichTextLabel
var _transg_box: VBoxContainer
var _tab_contents: Array[Control] = []
var _active_tab: int = 0

func _ready() -> void:
    _build_ui()
    new_game()

func new_game() -> void:
    state = GameState.new()
    manager = TurnManager.new(state)
    pending_action = -1
    _rebuild_all()

# ─── UI CONSTRUCTION ──────────────────────────────────────────────────────────

func _make_panel_style(bg: Color, border: Color = C_BORDER, radius: int = 6) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    s.set_content_margin_all(8)
    return s

func _make_button(text: String, color: Color = C_TEXT) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_color_override("font_color", color)
    var normal := StyleBoxFlat.new()
    normal.bg_color = C_PANEL2
    normal.border_color = C_BORDER
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(4)
    normal.set_content_margin_all(8)
    b.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate()
    hover.bg_color = C_BORDER
    b.add_theme_stylebox_override("hover", hover)
    var pressed_style := normal.duplicate()
    pressed_style.bg_color = Color(C_GOLD, 0.25)
    b.add_theme_stylebox_override("pressed", pressed_style)
    b.custom_minimum_size.y = 44
    return b

func _build_ui() -> void:
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)

    var root := VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_theme_constant_override("separation", 6)
    scroll.add_child(root)

    _build_header(root)
    _build_ascendant(root)
    _build_resources(root)
    _build_prompt_panel(root)
    _build_actions(root)
    _build_domains(root)
    _build_tabs(root)
    _build_debug_buttons(root)

func _build_header(parent: VBoxContainer) -> void:
    var hdr := PanelContainer.new()
    hdr.add_theme_stylebox_override("panel", _make_panel_style(C_PANEL, C_GOLD))
    parent.add_child(hdr)
    var col := VBoxContainer.new()
    hdr.add_child(col)
    var title := Label.new()
    title.text = "✦ POSSESSION — FIAT TENEBRIS ✦"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", C_GOLD)
    col.add_child(title)
    _station_label = Label.new()
    _station_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _station_label.add_theme_color_override("font_color", C_MUTED)
    col.add_child(_station_label)
    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.add_theme_color_override("font_color", C_TEXT)
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(_status_label)

func _build_ascendant(parent: VBoxContainer) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _make_panel_style(C_PANEL))
    parent.add_child(panel)
    var col := VBoxContainer.new()
    panel.add_child(col)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    col.add_child(row)
    var rl := Label.new()
    rl.text = "ROUGE"
    rl.add_theme_color_override("font_color", C_RED)
    row.add_child(rl)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(spacer)
    _ascendant_label = Label.new()
    _ascendant_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _ascendant_label.add_theme_color_override("font_color", C_GOLD)
    row.add_child(_ascendant_label)
    var spacer2 := Control.new()
    spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(spacer2)
    var bl := Label.new()
    bl.text = "BLEU"
    bl.add_theme_color_override("font_color", C_BLUE)
    row.add_child(bl)
    var bar := HBoxContainer.new()
    bar.custom_minimum_size = Vector2(0, 12)
    bar.add_theme_constant_override("separation", 0)
    col.add_child(bar)
    _ascendant_red = ColorRect.new()
    _ascendant_red.color = C_RED
    _ascendant_red.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.add_child(_ascendant_red)
    _ascendant_blue = ColorRect.new()
    _ascendant_blue.color = C_BLUE
    _ascendant_blue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.add_child(_ascendant_blue)

func _build_resources(parent: VBoxContainer) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    parent.add_child(row)
    for player in [GameEnums.PlayerId.RED, GameEnums.PlayerId.BLUE]:
        var panel := PanelContainer.new()
        var color := C_RED if player == GameEnums.PlayerId.RED else C_BLUE
        panel.add_theme_stylebox_override("panel", _make_panel_style(C_PANEL, color))
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(panel)
        var lbl := Label.new()
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.add_theme_color_override("font_color", C_TEXT)
        panel.add_child(lbl)
        _res_labels[player] = lbl

func _build_prompt_panel(parent: VBoxContainer) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _make_panel_style(C_PANEL2, C_GOLD))
    parent.add_child(panel)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 6)
    panel.add_child(col)
    _prompt_label = Label.new()
    _prompt_label.add_theme_color_override("font_color", C_GOLD)
    _prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(_prompt_label)
    _prompt_box = VBoxContainer.new()
    _prompt_box.add_theme_constant_override("separation", 4)
    col.add_child(_prompt_box)

func _build_actions(parent: VBoxContainer) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _make_panel_style(C_PANEL))
    parent.add_child(panel)
    _actions_flow = HFlowContainer.new()
    _actions_flow.add_theme_constant_override("h_separation", 6)
    _actions_flow.add_theme_constant_override("v_separation", 6)
    panel.add_child(_actions_flow)

func _build_domains(parent: VBoxContainer) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _make_panel_style(C_PANEL))
    parent.add_child(panel)
    _domains_grid = GridContainer.new()
    _domains_grid.columns = _domain_columns()
    _domains_grid.add_theme_constant_override("h_separation", 6)
    _domains_grid.add_theme_constant_override("v_separation", 6)
    panel.add_child(_domains_grid)

func _domain_columns() -> int:
    var w := get_viewport().get_visible_rect().size.x
    if w < 600: return 1
    if w < 900: return 2
    return 3

func _build_tabs(parent: VBoxContainer) -> void:
    var tab_bar := HBoxContainer.new()
    tab_bar.add_theme_constant_override("separation", 4)
    parent.add_child(tab_bar)

    var tab_panel := PanelContainer.new()
    tab_panel.add_theme_stylebox_override("panel", _make_panel_style(C_PANEL))
    tab_panel.custom_minimum_size = Vector2(0, 200)
    parent.add_child(tab_panel)

    _tab_contents = []

    # Tab 0: Log
    var log_scroll := ScrollContainer.new()
    log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _log_rtl = RichTextLabel.new()
    _log_rtl.bbcode_enabled = true
    _log_rtl.fit_content = true
    _log_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _log_rtl.add_theme_color_override("default_color", C_TEXT)
    log_scroll.add_child(_log_rtl)
    tab_panel.add_child(log_scroll)
    _tab_contents.append(log_scroll)

    # Tab 1: Transgressions
    var transg_scroll := ScrollContainer.new()
    transg_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    transg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    transg_scroll.visible = false
    _transg_box = VBoxContainer.new()
    _transg_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    transg_scroll.add_child(_transg_box)
    tab_panel.add_child(transg_scroll)
    _tab_contents.append(transg_scroll)

    # Tab 2: Debug
    var debug_scroll := ScrollContainer.new()
    debug_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    debug_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    debug_scroll.visible = false
    _debug_rtl = RichTextLabel.new()
    _debug_rtl.bbcode_enabled = true
    _debug_rtl.fit_content = true
    _debug_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _debug_rtl.add_theme_color_override("default_color", C_TEXT)
    debug_scroll.add_child(_debug_rtl)
    tab_panel.add_child(debug_scroll)
    _tab_contents.append(debug_scroll)

    var tab_names := ["Journal", "Transgressions", "Règles"]
    for i in tab_names.size():
        var btn := _make_button(tab_names[i])
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var idx := i
        btn.pressed.connect(func(): _switch_tab(idx))
        tab_bar.add_child(btn)

func _switch_tab(idx: int) -> void:
    for i in _tab_contents.size():
        _tab_contents[i].visible = (i == idx)
    _active_tab = idx

func _build_debug_buttons(parent: VBoxContainer) -> void:
    var col := VBoxContainer.new()
    parent.add_child(col)
    var lbl := Label.new()
    lbl.text = "— DEBUG —"
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.add_theme_color_override("font_color", C_MUTED)
    col.add_child(lbl)
    var row := HFlowContainer.new()
    row.add_theme_constant_override("h_separation", 6)
    row.add_theme_constant_override("v_separation", 6)
    col.add_child(row)
    var actions := [
        ["Nouvelle partie", _on_btn_new_game],
        ["Station →", _on_btn_force_next_station],
        ["Exorcisme →", _on_btn_force_exorcism],
        ["+1 Corruption", _on_btn_add_corruption],
        ["Tests", _on_btn_run_tests],
        ["Sauvegarder", _on_btn_save],
        ["Charger", _on_btn_load],
    ]
    for a in actions:
        var btn := _make_button(a[0], C_MUTED)
        btn.custom_minimum_size = Vector2(120, 36)
        btn.pressed.connect(a[1])
        row.add_child(btn)

# ─── RENDERING ────────────────────────────────────────────────────────────────

func _rebuild_all() -> void:
    _render_header()
    _render_ascendant()
    _render_resources()
    _render_actions()
    _render_prompt()
    _render_domains()
    _render_log()
    _render_debug()
    _render_transgressions()

func _render_header() -> void:
    if state.game_over:
        _station_label.text = "PARTIE TERMINÉE"
        _status_label.text = "Vainqueur : %s — %s" % [GameEnums.player_name(state.winner), state.winner_reason]
        return
    var st := GameEnums.STATION_NAMES[state.current_station]
    var pulses := GameEnums.STATION_PULSES[state.current_station]
    var init_p := GameEnums.STATION_INITIATIVE[state.current_station]
    _station_label.text = "Station %s — Pulsation %d/%d" % [st, state.current_pulse, pulses]
    _status_label.text = "Joueur actif : %s   Initiative : %s" % [
        GameEnums.player_name(state.active_player),
        GameEnums.player_name(init_p),
    ]

func _render_ascendant() -> void:
    var asc: int = state.ascendant
    var clamped := clamp(asc, -10, 10)
    var ratio := (clamped + 10.0) / 20.0
    _ascendant_label.text = "Ascendant : %+d" % asc
    _ascendant_red.size_flags_stretch_ratio = ratio
    _ascendant_blue.size_flags_stretch_ratio = 1.0 - ratio

func _render_resources() -> void:
    for player in [GameEnums.PlayerId.RED, GameEnums.PlayerId.BLUE]:
        var name_str := "Rouge" if player == GameEnums.PlayerId.RED else "Bleu"
        var corr := state.available_corruption[player]
        _res_labels[player].text = "%s\n%d Corruptions" % [name_str, corr]

func _render_actions() -> void:
    for c in _actions_flow.get_children():
        c.queue_free()
    if state.game_over:
        return
    if state.has_pending_decisions():
        return
    var p := state.active_player
    var actions := [
        [GameEnums.ActionId.INVESTIR, "Investir"],
        [GameEnums.ActionId.EXPLOITER, "Exploiter"],
        [GameEnums.ActionId.PROVOQUER, "Provoquer"],
        [GameEnums.ActionId.AMPLIFIER, "Amplifier"],
        [GameEnums.ActionId.SCELLER, "Sceller"],
        [GameEnums.ActionId.FISSURER, "Fissurer"],
        [GameEnums.ActionId.ENTRAVER, "Entraver"],
        [GameEnums.ActionId.PASSER, "Passer"],
    ]
    for a in actions:
        var btn := _make_button(a[1])
        btn.disabled = not _is_action_potentially_legal(a[0], p)
        var aid: int = a[0]
        btn.pressed.connect(func(): _on_action_chosen(aid))
        _actions_flow.add_child(btn)

func _render_prompt() -> void:
    for c in _prompt_box.get_children():
        c.queue_free()
    if state.has_pending_decisions():
        _render_decision_prompt()
        return
    if pending_action < 0:
        _prompt_label.text = "Choisissez une action ci-dessus."
        return
    var p := state.active_player
    match pending_action:
        GameEnums.ActionId.INVESTIR:
            _prompt_label.text = "Investir — choisissez un Domaine :"
            for d_id in DomainData.DOMAINS:
                if GameRules.can_investir(state, p, d_id):
                    _add_choice(GameEnums.DOMAIN_NAMES[d_id], func(): _commit_action({"domain": d_id}))
        GameEnums.ActionId.EXPLOITER:
            _prompt_label.text = "Exploiter — choisissez un Domaine contrôlé :"
            for d_id in DomainData.DOMAINS:
                if GameRules.can_exploiter(state, p, d_id):
                    var prod := GameRules.production_of(state, d_id, p)
                    _add_choice("%s (+%d)" % [GameEnums.DOMAIN_NAMES[d_id], prod], func(): _commit_action({"domain": d_id}))
        GameEnums.ActionId.SCELLER:
            _prompt_label.text = "Sceller — choisissez un Domaine :"
            for d_id in DomainData.DOMAINS:
                if GameRules.can_sceller(state, p, d_id):
                    _add_choice(GameEnums.DOMAIN_NAMES[d_id], func(): _commit_action({"domain": d_id}))
        GameEnums.ActionId.FISSURER:
            _prompt_label.text = "Fissurer — choisissez un Domaine scellé adverse :"
            for d_id in DomainData.DOMAINS:
                if GameRules.can_fissurer(state, p, d_id):
                    var cost := GameRules.fissurer_total_cost(state, p, d_id)
                    _add_choice("%s (coût %d)" % [GameEnums.DOMAIN_NAMES[d_id], cost], func(): _commit_action({"domain": d_id}))
        GameEnums.ActionId.PROVOQUER:
            _prompt_label.text = "Provoquer — choisissez une Transgression :"
            for tid in TransgressionData.ALL_IDS:
                if GameRules.can_provoquer(state, p, tid):
                    var cost := GameRules.transgression_scandal_cost(state, p, tid)
                    _add_choice("%s (coût %d)" % [TransgressionData.name_of(tid), cost], func(): _commit_action({"def_id": tid}))
        GameEnums.ActionId.AMPLIFIER:
            _prompt_label.text = "Amplifier — choisissez une Transgression :"
            for tid in TransgressionData.ALL_IDS:
                if GameRules.can_amplifier(state, p, tid):
                    var def: Dictionary = TransgressionData.get_def(tid)
                    _add_choice("%s (coût %d)" % [def["name"], int(def["amplification_cost"])], func(): _commit_action({"def_id": tid}))
        GameEnums.ActionId.ENTRAVER:
            _prompt_label.text = "Entraver — choisissez la Réponse à bloquer :"
            for st_id in [state.current_station, state.current_station + 1, state.current_station + 2]:
                if GameRules.can_entraver(state, p, st_id):
                    var cost := GameRules.entrave_cost(state, p, st_id)
                    _add_choice("%s (coût %d)" % [GameEnums.STATION_NAMES[st_id], cost], func(): _commit_action({"station": st_id}))
    _add_choice("✕ Annuler", _cancel_pending, C_MUTED)

func _add_choice(text: String, cb: Callable, color: Color = C_TEXT) -> void:
    var b := _make_button(text, color)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.pressed.connect(cb)
    _prompt_box.add_child(b)

func _render_decision_prompt() -> void:
    var dec = state.pending_decisions[0]
    if dec.kind == "free_exploit":
        var opts: Array = dec.data.get("options", [])
        _prompt_label.text = "Exploitation gratuite — %s :" % GameEnums.player_name(dec.player)
        for d_id in opts:
            var prod := GameRules.production_of(state, d_id, dec.player)
            var did: int = d_id
            _add_choice("%s (+%d)" % [GameEnums.DOMAIN_NAMES[d_id], prod], func(): _resolve_decision({"domain": did}))
        _add_choice("Passer", func(): _resolve_decision({"skip": true}), C_MUTED)
    elif dec.kind == "confession":
        var impedita: bool = dec.data.get("impedita", false)
        var done_str := ", ".join(dec.picks_done) if dec.picks_done.size() > 0 else "—"
        _prompt_label.text = "Confession (%s) — %s : %d pénitence(s) — Choisies : %s" % [
            "Impedita" if impedita else "In Integro",
            GameEnums.player_name(dec.player),
            dec.picks_remaining,
            done_str,
        ]
        var avail := LiturgyResolver.available_confession_kinds(state, dec)
        if "lose2" in avail:
            _add_choice("Perdre 2 Corruptions", func(): _resolve_decision({"kind": "lose2"}))
        if "penitence" in avail:
            for d_id in DomainData.DOMAINS:
                if state.controller_of(d_id) == dec.player and not state.is_in_penitence(d_id):
                    var did: int = d_id
                    _add_choice("Pénitence : %s" % GameEnums.DOMAIN_NAMES[d_id], func(): _resolve_decision({"kind": "penitence", "domain": did}))
        if "fissure" in avail:
            for d_id in DomainData.DOMAINS:
                if state.controller_of(d_id) == dec.player and state.is_sealed(d_id) and state.domain(d_id).seal_owner == dec.player:
                    var did: int = d_id
                    _add_choice("Fissurer : %s" % GameEnums.DOMAIN_NAMES[d_id], func(): _resolve_decision({"kind": "fissure", "domain": did}))
        if avail.is_empty():
            _add_choice("(Aucune pénitence applicable — passer)", _force_pop_decision, C_MUTED)

func _render_domains() -> void:
    _domains_grid.columns = _domain_columns()
    for c in _domains_grid.get_children():
        c.queue_free()
    for d_id in DomainData.DOMAINS:
        _domains_grid.add_child(_make_domain_panel(d_id))

func _make_domain_panel(d_id: int) -> Control:
    var d := state.domain(d_id)
    var ctrl := state.controller_of(d_id)
    var border_color := C_BORDER
    if ctrl == GameEnums.PlayerId.RED:
        border_color = C_RED
    elif ctrl == GameEnums.PlayerId.BLUE:
        border_color = C_BLUE
    if state.is_sealed(d_id):
        border_color = C_SEALED
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _make_panel_style(C_PANEL2, border_color, 8))
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 4)
    panel.add_child(col)

    var title_row := HBoxContainer.new()
    col.add_child(title_row)
    var name_lbl := Label.new()
    name_lbl.text = GameEnums.DOMAIN_NAMES[d_id]
    name_lbl.add_theme_color_override("font_color", C_GOLD)
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(name_lbl)
    var prod_lbl := Label.new()
    prod_lbl.text = DomainData.production_label(d_id)
    prod_lbl.add_theme_color_override("font_color", C_MUTED)
    title_row.add_child(prod_lbl)

    var status_row := HBoxContainer.new()
    status_row.add_theme_constant_override("separation", 6)
    col.add_child(status_row)

    var red_lbl := Label.new()
    red_lbl.text = "R:%d" % d.red_corruption
    red_lbl.add_theme_color_override("font_color", C_RED)
    status_row.add_child(red_lbl)
    var blue_lbl := Label.new()
    blue_lbl.text = "B:%d" % d.blue_corruption
    blue_lbl.add_theme_color_override("font_color", C_BLUE)
    status_row.add_child(blue_lbl)

    if ctrl != GameEnums.PlayerId.NONE:
        var ctrl_lbl := Label.new()
        var net := " ★" if state.has_net_domination(d_id, ctrl) else ""
        ctrl_lbl.text = GameEnums.player_name(ctrl) + net
        ctrl_lbl.add_theme_color_override("font_color", C_RED if ctrl == GameEnums.PlayerId.RED else C_BLUE)
        status_row.add_child(ctrl_lbl)

    if state.is_sealed(d_id):
        var seal_lbl := Label.new()
        seal_lbl.text = "⚔ Sceau %s" % GameEnums.player_name(d.seal_owner)
        seal_lbl.add_theme_color_override("font_color", C_SEALED)
        col.add_child(seal_lbl)
    if state.is_in_penitence(d_id):
        var pen_lbl := Label.new()
        pen_lbl.text = "✝ Pénitence"
        pen_lbl.add_theme_color_override("font_color", C_PENITENCE)
        col.add_child(pen_lbl)

    for ti in d.scandals:
        var sc := Label.new()
        var owner_color := C_RED if ti.owner == GameEnums.PlayerId.RED else C_BLUE
        sc.text = "◆ %s" % TransgressionData.name_of(ti.def_id)
        sc.add_theme_color_override("font_color", owner_color.lerp(C_TEXT, 0.3))
        col.add_child(sc)
    for ti in d.infamies:
        var inf := Label.new()
        var owner_color := C_RED if ti.owner == GameEnums.PlayerId.RED else C_BLUE
        inf.text = "✦ INFAMIE: %s" % TransgressionData.name_of(ti.def_id)
        inf.add_theme_color_override("font_color", owner_color)
        col.add_child(inf)

    return panel

func _render_log() -> void:
    var lines := state.log
    var max_lines := 50
    var start := max(0, lines.size() - max_lines)
    var s := ""
    for i in range(start, lines.size()):
        var line: String = String(lines[i])
        if line.begins_with("[ACTION"):
            s += "[color=#d4a73d]" + line.xml_escape() + "[/color]\n"
        elif line.begins_with("[DÉCISION") or line.begins_with("[DEBUG"):
            s += "[color=#999082]" + line.xml_escape() + "[/color]\n"
        elif line.begins_with("[STATION") or line.begins_with("[LITURGIE"):
            s += "[color=#6090c0]" + line.xml_escape() + "[/color]\n"
        else:
            s += line.xml_escape() + "\n"
    _log_rtl.text = s
    _log_rtl.scroll_to_line(_log_rtl.get_line_count())

func _render_debug() -> void:
    var rep := EndGameResolver.check_rupture(state)
    var fiat := EndGameResolver.check_fiat_tenebris(state)
    var vol := state.domain(GameEnums.DomainId.VOLONTE)
    var s := "[b][color=#d4a73d]ÉTAT DES RÈGLES[/color][/b]\n"
    s += "[color=#c8324c]Rouge[/color] : %d Corruptions\n" % state.available_corruption[GameEnums.PlayerId.RED]
    s += "[color=#3c6bc8]Bleu[/color] : %d Corruptions\n" % state.available_corruption[GameEnums.PlayerId.BLUE]
    s += "Profondeur : %s  Étendue : %s  Ancrage : %s\n" % [
        "[color=#41a05a]✓[/color]" if rep.profondeur else "[color=#c8324c]✗[/color]",
        "[color=#41a05a]✓[/color]" if rep.etendue else "[color=#c8324c]✗[/color]",
        "[color=#41a05a]✓[/color]" if rep.ancrage else "[color=#c8324c]✗[/color]",
    ]
    s += "Rupture complète : %s\n" % ("[color=#41a05a]OUI[/color]" if rep.complete else "non")
    s += "Fiat Tenebris : %s\n" % (GameEnums.player_name(fiat) if fiat != GameEnums.PlayerId.NONE else "non")
    s += "Volonté scellée : %s\n" % GameEnums.player_name(vol.seal_owner)
    _debug_rtl.text = s

func _render_transgressions() -> void:
    for c in _transg_box.get_children():
        c.queue_free()
    for player in [GameEnums.PlayerId.RED, GameEnums.PlayerId.BLUE]:
        var color := C_RED if player == GameEnums.PlayerId.RED else C_BLUE
        var header := Label.new()
        header.text = "%s — Transgressions" % GameEnums.player_name(player)
        header.add_theme_color_override("font_color", color)
        _transg_box.add_child(header)
        var any := false
        for d_id in DomainData.DOMAINS:
            var d := state.domain(d_id)
            for ti in d.scandals:
                if ti.owner == player:
                    var l := Label.new()
                    l.text = "  • %s — Scandale en %s" % [TransgressionData.name_of(ti.def_id), GameEnums.DOMAIN_NAMES[d_id]]
                    _transg_box.add_child(l)
                    any = true
            for ti in d.infamies:
                if ti.owner == player:
                    var l2 := Label.new()
                    l2.text = "  ✦ %s — INFAMIE en %s" % [TransgressionData.name_of(ti.def_id), GameEnums.DOMAIN_NAMES[d_id]]
                    l2.add_theme_color_override("font_color", color)
                    _transg_box.add_child(l2)
                    any = true
        if not any:
            var none_lbl := Label.new()
            none_lbl.text = "  (aucune)"
            none_lbl.add_theme_color_override("font_color", C_MUTED)
            _transg_box.add_child(none_lbl)

# ─── ACTION HANDLING ──────────────────────────────────────────────────────────

func _is_action_potentially_legal(action: int, p: int) -> bool:
    match action:
        GameEnums.ActionId.INVESTIR:
            if state.available_corruption[p] < 1: return false
            for d_id in DomainData.DOMAINS:
                if GameRules.can_investir(state, p, d_id): return true
            return false
        GameEnums.ActionId.EXPLOITER:
            for d_id in DomainData.DOMAINS:
                if GameRules.can_exploiter(state, p, d_id): return true
            return false
        GameEnums.ActionId.PROVOQUER:
            for tid in TransgressionData.ALL_IDS:
                if GameRules.can_provoquer(state, p, tid): return true
            return false
        GameEnums.ActionId.AMPLIFIER:
            for tid in TransgressionData.ALL_IDS:
                if GameRules.can_amplifier(state, p, tid): return true
            return false
        GameEnums.ActionId.SCELLER:
            for d_id in DomainData.DOMAINS:
                if GameRules.can_sceller(state, p, d_id): return true
            return false
        GameEnums.ActionId.FISSURER:
            for d_id in DomainData.DOMAINS:
                if GameRules.can_fissurer(state, p, d_id): return true
            return false
        GameEnums.ActionId.ENTRAVER:
            for st_id in [state.current_station, state.current_station + 1, state.current_station + 2]:
                if GameRules.can_entraver(state, p, st_id): return true
            return false
        GameEnums.ActionId.PASSER:
            return true
    return false

func _on_action_chosen(action: int) -> void:
    pending_action = action
    if action == GameEnums.ActionId.PASSER:
        _commit_action()
        return
    _render_prompt()

func _commit_action(kw: Dictionary = {}) -> void:
    var action := pending_action
    pending_action = -1
    var result := manager.perform_action(action, kw)
    if not result.get("ok", false):
        state.add_log("[ACTION REFUSÉE] " + result.get("message", "?"))
    _rebuild_all()

func _cancel_pending() -> void:
    pending_action = -1
    _render_prompt()

func _resolve_decision(picks: Dictionary) -> void:
    var r := manager.resolve_decision(picks)
    if not r.get("ok", false):
        state.add_log("[DÉCISION REFUSÉE] " + r.get("message", "?"))
    _rebuild_all()

func _force_pop_decision() -> void:
    if state.has_pending_decisions():
        state.pending_decisions.pop_front()
        if not state.has_pending_decisions() and manager._pending_advance_to_station >= 0:
            var s = manager._pending_advance_to_station
            manager._pending_advance_to_station = -1
            manager._advance_to_station(s)
    _rebuild_all()

# ─── DEBUG BUTTONS ────────────────────────────────────────────────────────────

func _on_btn_new_game() -> void: new_game()

func _on_btn_force_next_station() -> void:
    if state.game_over: return
    state.current_pulse = GameEnums.STATION_PULSES[state.current_station]
    manager._pulse_actions_done[GameEnums.PlayerId.RED] = true
    manager._pulse_actions_done[GameEnums.PlayerId.BLUE] = true
    manager._end_pulse()
    _rebuild_all()

func _on_btn_force_exorcism() -> void:
    if state.game_over: return
    manager.force_advance_to_exorcism()
    state.current_pulse = GameEnums.STATION_PULSES[GameEnums.StationId.EXORCISME]
    manager._pulse_actions_done[GameEnums.PlayerId.RED] = true
    manager._pulse_actions_done[GameEnums.PlayerId.BLUE] = true
    manager._end_pulse()
    _rebuild_all()

func _on_btn_add_corruption() -> void:
    if state.game_over: return
    state.add_corruption_pool(state.active_player, 1)
    state.add_log("[DEBUG] +1 Corruption à %s." % GameEnums.player_name(state.active_player))
    _rebuild_all()

func _on_btn_run_tests() -> void:
    var runner := RulesTestRunner.new()
    var res := runner.run_all()
    state.add_log("=== TESTS : %d/%d PASS, %d FAIL ===" % [res["pass"], res["total"], res["fail"]])
    for line in res["lines"]:
        state.add_log(String(line))
    _render_log()

func _on_btn_save() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        state.add_log("[DEBUG] Sauvegarde impossible.")
        _render_log()
        return
    f.store_string(JSON.stringify(state.to_dict()))
    f.close()
    state.add_log("[DEBUG] Sauvegarde : %s" % SAVE_PATH)
    _render_log()

func _on_btn_load() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        state.add_log("[DEBUG] Pas de sauvegarde.")
        _render_log()
        return
    var txt := f.get_as_text()
    f.close()
    var d = JSON.parse_string(txt)
    if d == null:
        state.add_log("[DEBUG] Sauvegarde corrompue.")
        _render_log()
        return
    state = GameState.new()
    state.from_dict(d)
    manager = TurnManager.new(state, false)
    _rebuild_all()
