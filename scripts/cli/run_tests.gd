extends SceneTree
# Headless test driver for the Possession rules engine.
# Run with:
#   godot --headless --path . --script res://scripts/cli/run_tests.gd
#
# Exits with code 0 if every test passes, 1 otherwise.
# Output is suitable for CI logs (one PASS/FAIL line per test, then a summary).


func _initialize() -> void:
	var rules := RulesTestRunner.new()
	var r1 := rules.run_all()
	for line in r1["lines"]:
		print(String(line))
	print("--- Rules : %d/%d PASS ---" % [r1["pass"], r1["total"]])

	print("")

	var bots := BotTestRunner.new()
	var r2 := bots.run_all()
	for line in r2["lines"]:
		print(String(line))
	print("--- Bot   : %d/%d PASS ---" % [r2["pass"], r2["total"]])

	print("")
	var total_pass: int = int(r1["pass"]) + int(r2["pass"])
	var total_fail: int = int(r1["fail"]) + int(r2["fail"])
	var total_all: int  = int(r1["total"]) + int(r2["total"])
	print("=== %d/%d PASS, %d FAIL ===" % [total_pass, total_all, total_fail])
	quit(0 if total_fail == 0 else 1)
