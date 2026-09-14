#!/usr/bin/env python3
"""从 chen 一键刷新 _template（可反复重跑，模板永远等于 chen 最新状态）。

做法 = 复制 chen → 换成占位命名 → 身份字符串占位符化 → 内部引用去 uid
     → 残留断言。创建器(character_creator.gd)零改动。

排除：sprites_master/、蒙版与跳过标记（新角色重画）、.uid/.import 伴生。
"""
import os, re, shutil, sys, filecmp

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(REPO, "characters/playable/chen")
DST = os.path.join(REPO, "characters/playable/_template")
KEEP_IN_DST = {"character_template.tscn", "character_template.gd", "character_template.gd.uid",
               "README.md", "create_character.sh",
               "__NAME___ai.gd", "__NAME___ai.gd.uid"}  # 默认策略小抄：模板自带，非 chen 来源

FILE_TOKENS = [  # 文件名占位（先文件名词，后目录词）
    ("/chen_skin.tscn", "/__NAME___skin.tscn"), ("/chen.gd", "/__NAME__.gd"),
    ("/chen.tscn", "/__NAME__.tscn"),
    ("/chen_attributes.tres", "/__NAME___attributes.tres"),
    ("/chen_gradient.tres", "/__NAME___gradient.tres"),
    ("/spriteframes_chen.tres", "/spriteframes___NAME__.tres"),
    ("/anim_library_chen.tres", "/anim_library___NAME__.tres"),
    ("/chen_profile.png", "/__NAME___profile.png"),
]
RENAME = {  # 落地后的物理改名
    "chen.gd": "__NAME__.gd", "chen.tscn": "__NAME__.tscn",
    "chen_skin.gd": "__NAME___skin.gd", "chen_skin.tscn": "__NAME___skin.tscn",
    "resources/chen_attributes.tres": "resources/__NAME___attributes.tres",
    "resources/chen_gradient.tres": "resources/__NAME___gradient.tres",
    "resources/spriteframes_chen.tres": "resources/spriteframes___NAME__.tres",
    "resources/anim_library_chen.tres": "resources/anim_library___NAME__.tres",
    "resources/sprites/chen_profile.png": "resources/sprites/__NAME___profile.png",
}

def skip_rel(rel: str) -> bool:
    parts = rel.split(os.sep)
    if "sprites_master" in parts or "png_scale_backup" in parts:
        return True
    f = parts[-1]
    if f.endswith((".import", ".uid")):
        return True
    if ".mask.png" in f or ".no.png" in f:
        return True
    if ".backup-" in f:  # 历史烘焙备份文件（轮廓工具时代遗留），不随模板传播
        return True
    return False

def tokenize(text: str) -> str:
    for old, new in FILE_TOKENS:            # 1) 文件名词
        text = text.replace(old, new)
    text = text.replace("characters/playable/chen/", "characters/__PKG__/__NAME__/")  # 2) 目录（含阵营包）
    text = text.replace("ChenSkin", "__CLASS__Skin")          # 3) 节点名与 _path_skin
    text = re.sub(r'node name="Chen"(\s|])', r'node name="__CLASS__"\1', text)
    text = text.replace("libraries/Chen", "libraries/__CLASS__")   # 4) 动画库键
    text = text.replace('&"Chen/', '&"__CLASS__/')                  #    AnimTree 引用
    text = text.replace("area2d:chen", "area2d:__NAME__")           # 5) 阵营组
    text = text.replace('"陈靖仇"', '"__DISPLAY_NAME__"')            # 6) 显示名
    # 7) 去文件头 uid（uid 属性在方括号内部任意位置）
    text = re.sub(r'^\[(gd_scene|gd_resource)\b([^\]]*)\]',
                  lambda m: "[" + m.group(1) + re.sub(r'\s+uid="uid://[^"]*"', "", m.group(2)) + "]",
                  text, flags=re.M)
    # 8) 去"指向本角色内部"的 ext uid（外部引用保留）
    def strip_int(m):
        line = m.group(0)
        if "__PKG__/__NAME__/" in line:
            line = line.replace(' uid="uid://', ' uidSTRIPPED="uid://')
            line = re.sub(r' uidSTRIPPED="uid://[^"]*"', "", line)
        return line
    text = re.sub(r'\[ext_resource [^\]]*\]', strip_int, text)
    return text

