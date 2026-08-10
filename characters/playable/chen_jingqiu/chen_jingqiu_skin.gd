@tool
extends QuiverCharacterSkinAnimTree
## 陈靖仇的皮肤（视觉层）
##
## 继承 QuiverCharacterSkinAnimTree（AnimationTree 版本）。
## 使用 BlendSpace1D 处理 left/right 朝向，而不是 flip_h。
##
## AnimationTree 树形结构（参考 Downtown Beatdown 模板，BlendTree 包裹 StateMachine）：
##   tree_root = AnimationNodeBlendTree
##     ├── StateMachine (AnimationNodeStateMachine, 用插件默认命名)
##     │     ├── idle (BlendSpace1D)
##     │     │     ├── idle_left   @ blend_position = -1
##     │     │     └── idle_right  @ blend_position = +1
##     │     └── walk (BlendSpace1D)
##     │           ├── walk_left   @ blend_position = -1
##     │           └── walk_right  @ blend_position = +1
##     └── Output
##
## _path_playback 用插件默认值 "parameters/StateMachine/playback"，无需 override。
##
## 父类已实现：transition_to()、_skin_direction_updated()、_update_blend_directions() 等。
## 本脚本目前不添加任何额外逻辑，完全复用父类能力。
##
## 动画层的状态管理由游戏逻辑层的 QuiverActionIdle / QuiverActionWalk 通过
## `_skin.transition_to("idle")` / `_skin.transition_to("walk")` 驱动。
