extends CharacterBody2D

## 盒契约探针体：恒定速度驱动 move_and_slide（判例合规：裸舞台角色初速沉降
## 相位随机——本腿自带确定性，不用活体角色推演边界几何）。mask=全高度层，
## 真实角色持当前高度位 ⊆ 全集，墙带可见性判据保守等价。

var axis := Vector2.ZERO
var speed := 400.0

const HEIGHT_ALL := 16760832


func _ready() -> void:
	collision_layer = HEIGHT_ALL
	collision_mask = HEIGHT_ALL
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 20)
	shape.shape = rs
	add_child(shape)


func _physics_process(_delta: float) -> void:
	velocity = axis * speed
	move_and_slide()