# ---------- 2.5 主场景专属注入（单壳行为档位，chen 快照本身没有） ----------
def inject_behavior_tokens(text: str, path: str) -> str:
    """仅对 __NAME__.tscn：根节点组占位 + behavior_mode 属性行。"""
    if not path.endswith("__NAME__.tscn"):
        return text
    n1 = text.count('groups=["players"]')
    assert n1 == 1, f"主 tscn 根节点 groups=[\"players\"] 出现 {n1} 次（应为 1）"
    text = text.replace('groups=["players"]', 'groups=["__BODY_GROUP__"]')
    root = re.search(r'\[node name="__CLASS__"[^\n]*instance=ExtResource\("[^"]*"\)\]\n', text)
    assert root, "主 tscn 未找到根节点行（name=__CLASS__ + instance）"
    if "behavior_mode = __BEHAVIOR_MODE__" in text:
        return text
    end = root.end()
    return text[:end] + "behavior_mode = __BEHAVIOR_MODE__\n" + text[end:]

# ---------- 0. 源头守卫：chen 的 faction group 声明必须完好（防编辑器手滑扩散） ----------
src_skin = open(os.path.join(SRC, "chen_skin.tscn"), encoding="utf-8").read()
if src_skin.count("area2d:chen") != 5:
    print(f"  ✗ chen_skin.tscn 阵营组声明异常：area2d:chen 出现 {src_skin.count('area2d:chen')} 次（应为 5）")
    print("    疑似编辑器保存误删 groups，先修复 characters/playable/chen/chen_skin.tscn 再同步")
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
        if not f.endswith(TEXT_EXT) or f.startswith("character_template"):
            continue
        p = os.path.join(root, f)
        s = open(p, encoding="utf-8").read()
        t = inject_behavior_tokens(tokenize(s), f)
        if t != s:
            open(p, "w", encoding="utf-8").write(t)
            changed += 1

# ---------- 3. 残留断言 ----------
problems = []
for root, _, files in os.walk(DST):
    for f in files:
        if not f.endswith(TEXT_EXT):
            continue
        if f.startswith("character_template"):
            continue  # 触发场景保留原样，不参与断言
        p = os.path.join(root, f)
        s = open(p, encoding="utf-8").read()
        relp = os.path.relpath(p, DST)
        if "playable/chen" in s: problems.append(f"{relp}: 残留 playable/chen")
        if re.search(r"node name=\"Chen\"", s): problems.append(f"{relp}: 残留节点名 Chen")
        if "Chen/" in s or "ChenSkin" in s: problems.append(f"{relp}: 残留 Chen 类引用")
        if "area2d:chen" in s: problems.append(f"{relp}: 残留 area2d:chen")
        if '"陈靖仇"' in s: problems.append(f"{relp}: 残留显示名")
        # 内部引用不允许再有 uid
        for m in re.finditer(r'\[ext_resource [^\]]*\]', s):
            if "playable/__NAME__/" in m.group(0) and "uid=" in m.group(0):
                problems.append(f"{relp}: 内部引用残留 uid")
                break
        for m in re.finditer(r'^\[(gd_scene|gd_resource)[^\]]*\]', s, re.M):
            if 'uid="uid://' in m.group(0):
                problems.append(f"{relp}: 文件头残留 uid")
                break
        # 占位文件自身不应引用自己的旧名
        if re.search(r'"res://[^"]*/chen[._]', s): problems.append(f"{relp}: 残留 chen_ 文件名引用")

print(f"复制 {copied} 个文件，占位符化 {changed} 个文本")
if problems:
    print("残留问题："); [print("  ✗", x) for x in problems]; sys.exit(1)

# ---------- 4. 单壳行为档正向断言（防同步工具回退丢注入） ----------
main = open(os.path.join(DST, "__NAME__.tscn"), encoding="utf-8").read()
for needle, label in [
    ('groups=["__BODY_GROUP__"]', "根节点阵营组占位"),
    ("behavior_mode = __BEHAVIOR_MODE__", "行为档属性行"),
    ("characters/__PKG__/__NAME__/", "阵营包目录占位"),
]:
    if needle not in main:
        print(f"  ✗ 主 tscn 缺注入: {label}"); sys.exit(1)
tpl_skin = open(os.path.join(DST, "__NAME___skin.tscn"), encoding="utf-8").read()
if tpl_skin.count("area2d:__NAME__") != 5:
    print(f"  ✗ 模板阵营组注入异常：area2d:__NAME__ 出现 {tpl_skin.count('area2d:__NAME__')} 次（应为 5）"); sys.exit(1)
if not os.path.exists(os.path.join(DST, "__NAME___ai.gd")):
    print("  ✗ 缺默认策略小抄 __NAME___ai.gd"); sys.exit(1)

print("断言通过：模板内已无任何 chen 身份残留（含单壳行为档注入与小抄在位检查）")
