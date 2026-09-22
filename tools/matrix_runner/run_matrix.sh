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
##   5. 通道见证（M4）：消费 test_actor 的套须在日志里喊出身份断言标记
##      （下表 ATTEST），标记缺席 = 该跑记红——封死"导入门退化→NOTICE 静默
##      跳身份腿→绿矩阵"的家族路径。
##
## 用法：
##   tools/matrix_runner/run_matrix.sh                 # 全套通跑（含末销毁）
##   tools/matrix_runner/run_matrix.sh --only 子串     # 只跑名含子串的套；跳过末销毁
##   tools/matrix_runner/run_matrix.sh --ensure-only   # 只走生命周期建好替身即退
##                                                     # （消费套头部红字的处方通道）
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

# ── 通道见证表（M4）：label|身份断言标记 ──────────────────────────────────────
# 消费 test_actor 的套必须在日志里喊出该标记（身份腿真跑了的证据）；标记缺席
# 且该套本次有跑 = 记红（红因：导入门退化 → NOTICE 静默跳身份腿 → 假绿矩阵）。
# T4 主权迁移批：所有"只需要一个身体"的直载套迁入 test_actor 后统一以
# ACTOR-GATE（三态守卫通过行）入表——封死"守卫被绕过/替身未真就绪仍绿"。
# T5 接缝批起支持**同套多行**（每行一个标记，全部必须在日志在场）。
ATTEST=(
	"interact_contract|S1a "
	"interact_contract|SEAM-GATE"
	"input_channel_test|ACTOR-GATE"
	"attack_freeze_repro|ACTOR-GATE"
	"conductor_test|ACTOR-GATE"
	"hud_test|ACTOR-GATE"
	"spell_cast_test|ACTOR-GATE"
	"tree_connectivity_test|ACTOR-GATE"
	"wp2_creation_test|ACTOR-GATE"
	"wp3_formal|ACTOR-GATE"
	"attack_lane_contract|ACTOR-GATE"
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
	# M1 修正（Task2 评审）：`if !` 之后再取 $? 恒为 0（取到的是取反后的判定），
	# 必须先直跑命令、紧跟捕获 irc，再判非 0。
	"${GODOT}" --headless --path "${REPO_ROOT}" --import \
			>"${LOG_ROOT}/import.log" 2>&1
	local irc=$?
	if [ "${irc}" -ne 0 ]; then
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
MODE="full"
while [ $# -gt 0 ]; do
	case "$1" in
		--only)
			# M2 修正（Task2 评审）：裸 `--only`（尾参缺失）时 shift 2 失败、
			# $@ 不变 → 死循环。必须先验剩余参数充足且不是另一个选项。
			if [ $# -lt 2 ] || [ -z "$2" ] || [[ "$2" = --* ]]; then
				echo "错误：--only 需要名册子串参数（--only <套件名子串>）" >&2
				exit 2
			fi
			ONLY="$2"; shift 2 ;;
		--only=*)
			ONLY="${1#--only=}"
			if [ -z "${ONLY}" ]; then
				echo "错误：--only= 的子串不能为空" >&2
				exit 2
			fi
			shift ;;
		--ensure-only) MODE="ensure"; shift ;;
		-h|--help) sed -n '/^## =====/,/^## =====/p' "${BASH_SOURCE[0]}"; exit 0 ;;
		*) echo "未知参数：$1（--only 子串 | --ensure-only | --help）" >&2; exit 2 ;;
	esac
done

cd "${REPO_ROOT}" || { echo "无法进入 ${REPO_ROOT}" >&2; exit 2; }

# 生命周期：全跑 / --only / --ensure-only 都先建好 test_actor。
lifecycle_ensure

if [ "${MODE}" = "ensure" ]; then
	echo "${C_GRN}--ensure-only：test_actor 已就绪（未跑名册，供消费套单跑使用）${C_RST}"
	exit 0
fi

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
		# M4 见证（Task2 评审）：表内套 rc=0 但日志没喊出身份标记 = 身份腿被
		# 门控静默跳过（NOTICE 家族假绿），本次跑同样记红。rc 已红则不叠加。
		markers=()
		for a in "${ATTEST[@]}"; do
			IFS='|' read -r alabel amarker <<< "${a}"
			[ "${alabel}" = "${label}" ] && markers+=("${amarker}")
		done
		# T5 起一可多标记：任一缺席都记红（${markers[@]:-} 兼容 set -u 空数组）
		for marker in "${markers[@]:-}"; do
			[ -z "${marker}" ] && continue
			if [ "${rc}" -eq 0 ] \
					&& ! grep -qa -- "${marker}" "${LOG_ROOT}/${label}${extra:+_fixtures}.log"; then
				verdict="${C_RED}RED(M4 见证标记「${marker%% *}」缺席)${C_RST}"; RED=$((RED + 1))
			fi
		done
		printf '%s %-28s rc=%-3s %s  %s\n' \
			"${C_YEL}=>${C_RST}" "${tag}" "${rc}" "${verdict}" "${LAST_PASS_LINE}"
		RESULTS+=("${tag}|${rc}|${LAST_PASS_LINE}")
	done
done

# M3 修正（Task2 评审）：--only 子串零命中时 RESULTS 为空、旧版会静默 exit 0
# ——拼错名册标签等于"假装跑完"。必须 FATAL 并列出可用标签。
if [ -n "${ONLY}" ] && [ "${#RESULTS[@]}" -eq 0 ]; then
	echo "${C_RED}FATAL: --only「${ONLY}」未命中任何套件（本次零执行，判定不可信）${C_RST}" >&2
	echo "可用标签：" >&2
	for row in "${ROSTER[@]}"; do
		IFS='|' read -r _k _label _p <<< "${row}"
		echo "  ${_label}" >&2
	done
	exit 7
fi

# ── 末销毁（--only 跳过；M5：残留文案以盘上实况为准，不再口头断言）──────────
if [ -n "${ONLY}" ]; then
	echo
	if [ -d "${REPO_ROOT}/characters/playable/test_actor" ]; then
		echo "${C_YEL}--only 模式：test_actor 仍驻留（消费套只读不销毁，属预期），下次通跑 destroy 先行强制重建${C_RST}"
	else
		echo "${C_YEL}--only 模式：test_actor 未驻留（异常形态——通跑生命周期建好的替身被本次执行弄丢，查上行消费套日志），下次通跑将重建${C_RST}"
	fi
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
