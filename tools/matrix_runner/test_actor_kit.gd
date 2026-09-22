class_name TestActorKit
extends RefCounted
## 测试替身全套件：为回归矩阵创建/销毁专属角色 `test_actor`。
##
## 创建与销毁都走**真实产线**（CharacterCreator / CharacterDeleter，与编辑器
## Inspector 同一入口）——每次矩阵全量跑顺带产线活审计（headless 探针实锤：
## 产线是 RefCounted + DirAccess/FileAccess 纯文本手术，无 EditorInterface 依赖，
## headless -s 直接可用）。
##
## 主权归属（Task2 评审 R2/R6 定档，不可协商）：
## - 共享替身 `test_actor` 的创建/导入/销毁**只属于 run_matrix.sh**；
##   消费套**只读**消费（exists()/ensure() 幂等读），**禁止 Kit.destroy()**
##   ——通跑中途销毁会让后续套名的 ensure() 永远拿不到 OK（进程间纹理失明）。
## - 需要"全创建→全销毁"破坏性周期演练的套件（interact_contract S2），
##   传入**私有草稿名**（如 test_actor_scratch）自生自灭、零残留，
##   绝不动共享替身。
##
## ensure(p_name) 三态契约（run_matrix.sh 消费，语义如下）：
## - `OK`(0)：文件齐且**本进程可加载**——上轮产线已创建、且已过一遍 --import。
## - `NEEDS_IMPORT`(=Kit.NEEDS_IMPORT，42)：本进程刚创建完文件（或目录在但纹理
##   未导入）。当前进程无法导入纹理，调用方须先跑 `godot --headless --import`
##   再重开进程调 ensure()，第二跑即 OK。
## - `ERR_CANCELED`(=1)：产线创建失败或产物缺文件，诊断已打印。
##
## 导入判据实测定档（4.7.1 headless 探针，勿再凭直觉换判据）：
## `ResourceLoader.exists(主场景)` 与 `load(主场景)` 在**纹理未导入时同样返回
## 真值**（.tscn 本体是文本资源；缺 .import 的 png 只报 "No loader found" 错误、
## 场景仍降级加载成功）——两者都不能当导入门。唯一廉价可靠的信号是**产线固定
## 路径的头像 png 的 `.import` 伴生文件**（`_synthesize_attributes` 契约引用
## `resources/sprites/<name>_profile.png`，创建必落此位；导入必为其生成 sidecar）；
## 且 sidecar 尚须指向一个真实存在的 `.ctex` 实体（R5 强化：Syncthing 只同步来
## sidecar 而本机 `.godot/imported` 缓存是全新时，sidecar 在场≠纹理可加载）。

const ACTOR_NAME := "test_actor"
const ACTOR_DIR := "res://characters/playable/test_actor"
const ACTOR_SCENE := ACTOR_DIR + "/test_actor.tscn"
## 裸皮肤场景（不含角色壳）：attack_freeze_repro 这类"只要皮肤+AnimTree"的
## 取证台消费点（产线命名约定 <name>_skin.tscn，与 _required_files 同源）。
const ACTOR_SKIN_SCENE := ACTOR_DIR + "/test_actor_skin.tscn"

## shell 侧识别的"需先 --import 再重跑"退出码
const NEEDS_IMPORT := 42
## 产线失败退出码（本构建 `Error.CANCELED` 成员访问不被解析器接受——判例：
## 4.7.1 headless "Cannot find member CANCELED in base Error"，故自带常量）
const ERR_CANCELED := 1

# 产线类用 preload 路径引用：全局类缓存要编辑器扫描才登记，headless 测试进程
# 不重扫（template_cloner 头注同源判例）。
const _Creator := preload("res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/character_creator.gd")
const _Deleter := preload("res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/character_deleter.gd")

## 角色产物的路径推导（全部从名字来；默认名 = 共享替身 test_actor，
## 常量 ACTOR_DIR/ACTOR_SCENE 即其字面特例，历史消费点零改动）
static func _dir_for(p_name: String) -> String:
	return "res://characters/playable/" + p_name


static func _scene_for(p_name: String) -> String:
	return _dir_for(p_name) + "/" + p_name + ".tscn"


## 导入门文件（见文件头判据实测定档）
static func _gate_for(p_name: String) -> String:
	return _dir_for(p_name) + "/resources/sprites/" + p_name + "_profile.png.import"


## snake_case 名 → PascalCase 类名（零信任：不赌 to_pascal_case 存在，
## 本仓库判例要求引擎 API 写前探一次；手写 split+capitalize 无版本风险）
static func _class_for(p_name: String) -> String:
	var cls := ""
	for part in p_name.split("_"):
		if String(part).is_empty():
			continue
		cls += String(part)[0].to_upper() + String(part).substr(1)
	return cls


