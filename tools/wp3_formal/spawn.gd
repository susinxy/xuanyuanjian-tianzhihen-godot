extends SceneTree

## WP3 正式验证角色生成（幂等：已存在则跳过）。
## 运行：godot --headless --path . -s tools/wp3_formal/spawn.gd

const FORMAL := [
	{"name": "spar_enemy", "pascal": "SparEnemy", "display": "陪练敌人",
	"pkg": "enemies", "faction": "enemies", "mode": 1},
	{"name": "street_vendor", "pascal": "StreetVendor", "display": "站街小贩",
	"pkg": "neutrals", "faction": "neutrals", "mode": 2},
]


func _initialize() -> void:
	var creator := CharacterCreator.new()
	var failures := 0
	for spec in FORMAL:
		var dir := "res://characters/%s/%s" % [spec.pkg, spec.name]
		if DirAccess.dir_exists_absolute(dir):
			print("SKIP: %s 已存在" % spec.name)
			continue
		var ok := creator.create_character(
				spec.name, spec.pascal, spec.display, spec.faction,
				{}, [], spec.mode)
		if not ok:
			failures += 1
			print("FAIL: 创建 ", spec.name)
	print("spawn 完成，失败数=", failures)
	quit(0 if failures == 0 else 1)
