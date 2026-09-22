#!/usr/bin/env bash
## =============================================================================
## run_matrix.sh —— 回归矩阵通跑编排器（S2-M1-B2.5 测试主权批）
##
## 名册规则（AGENTS.md「关卡装配」段权威）：**名册以 tools/ 下实存 runner 为准**。
## 本脚本内嵌 22 套 / 23 跑名册（validator 双模=2 跑），与 AGENTS 收口一致；
## 新增/删除套件须同批改本脚本 + AGENTS 名册。spike 类（dialogic_spike /
## container_prototype）故意不入册。
##
## 生命周期铁律（不可协商，Task1 评审 R5 定档）：
##   1. `--import` 退出码非 0 → **致命终止**（绝不带着半导入缓存跑测试）。
##   2. 全套顺序 = **destroy 先行 → ensure(期望 42) → import → ensure(期望 0)
##      → 逐套 → 末销毁（--only 除外）**。destroy 先行破"永久 42 死锁"
##      （目录在但门控 png 缺 → 创建器拒覆写 → import 也造不出 sidecar）。
##   3. 每套 `timeout 300` 守卫；rc=124 记红并标 TIMEOUT。
##   4. 末行汇总表（名/rc/PASS 行 grep），退出码 = 红套数。
##
## 用法：
##   tools/matrix_runner/run_matrix.sh                 # 全套通跑（含末销毁）
##   tools/matrix_runner/run_matrix.sh --only 子串     # 只跑名含子串的套；跳过末销毁
## =============================================================================
set -u

GODOT="${GODOT:-godot}"
TIMEOUT_SECS=300
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_ROOT="/tmp/opencode/matrix/${STAMP}"
ENSURE_ENTRY="tools/matrix_runner/test_actor_ensure.gd"
DESTROY_ENTRY="tools/matrix_runner/test_actor_destroy.gd"

# ── 22 套名册（23 跑）：kind|标签|res 路径 ────────────────────────────────────
# kind: scene=直接跑场景；script=-s 脚本；validator=脚本双模（默认+fixtures）。
ROSTER=(
	"scene|attack_freeze_repro|tools/attack_freeze_repro/repro.tscn"
	"scene|conductor_test|tools/conductor_test/conductor_test.tscn"
	"scene|container_contract|tools/container_contract/container_contract.tscn"
	"scene|debug_dock_test|tools/debug_dock_test/dock_test.tscn"
	"scene|dock_wheel_test|tools/dock_wheel_test/wheel_test.tscn"
	"scene|hud_test|tools/hud_test/hud_test.tscn"
	"scene|input_channel_test|tools/input_channel_test/test_runner.tscn"
	"scene|interact_contract|tools/interact_contract/interact_contract.tscn"
	"scene|knockout_contract|tools/knockout_contract/knockout_contract.tscn"
	"scene|spell_cast_test|tools/spell_cast_test/cast_contract.tscn"
	"scene|spell_hit_test|tools/spell_hit_test/projectile_hit.tscn"
	"scene|stage_contract|tools/stage_contract/stage_contract.tscn"
	"scene|tree_connectivity_test|tools/tree_connectivity_test/connectivity.tscn"
	"scene|wp2_creation_test|tools/wp2_creation_test/overlay_e2e.tscn"
	"scene|wp3_formal|tools/wp3_formal/verify.tscn"
	"scene|attack_lane_contract|tools/attack_lane_contract/attack_lane_contract.tscn"
	"script|blend_domain|tools/blend_domain_test/project_test.gd"
	"script|contour_sort|tools/contour_sort_test/trace_sort.gd"
	"script|editor_scripts_check|tools/editor_scripts_check/check.gd"
	"script|spell_creation|tools/spell_creation_test/test_spell_creation.gd"
	"script|test_scene_parity|tools/test_scene_parity/parity.gd"
	"validator|stage_validator|tools/stage_validator/validator.gd"
)

# 颜色（仅 tty 时上色，日志文件里留纯文本判读方便 grep）
if [ -t 1 ]; then C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_RST=$'\033[0m'
else C_RED=""; C_GRN=""; C_YEL=""; C_RST=""; fi

## 跑一次 kit 的 -s 入口，回显其 stdout，把退出码经全局 RC 带回。
run_kit() {
	local entry="$1"
	local out
	out="$("$GODOT" --headless --path "${REPO_ROOT}" -s "${entry}" 2>&1)"
	RC=$?
	echo "${out}"
}

## 主生命周期（ensure 三态 + import）。失败非零退出。$1=only 时的日志子目录名。
lifecycle_ensure() {
	mkdir -p "${LOG_ROOT}"
	echo "== [1/3] destroy 先行（破永久 42 死锁） =="
	run_kit "${DESTROY_ENTRY}"
	if [ "${RC}" -ne 0 ]; then
		echo "${C_RED}FATAL: destroy 先行失败 rc=${RC}${C_RST}" >&2; exit 3
	fi

	echo "== [2/3] ensure（期望 42 = 已创建待导入） =="
	run_kit "${ENSURE_ENTRY}"
	if [ "${RC}" -ne 42 ]; then
		echo "${C_RED}FATAL: ensure 期望 42，实得 ${RC}${C_RST}" >&2; exit 4
	fi

	echo "== [3/3] godot --headless --import =="
	if ! "${GODOT}" --headless --path "${REPO_ROOT}" --import \
			>"${LOG_ROOT}/import.log" 2>&1; then
		local irc=$?
		echo "${C_RED}FATAL: --import 退出码 ${irc}!=0（半导入窗口，拒绝续跑）${C_RST}" >&2
		tail -n 15 "${LOG_ROOT}/import.log" >&2
		exit 5
	fi

	echo "== ensure（期望 0 = 就绪） =="
	run_kit "${ENSURE_ENTRY}"
	if [ "${RC}" -ne 0 ]; then
		echo "${C_RED}FATAL: import 后 ensure 期望 0，实得 ${RC}${C_RST}" >&2; exit 6
	fi
	echo "${C_GRN}test_actor 就绪${C_RST}"
}

