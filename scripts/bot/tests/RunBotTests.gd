extends SceneTree

func _initialize() -> void:
	var r := BotTestRunner.new().run_all()
	for line in r["lines"]:
		print(line)
	print("\n%d/%d PASS" % [r["pass"], r["total"]])
	quit(0 if r["fail"] == 0 else 1)
