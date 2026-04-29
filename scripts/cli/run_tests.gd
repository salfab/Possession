extends SceneTree
# Headless test driver for the Possession rules engine.
# Run with:
#   godot --headless --path . --script res://scripts/cli/run_tests.gd
#
# Exits with code 0 if every test passes, 1 otherwise.
# Output is suitable for CI logs (one PASS/FAIL line per test, then a summary).


func _initialize() -> void:
	var runner := RulesTestRunner.new()
	var res := runner.run_all()
	for line in res["lines"]:
		print(String(line))
	print("")
	print("=== %d/%d PASS, %d FAIL ===" % [res["pass"], res["total"], res["fail"]])
	var exit_code := 0 if int(res["fail"]) == 0 else 1
	quit(exit_code)
