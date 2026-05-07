extends SceneTree
# Balance runner for the Missel Corrompu modifiers.
# NOT part of CI — run manually when testing modifier balance.
# Run with:
#   godot --headless --path . --script res://scripts/cli/run_balance.gd
# Optional: pass n as an argument for parties per modifier (default 20):
#   godot --headless --path . --script res://scripts/cli/run_balance.gd -- 50


func _initialize() -> void:
	var n := 20
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		n = int(args[0])

	var runner = load("res://scripts/bot/tests/BotTestRunner.gd").new()
	var r: Dictionary = runner.run_balance(n)
	for line in r["lines"]:
		print(String(line))
	print("")
	print("=== Balance : %d/%d PASS, %d FAIL ===" % [r["pass"], r["total"], r["fail"]])
	quit(0 if r["fail"] == 0 else 1)
