extends Control

@onready var output: RichTextLabel = $Output
@onready var summary: Label = $Summary

func _ready() -> void:
	var runner := RulesTestRunner.new()
	var res := runner.run_all()
	var s := ""
	for line in res["lines"]:
		s += String(line) + "\n"
	output.text = s
	summary.text = "Résultat : %d/%d PASS — %d FAIL" % [res["pass"], res["total"], res["fail"]]
