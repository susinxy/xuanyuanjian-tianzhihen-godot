#!/bin/bash
#
# 创建新角色的自动化脚本
# 
# 用法: ./create_character.sh <角色英文名> <角色PascalCase名> <角色中文名>
# 例子: ./create_character.sh yu_xiaoxue YuXiaoxue 于小雪
#
# 必须在项目根目录运行：
#   cd xuanyuan-sword
#   ./characters/playable/_template/create_character.sh yu_xiaoxue YuXiaoxue 于小雪
#
# 角色英文名规范:
#   - 小写 + 下划线（snake_case）
#   - 如: chen_jingchou, yu_xiaoxue, tuoba_yuer
#
# 角色 PascalCase 名规范:
#   - 首字母大写驼峰
#   - 如: ChenJingchou, YuXiaoxue, TuobaYuer
#

set -e  # 出错即退出

TEMPLATE_DIR="characters/playable/_template"
CHARACTERS_DIR="characters/playable"

# 参数检查
if [ "$#" -ne 3 ]; then
    echo "用法: $0 <角色英文名> <角色PascalCase> <角色中文名>"
    echo ""
    echo "必须在项目根目录运行："
    echo "  cd xuanyuan-sword"
    echo "  ./characters/playable/_template/create_character.sh yu_xiaoxue YuXiaoxue 于小雪"
    echo ""
    echo "例子:"
    echo "  $0 yu_xiaoxue YuXiaoxue 于小雪"
    echo "  $0 tuoba_yuer TuobaYuer 拓跋玉儿"
    exit 1
fi

CHAR_NAME="$1"       # snake_case: yu_xiaoxue
CLASS_NAME="$2"      # PascalCase: YuXiaoxue
DISPLAY_NAME="$3"    # 中文名: 于小雪

TARGET_DIR="${CHARACTERS_DIR}/${CHAR_NAME}"

echo "=========================================="
echo "创建新角色: ${DISPLAY_NAME}"
echo "=========================================="
echo "角色英文名:    ${CHAR_NAME}"
echo "PascalCase 名: ${CLASS_NAME}"
echo "目标目录:      ${TARGET_DIR}"
echo ""

# 检查当前目录是否是项目根（必须有 project.godot）
if [ ! -f "project.godot" ]; then
    echo "错误: 必须在项目根目录运行（当前目录找不到 project.godot）"
    echo "请先 cd 到 xuanyuan-sword 再运行本脚本"
    exit 1
fi

# 检查模板目录
if [ ! -d "${TEMPLATE_DIR}" ]; then
    echo "错误: 找不到模板目录 ${TEMPLATE_DIR}"
    exit 1
fi

# 检查目标目录是否已存在
if [ -d "${TARGET_DIR}" ]; then
    echo "错误: 目录 ${TARGET_DIR} 已存在"
    exit 1
fi

echo "[步骤 1/4] 复制模板目录..."
cp -r "${TEMPLATE_DIR}" "${TARGET_DIR}"

# 删除模板专用文件（脚本和说明文件不应出现在新角色目录）
rm -f "${TARGET_DIR}/create_character.sh"
rm -f "${TARGET_DIR}/README.md"

echo "[步骤 2/4] 重命名文件..."
# 按特定顺序重命名（先处理带后缀的，避免子串冲突）
if [ -f "${TARGET_DIR}/__NAME___skin.tscn" ]; then
    mv "${TARGET_DIR}/__NAME___skin.tscn" "${TARGET_DIR}/${CHAR_NAME}_skin.tscn"
fi
if [ -f "${TARGET_DIR}/__NAME___skin.gd" ]; then
    mv "${TARGET_DIR}/__NAME___skin.gd" "${TARGET_DIR}/${CHAR_NAME}_skin.gd"
fi
if [ -f "${TARGET_DIR}/__NAME__.tscn" ]; then
    mv "${TARGET_DIR}/__NAME__.tscn" "${TARGET_DIR}/${CHAR_NAME}.tscn"
fi
if [ -f "${TARGET_DIR}/__NAME__.gd" ]; then
    mv "${TARGET_DIR}/__NAME__.gd" "${TARGET_DIR}/${CHAR_NAME}.gd"
fi

# 资源文件重命名
if [ -f "${TARGET_DIR}/resources/anim_library___NAME__.tres" ]; then
    mv "${TARGET_DIR}/resources/anim_library___NAME__.tres" "${TARGET_DIR}/resources/anim_library_${CHAR_NAME}.tres"
fi
if [ -f "${TARGET_DIR}/resources/__NAME___attributes.tres" ]; then
    mv "${TARGET_DIR}/resources/__NAME___attributes.tres" "${TARGET_DIR}/resources/${CHAR_NAME}_attributes.tres"
fi
if [ -f "${TARGET_DIR}/resources/__NAME___gradient.tres" ]; then
    mv "${TARGET_DIR}/resources/__NAME___gradient.tres" "${TARGET_DIR}/resources/${CHAR_NAME}_gradient.tres"
fi
if [ -f "${TARGET_DIR}/resources/spriteframes___NAME__.tres" ]; then
    mv "${TARGET_DIR}/resources/spriteframes___NAME__.tres" "${TARGET_DIR}/resources/spriteframes_${CHAR_NAME}.tres"
fi
if [ -f "${TARGET_DIR}/resources/sprites/__NAME___profile.png" ]; then
    mv "${TARGET_DIR}/resources/sprites/__NAME___profile.png" "${TARGET_DIR}/resources/sprites/${CHAR_NAME}_profile.png"
fi

echo "[步骤 3/4] 替换文件内容..."
find "${TARGET_DIR}" -type f \( -name "*.tres" -o -name "*.tscn" -o -name "*.gd" \) \
    -exec sed -i "s/__NAME__/${CHAR_NAME}/g" {} + \
    -exec sed -i "s/__CLASS__/${CLASS_NAME}/g" {} + \
    -exec sed -i "s/__DISPLAY_NAME__/${DISPLAY_NAME}/g" {} +

echo "[步骤 4/4] 清理缓存文件..."
find "${TARGET_DIR}" -name "*.uid" -delete
find "${TARGET_DIR}" -name "*.import" -delete

echo ""
echo "=========================================="
echo "角色创建完成！"
echo "=========================================="
echo "新目录: ${TARGET_DIR}"
echo ""
echo "下一步操作:"
echo "  1. 删除 uid 缓存: rm .godot/uid_cache.bin"
echo "  2. 重启 Godot 编辑器"
echo "  3. 打开 ${TARGET_DIR}/${CHAR_NAME}.tscn 验证加载"
echo "  4. 替换 sprite 图片（resources/sprites/ 目录）"
echo "  5. 调整角色属性（resources/${CHAR_NAME}_attributes.tres）"
echo "  6. 调整攻击数据（resources/attacks/ 目录）"
echo ""
echo "详细指南请阅读: ${TEMPLATE_DIR}/README.md"
