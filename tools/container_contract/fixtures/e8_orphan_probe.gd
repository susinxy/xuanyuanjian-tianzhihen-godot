extends Node

## E8 靶面（B2-T1）：切换链在途时壳被删——修复后链让位静默、E8-DONE 干净收口。
## 子进程跑（父侧 _flow_orphan 经共享 helper 重定向捕获本场景 stdout/stderr）。
## 指纹实探判词（Step 0，Linux 4.7.1 headless 实测）：本靶面及 6 种变体
## （free/queue_free/定时器自删/嵌套 await/执行中自删）对修复前代码全部
## 静默死亡、stderr 零输出——GDScriptInstance 析构主动 _clear_connections()
## 断开在途协程信号（godot 4.7 gdscript.cpp:2066-2079），"Resumed function"
## 指纹在本平台不可达。故 E8b（指纹不存在）在 Linux 恒绿、仅作 Windows 侧
## 回归锁；承红由 E8c 结构守卫承担（callv 动态调用不得再返回协程状态）。

const FIX_CHAPTER := "res://tools/container_contract/fixtures/chapter_fix.tscn"


func _ready() -> void:
	var shell: ChapterShell = load(FIX_CHAPTER).instantiate()
	add_child(shell)
	await get_tree().physics_frame   # 等 _ready 进首段链走完
	shell.switch_segment(&"seg_b")
	await get_tree().create_timer(0.5).timeout   # 90 静默帧窗正中
	shell.free()                     # 孤儿化在途链
	await get_tree().create_timer(3.0).timeout
	print("E8-DONE")
	get_tree().quit(0)
