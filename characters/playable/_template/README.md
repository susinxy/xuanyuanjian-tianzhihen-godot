# 角色模板（_template）

> 2026-09-14 起：模板内容 = **chen 的占位符化快照**（旧"骨架模板"退役）。
> 新角色创建出来即自带完整可跑状态：全动画结构 + 演示图（chen 的图）+ 属性/攻击演示值。

## 创建新角色（不变）

Inspector 面板流程原样：打开 `character_template.tscn` → 填英文名/类名/显示名 → Create。
占位符：`__NAME__`（snake）、`__CLASS__`（Pascal）、`__DISPLAY_NAME__`。

## 创建后的三步工作流

1. **换图 = 同名覆盖**。目录结构即 chen 规范：
   - `resources/sprites/<attackN|idle|walk|run|hurt|jump|knock_out|air_attack>/<方向>/<动画名>_<槽号两位>.png`
   - 新角色画好的图用**相同文件名**盖掉占位图即可，所有引用零改动
   - `__NAME___profile.png` 是头像（被 attributes 引用），同样同名覆盖
2. **跑两类轮廓转换**（Body + Attack，Inspector 高度层面板）：
   轮廓/身高/攻击窗口/时间轴全部按新图重算——占位图带来的 chen 数据会被自动冲掉
3. **体检归零**（面板"attack 结构体检"无告警）+ 按需在编辑器调属性/攻击数值

可选：若走"大图画、缩着进游戏"的缩放管线，创建后自行建 `resources/sprites_master/`
（模板**不带**母版目录、账本、蒙版和跳过标记——新角色自己产生）。

## 刷新模板（chen 更新后）

```
python3 tools/sync_template_from_chen.py
```

从 chen 目录一键重拍"标准照"（复制→占位命名→身份替换→内部引用去 uid→残留断言），
可反复执行；`character_template.*` 触发文件永不触碰。脚本失败（残留非零）时勿提交。
