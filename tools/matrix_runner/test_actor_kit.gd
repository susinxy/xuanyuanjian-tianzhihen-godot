class_name TestActorKit
extends RefCounted
## 测试替身全套件：为回归矩阵创建/销毁专属角色 `test_actor`。
##
## 创建与销毁都走**真实产线**（CharacterCreator / CharacterDeleter，与编辑器
## Inspector 同一入口）——每次矩阵全量跑顺带产线活审计（headless 探针实锤：
## 产线是 RefCounted + DirAccess/FileAccess 纯文本手术，无 EditorInterface 依赖，
## headless -s 直接可用）。
##
## ensure() 三态契约（run_matrix.sh 消费，语义如下）：
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
## `resources/sprites/<name>_profile.png`，创建必落此位；导入必为其生成 sidecar）。

const ACTOR_NAME := "test_actor"
const ACTOR_DIR := "res://characters/playable/test_actor"
const ACTOR_SCENE := ACTOR_DIR + "/test_actor.tscn"

## shell 侧识别的"需先 --import 再重跑"退出码
const NEEDS_IMPORT := 42
## 产线失败退出码（本构建 `Error.CANCELED` 成员访问不被解析器接受——判例：
## 4.7.1 headless "Cannot find member CANCELED in base Error"，故自带常量）
const ERR_CANCELED := 1

# 产线类用 preload 路径引用：全局类缓存要编辑器扫描才登记，headless 测试进程
# 不重扫（template_cloner 头注同源判例）。
const _Creator := preload("res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/character_creator.gd")
const _Deleter := preload("res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/character_deleter.gd")

## 导入门文件（见文件头判据实测定档）
const _IMPORT_GATE := ACTOR_DIR + "/resources/sprites/test_actor_profile.png.import"

## 产线必备产物（创建成功后逐文件断言；缺任何一个 = CANCELED）
const REQUIRED_FILES := [
	"test_actor.tscn",
	"test_actor_skin.tscn",
	"test_actor.gd",
	"test_actor_skin.gd",
	"resources/test_actor_attributes.tres",
	"resources/anim_library_test_actor.tres",
	"resources/spriteframes_test_actor.tres",
	"resources/attacks/punch1_attack_data.tres",
	"resources/attacks/punch2_attack_data.tres",
	"resources/attacks/punch3_attack_data.tres",
	"resources/attacks/air_kick_attack_data.tres",
]


## 目录与主场景文件都在（不代表可加载，可加载性看 _imported()）
static func exists() -> bool:
	return DirAccess.dir_exists_absolute(ACTOR_DIR) and FileAccess.file_exists(ACTOR_SCENE)


## 三态就绪检查：详见文件头契约。幂等——已就绪时零副作用。
static func ensure() -> int:
	if exists() and _imported():
		return OK
	if not exists():
		var creator = _Creator.new()
		var ok: bool = creator.create_character(
				ACTOR_NAME, "TestActor", "测试替身", "player", {}, [],
				_Creator.ControlMode.PLAYER_INPUT)
		if not ok:
			push_error("[TestActorKit] CharacterCreator 产线创建失败（诊断见上行 push_error）")
			return ERR_CANCELED
		for rel in REQUIRED_FILES:
			if not FileAccess.file_exists(ACTOR_DIR.path_join(rel)):
				push_error("[TestActorKit] 产线产物缺失: %s" % ACTOR_DIR.path_join(rel))
				return ERR_CANCELED
	# 走到这里：要么本轮刚创建完（文件在、纹理未导入），要么目录早已存在但
	# 缺 .import（上轮崩溃/手工拷入）——两种形态的处方相同：--import 后重跑。
	return NEEDS_IMPORT


## 递归删除 ACTOR_DIR（走真实 CharacterDeleter 产线）。幂等：不存在 = OK。
static func destroy() -> int:
	if not DirAccess.dir_exists_absolute(ACTOR_DIR):
		return OK
	var deleter = _Deleter.new()
	if not deleter.delete_character(ACTOR_NAME, "playable"):
		push_error("[TestActorKit] CharacterDeleter 产线删除失败")
		return ERR_CANCELED
	return OK


static func _imported() -> bool:
	return FileAccess.file_exists(_IMPORT_GATE)