## 跑单套：$1=kind $2=label $3=res 路径（validator 的 fixtures 跑另见主循环）。
## 结果写全局 LAST_RC / LAST_PASS_LINE。日志 tee 进 LOG_ROOT。
run_suite() {
	local kind="$1" label="$2" path="$3" extra="${4:-}"
	local logfile="${LOG_ROOT}/${label}${extra:+_fixtures}.log"
	local -a cmd
	if [ "${kind}" = "script" ] || [ "${kind}" = "validator" ]; then
		# house 惯例：-s 走相对路径（各套头注 "运行：godot --headless --path . -s tools/..." 同源）
		cmd=("${GODOT}" --headless --path "${REPO_ROOT}" -s "${path}")
	else
		# 场景套件走 res:// 直跑（interact_contract 等头注同源惯例）
		cmd=("${GODOT}" --headless --path "${REPO_ROOT}" "res://${path}")
	fi
	[ -n "${extra}" ] && cmd+=("--" "${extra}")

	echo "---- 跑 ${label}${extra:+ (${extra})} ----"
	# timeout 守卫；124=超时。PIPESTATUS[0] 取 timeout 退出码（非 tee 的）。
	timeout "${TIMEOUT_SECS}" "${cmd[@]}" 2>&1 | tee "${logfile}"
	local rc="${PIPESTATUS[0]}"
	LAST_RC="${rc}"
	# 提取末个含 PASS/FAIL 的汇总行（各套形如 "════ ... : PASS ════"）
	LAST_PASS_LINE="$(grep -aE 'PASS|FAIL' "${logfile}" | tail -n 1 || true)"
}

# ── 参数解析 ──────────────────────────────────────────────────────────────────
ONLY=""
while [ $# -gt 0 ]; do
	case "$1" in
		--only) ONLY="${2:-}"; shift 2 ;;
		--only=*) ONLY="${1#--only=}"; shift ;;
		-h|--help) sed -n '2,26p' "${BASH_SOURCE[0]}"; exit 0 ;;
		*) echo "未知参数：$1（--only 子串 | --help）" >&2; exit 2 ;;
	esac
done

cd "${REPO_ROOT}" || { echo "无法进入 ${REPO_ROOT}" >&2; exit 2; }

# 生命周期：全跑与 --only 都先建好 test_actor（--only 末不销毁）。
lifecycle_ensure

# ── 逐套执行，收集 (label|rc|passline) ────────────────────────────────────────
RESULTS=()
RED=0
for row in "${ROSTER[@]}"; do
	IFS='|' read -r kind label path <<< "${row}"

	if [ "${kind}" = "validator" ]; then
		runs=( "" "--fixtures" )
	else
		runs=( "" )
	fi

	for extra in "${runs[@]}"; do
		tag="${label}"
		[ -n "${extra}" ] && tag="${label}:fixtures"
		# --only 过滤：标签须含子串
		if [ -n "${ONLY}" ] && [[ "${tag}" != *"${ONLY}"* ]]; then
			continue
		fi
		run_suite "${kind}" "${label}" "${path}" "${extra}"
		rc="${LAST_RC}"
		verdict="${C_GRN}PASS${C_RST}"
		if [ "${rc}" -eq 124 ]; then
			verdict="${C_RED}TIMEOUT${C_RST}"; RED=$((RED + 1))
		elif [ "${rc}" -ne 0 ]; then
			verdict="${C_RED}RED${C_RST}"; RED=$((RED + 1))
		fi
		printf '%s %-28s rc=%-3s %s  %s\n' \
			"${C_YEL}=>${C_RST}" "${tag}" "${rc}" "${verdict}" "${LAST_PASS_LINE}"
		RESULTS+=("${tag}|${rc}|${LAST_PASS_LINE}")
	done
done

# ── 末销毁（--only 跳过，保留 test_actor 供下次强制重建）──────────────────────
if [ -n "${ONLY}" ]; then
	echo
	echo "${C_YEL}--only 模式：test_actor 残留中，下次通跑将强制重建（destroy 先行）${C_RST}"
else
	echo "== 末销毁 test_actor =="
	run_kit "${DESTROY_ENTRY}"
	[ "${RC}" -ne 0 ] && echo "${C_YEL}警告：末销毁 rc=${RC}（不改变汇总判定）${C_RST}"
fi

# ── 汇总表 ────────────────────────────────────────────────────────────────────
echo
echo "══════════════════ 矩阵汇总（${STAMP}）══════════════════"
printf '%-30s %-4s %s\n' "套件" "RC" "PASS 行"
for r in "${RESULTS[@]}"; do
	IFS='|' read -r tag rc passline <<< "${r}"
	printf '%-30s %-4s %s\n' "${tag}" "${rc}" "${passline}"
done
echo "═════════════════════════════════════════════════════════"
echo "红套数：${RED}   日志目录：${LOG_ROOT}"
exit "${RED}"
