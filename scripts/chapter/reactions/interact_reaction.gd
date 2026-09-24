class_name InteractReaction
extends Node

## 反应件申报基类（S2-B4，spec §3 门三）：互动反应件的账本义务载体——
## "什么该记住"不由账本猜、也不靠文档约定，由每件反应件**显式申报**成数据。
## X 流静态清点（T3 在册）抓两案：①reactions/ 下每个 class_name 件必须实存
## save_claim 覆写；②申报名册自动汇总=判项表报表（spec §2.1：文档是报表不是公约）。
##
## save_claim() 申报单三列语义：
## 　· 第一列·账本键所属 namespace（persists/resets 数组里的每个元素都是
## 　　GameSave 的 ns，如 spells_known/chests——户名即口径，不申报文件路径）；
## 　· persists=入册户——本件写入的账在"重演/回跳/换章"下必须**保持不变**
## 　　（宝箱不再吐宝、秘籍不再重学，spec §2"重演一遍玩家不能接受"的那类）；
## 　· resets=豁免户——本件依赖的可重导状态**不入册**、重演必须归零
## 　　（段内敌人=场景自带、血量=满状态规则推导，四门重演等价腿据此反向
## 　　断言"必须重置"，忘申报的持久态在第二遍必然分叉）。
##
## 基类默认实现=响亮红（push_error+空单）：子类忘记申报不会静默滑过。

## 申报单本体（子类必须覆写；返回 {&"persists": [ns...], &"resets": [ns...]}）
func save_claim() -> Dictionary:
	push_error("InteractReaction: 子类 %s 必须申报 save_claim()（spec §3 门三，申报即入册）"
			% str(get_script()))
	return {}
