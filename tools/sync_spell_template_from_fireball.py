#!/usr/bin/env python3
"""从 fire_ball 一键刷新 templates/spell（可反复重跑，模板永远等于 fire_ball 最新状态）。

法术版 sync_template_from_chen：复制 → 占位命名 → 身份 token 化 → 内部引用去 uid
→ 残留断言。创建器(spell_creator.gd)零改动。

排除：sprites_master/（新法术自产母版）、.uid/.import 伴生、
触发器件（spell_template.*、README.md 永不参与同步）。
"""
import os, re, shutil, sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(REPO, "spells/fire_ball")
DST = os.path.join(REPO, "templates/spell")
KEEP_IN_DST = {"spell_template.tscn", "spell_template.gd", "spell_template.gd.uid", "README.md"}

FILE_TOKENS = [
    ("/fire_ball_skin.tscn", "/__NAME___skin.tscn"), ("/fire_ball_skin.gd", "/__NAME___skin.gd"),
    ("/fire_ball.gd", "/__NAME__.gd"), ("/fire_ball.tscn", "/__NAME__.tscn"),
    ("/fire_ball_definition.tres", "/__NAME___definition.tres"),
    ("/fire_ball_attack_data.tres", "/__NAME___attack_data.tres"),
    ("/spriteframes_fire_ball.tres", "/spriteframes___NAME__.tres"),
    ("/anim_library_fire_ball.tres", "/anim_library___NAME__.tres"),
]
RENAME = {
    "fire_ball.gd": "__NAME__.gd", "fire_ball.tscn": "__NAME__.tscn",
    "fire_ball_skin.gd": "__NAME___skin.gd", "fire_ball_skin.tscn": "__NAME___skin.tscn",
    "resources/fire_ball_definition.tres": "resources/__NAME___definition.tres",
    "resources/attacks/fire_ball_attack_data.tres": "resources/attacks/__NAME___attack_data.tres",
    "resources/spriteframes_fire_ball.tres": "resources/spriteframes___NAME__.tres",
    "resources/anim_library_fire_ball.tres": "resources/anim_library___NAME__.tres",
}

def skip_rel(rel: str) -> bool:
    parts = rel.split(os.sep)
    if "sprites_master" in parts or "png_scale_backup" in parts:
        return True
    f = parts[-1]
    return f.endswith((".import", ".uid")) or ".backup-" in f

def tokenize(text: str) -> str:
    for old, new in FILE_TOKENS:                 # 1) 文件名词
        text = text.replace(old, new)
    text = text.replace("spells/fire_ball/", "spells/__NAME__/")   # 2) 目录
    text = text.replace("FireBallSkin", "__CLASS__Skin")           # 3) 长类名先行
    text = re.sub(r'node name="FireBall"(\s|])', r'node name="__CLASS__"\1', text)
    text = text.replace("libraries/FireBall", "libraries/__CLASS__")
    text = text.replace('&"FireBall/', '&"__CLASS__/')
    text = class_in_script(text)
    text = text.replace('"火球术"', '"__DISPLAY_NAME__"')           # 4) 显示名
    text = text.replace("## 火球术 法术", "## __DISPLAY_NAME__ 法术")
    text = text.replace("fire_ball", "__NAME__")                   # 5) 剩余小写身份（spell_id 等）
    # 6) 文件头 uid 剥离
    text = re.sub(r'^\[(gd_scene|gd_resource)\b([^\]]*)\]',
                  lambda m: "[" + m.group(1) + re.sub(r'\s+uid="uid://[^"]*"', "", m.group(2)) + "]",
                  text, flags=re.M)
    def strip_int(m):
        line = m.group(0)
        if "spells/__NAME__/" in line:
            line = re.sub(r' uid="uid://[^"]*"', "", line)
        return line
    text = re.sub(r'\[ext_resource [^\]]*\]', strip_int, text)
    return text

def class_in_script(text: str) -> str:
    # 脚本类名声明（若源里有 class_name FireBall）
    return re.sub(r'\bclass_name FireBall\b', "class_name __CLASS__", text)

# ---------- 0. 源头守卫：fire_ball 战斗组声明完好（防编辑器手滑扩散） ----------
# 守卫随 326fece 阵营重构换岗（对齐角色 sync 的"皮肤零阵营残留"同款形态）：
# 弹体战斗盒阵营改由 spell_base 运行时按施法者注入，皮肤场景不再携带任何
# area2d: 标签。旧守卫（要求恰 1 枚自名标签）属重构漏网，且曾把模板快照里的
# 死行喂给新建法术（2026-09-18 击飞统一模型批牵出）。
src_skin = open(os.path.join(SRC, "fire_ball_skin.tscn"), encoding="utf-8").read()
if src_skin.count("area2d:") != 0:
    print(f"  ✗ fire_ball_skin.tscn 阵营残留：area2d: 出现 {src_skin.count('area2d:')} 次（应为 0）")
    print("    法术皮肤应零阵营数据（运行时按施法者注入）；排查编辑器保存或手工改动")
    sys.exit(1)

# ---------- 1. 复制 ----------
if os.path.exists(DST):
    for entry in os.listdir(DST):
        if entry in KEEP_IN_DST:
            continue
        p = os.path.join(DST, entry)
        shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
copied = 0
for root, _, files in os.walk(SRC):
    for f in files:
        src = os.path.join(root, f)
        rel = os.path.relpath(src, SRC)
        if skip_rel(rel):
            continue
        dst_rel = RENAME.get(rel, rel)
        dst = os.path.join(DST, dst_rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        copied += 1

# ---------- 2. 文本占位符化 ----------
TEXT_EXT = (".tscn", ".tres", ".gd")
changed = 0
for root, _, files in os.walk(DST):
    for f in files:
        if not f.endswith(TEXT_EXT) or f.startswith("spell_template"):
            continue
        p = os.path.join(root, f)
        s = open(p, encoding="utf-8").read()
        t = tokenize(s)
        if t != s:
            open(p, "w", encoding="utf-8").write(t)
            changed += 1

# ---------- 3. 残留断言 ----------
problems = []
for root, _, files in os.walk(DST):
    for f in files:
        if not f.endswith(TEXT_EXT) or f.startswith("spell_template"):
            continue
        p = os.path.join(root, f)
        s = open(p, encoding="utf-8").read()
        relp = os.path.relpath(p, DST)
        for token in ("fire_ball", "FireBall", "火球术"):
            if token in s:
                problems.append(f"{relp}: 残留 {token}")
        if f.endswith((".tscn", ".tres")) and "uid://dx" in s and "__NAME__" not in s:
            problems.append(f"{relp}: 意外保留 ext uid")
if problems:
    print("  ✗ 残留断言失败:")
    for x in problems:
        print("   ", x)
    sys.exit(1)

print(f"复制 {copied} 个文件，占位符化 {changed} 个文本")
print("断言通过：模板内已无任何 fire_ball 身份残留")
