extends CharacterBody2D

## 修士（玩家）移动脚本
## M1 任务 1 —— 仅实现俯视角 WASD 移动，不含战斗 / 升级 / 机缘等系统。

@export var speed: float = 200.0
@export var max_qi_blood: int = 100
@export var max_mana: int = 50

var qi_blood: int
var mana: int


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	qi_blood = max_qi_blood
	mana = max_mana


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	velocity = direction * speed
	move_and_slide()
