extends RefCounted
## 主权身份探针（Task 1 一次性探针的常驻化，interact_contract S 流调用）。
##
## 职责：在**活着的套件进程**内把 test_actor 主场景真正挂进场景树、跑若干物理
## 帧、采集"这个测试替身是否活着且身份正确"的证据，再把临时壳摘干净。
##
## 前置铁律：只有当 test_actor 已被**导入**（其 profile png 的 .import sidecar
## 指向的 .ctex 实体在盘上）时，load→instantiate 才会得到可用的皮肤/动画资源。
## 未导入时 load 会静默降级（No loader found→占位），探针的 sprite_frames/状态机
## 判据将失真——那正是 run_matrix.sh 用 ensure()==OK 把关、把身份断言只在
## "进场时 ensure 已报 OK（=通跑器导入过）"的状态下执行的原因（见 S 流门控）。
##
## 用法（协程）：`var report: Dictionary = await Probe.identity_check(self)`
## report 形如 {loadable, in_player_group, skin_ok, frames_ok, sm_ok, idle_ok,
##              state_name, error}。任一硬前置失败（load 不出 PackedScene）时
## error 给出**可操作**文本（含 run_matrix.sh 字样），绝不静默返空。

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")


## 在 host 节点所在场景树里加载并挂载 test_actor，await 物理帧后采集证据，
## 全程零残留（自带摘树 + free）。返回观察字典供 S 流逐条 _check。
static func identity_check(host: Node) -> Dictionary:
	var report := {
		"loadable": false,
		"in_player_group": false,
		"skin_ok": false,
		"frames_ok": false,
		"sm_ok": false,
		"idle_ok": false,
		"state_name": "",
		"error": "",
	}
	var packed := load(Kit.ACTOR_SCENE)
	if not (packed is PackedScene):
		report.error = (
				"load(%s) 未得 PackedScene——test_actor 未被本进程导入。"
				% Kit.ACTOR_SCENE
				+ "经 tools/matrix_runner/run_matrix.sh --only <suite> 走一遍 "
				+ "destroy-first/ensure/--import 生命周期后再跑。")
		push_error("[SovereigntyProbe] " + report.error)
		return report
	report.loadable = true

	# 临时壳：Node2D 承载，摘树即走，绝不与正式关卡/战斗树混居。
	var holder := Node2D.new()
	holder.name = "SovereigntyHolder"
	host.add_child(holder)
	var actor := (packed as PackedScene).instantiate()
	holder.add_child(actor)

	# add_child 后立即断言=假现场（判例）：必须 await 过 _ready/@onready 提交帧。
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame

	report.in_player_group = actor.is_in_group("area2d:player")

	var skin: Node = actor.get("_skin")
	report.skin_ok = skin != null
	if skin != null:
		var spr: Node = skin.get_node_or_null("AnimatedSprite2D")
		if spr != null:
			var frames: SpriteFrames = spr.sprite_frames
			report.frames_ok = frames != null and frames.get_animation_names().size() > 0

	# 状态机：直接取场景里的 StateMachine 子节点（公开 state_machine getter
	# 在 @onready 后才等价于此，取节点更稳、不吃基类静态检查误杀）。
	var body_sm := actor.get_node_or_null("StateMachine")
	report.sm_ok = body_sm != null
	if body_sm != null:
		# 出生应落在 initial_state=Ground/Move/Idle；"idle-ish"作 nice-to-have，
		# 允许有限轮询等 owner.ready 链把状态摆正（cap 短，不拖套件）。
		var sn := String(body_sm.get("state_name"))
		for _i in 12:
			if sn.contains("Idle"):
				break
			await host.get_tree().physics_frame
			sn = String(body_sm.get("state_name"))
		report.state_name = sn
		report.idle_ok = sn.contains("Idle")

	# 摘干净：free holder 连带 actor（无 queue_free 竞态——S 流后续无对该实例引用）。
	host.remove_child(holder)
	holder.free()
	return report