## 产线必备产物（创建成功后逐文件断言；缺任何一个 = CANCELED）
static func _required_files(p_name: String) -> Array[String]:
	return [
		p_name + ".tscn",
		p_name + "_skin.tscn",
		p_name + ".gd",
		p_name + "_skin.gd",
		"resources/" + p_name + "_attributes.tres",
		"resources/anim_library_" + p_name + ".tres",
		"resources/spriteframes_" + p_name + ".tres",
		"resources/attacks/punch1_attack_data.tres",
		"resources/attacks/punch2_attack_data.tres",
		"resources/attacks/punch3_attack_data.tres",
		"resources/attacks/air_kick_attack_data.tres",
	]


## 目录与主场景文件都在（不代表可加载，可加载性看 _imported()）
static func exists(p_name: String = ACTOR_NAME) -> bool:
	var dir := _dir_for(p_name)
	return DirAccess.dir_exists_absolute(dir) and FileAccess.file_exists(_scene_for(p_name))


## 三态就绪检查：详见文件头契约。幂等——已就绪时零副作用。
## 注意：名字缺席时 ensure 会走创建（供 run_matrix.sh / 草稿演练用）；
## 只读消费套必须先自判 exists() 再调，缺席即报可读红（R6 消费铁律）。
static func ensure(p_name: String = ACTOR_NAME) -> int:
	if exists(p_name) and _imported(p_name):
		return OK
	if not exists(p_name):
		var creator = _Creator.new()
		var ok: bool = creator.create_character(
				p_name, _class_for(p_name), "测试替身", "player", {}, [],
				_Creator.ControlMode.PLAYER_INPUT)
		if not ok:
			push_error("[TestActorKit] CharacterCreator 产线创建失败（诊断见上行 push_error）")
			return ERR_CANCELED
		var dir := _dir_for(p_name)
		for rel in _required_files(p_name):
			if not FileAccess.file_exists(dir.path_join(rel)):
				push_error("[TestActorKit] 产线产物缺失: %s" % dir.path_join(rel))
				return ERR_CANCELED
	# 走到这里：要么本轮刚创建完（文件在、纹理未导入），要么目录早已存在但
	# 缺 .import（上轮崩溃/手工拷入）——两种形态的处方相同：--import 后重跑。
	return NEEDS_IMPORT


## 递归删除 _dir_for(p_name)（走真实 CharacterDeleter 产线）。幂等：不存在 = OK。
## 共享替身只有 run_matrix.sh 有资格调它；草稿名由演练套自生自灭。
static func destroy(p_name: String = ACTOR_NAME) -> int:
	var dir := _dir_for(p_name)
	if not DirAccess.dir_exists_absolute(dir):
		return OK
	var deleter = _Deleter.new()
	if not deleter.delete_character(p_name, "playable"):
		push_error("[TestActorKit] CharacterDeleter 产线删除失败")
		return ERR_CANCELED
	return OK


## 导入判据（R5 强化，2026-09-22）：sidecar 在场**且**其 `path=` 指向的
## `.godot/imported/*.ctex` 实体也存在，才算导入完成。
## 为什么只看 sidecar 不够：Syncthing 会把 `.import` 伴生文件（跟源 png 同目录、
## 纳入版本/同步范围）同步到本机，但 `.godot/imported/` 是本机缓存——新克隆或清缓存
## 后 sidecar 在、`.ctex` 不在，`load` 会静默降级成占位纹理，属"OK-when-not-fine"
## 误判（下轮矩阵用假替身仍绿）。故二次核验 `.ctex` 实体（真实 sidecar 行样例见
## characters/enemies/spar_enemy/.../spar_enemy_profile.png.import：
## `path="res://.godot/imported/spar_enemy_profile.png-<hash>.ctex"`）。
static func _imported(p_name: String = ACTOR_NAME) -> bool:
	var gate := _gate_for(p_name)
	if not FileAccess.file_exists(gate):
		return false
	var sidecar := FileAccess.get_file_as_string(gate)
	var marker := "path=\"res://"
	var at := sidecar.find(marker)
	if at == -1:
		# sidecar 在但无 res:// path 键（畸形/空）：宁保守判未导入，逼调用方重跑 --import
		return false
	var rest := sidecar.substr(at + marker.length())
	var end := rest.find("\"")
	if end == -1:
		return false
	var ctex := "res://" + rest.substr(0, end)
	return ctex.ends_with(".ctex") and FileAccess.file_exists(ctex)
