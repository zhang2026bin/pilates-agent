---
name: pilates-studio
description: 读取本机「普拉提教练助手（课序引擎）」的真实数据：客户档案、课次记录、客户反馈、复测、课表、课时包、规则库。当需要基于真实客户做排课、课前 brief、续费提醒、流失复盘、教练建议时使用；只读，不写库。
---

# 普拉提教练助手（课序引擎）数据技能

## 前置

1. 本机装了 Node ≥ 22.5（内置 `node:sqlite`）。
2. 程序目录：优先读环境变量 `STUDIO_APP`；没有则默认 `D:\Downloads\普拉提`。
3. 数据库：`<STUDIO_APP>\data\studio.db`（可用 `STUDIO_DB` 覆盖）。

先用一条命令确认可用：

```powershell
node "$env:STUDIO_APP\app\agent-bridge.js" list
```

若报 `database not found` 或 `Cannot find module 'node:sqlite'`，**停止并告诉用户具体原因**，不要编造客户数据。

## 命令

```powershell
node "$app\app\agent-bridge.js" list            # 客户列表（id/化名/人群/阶段/余额/流失风险）
node "$app\app\agent-bridge.js" client <id|化名> # 档案+最近6节课+反馈+复测+未来5次排课+课时包
node "$app\app\agent-bridge.js" today           # 今天课表（含教练、客户、预约数）
node "$app\app\agent-bridge.js" week            # 未来 7 天课表
node "$app\app\agent-bridge.js" rules           # 规则库（R-SAFE-01 等 6 条）
```

输出是 JSON。`client` 返回结构：

```
client     档案（complaints/red_flags/avail_fixed 已解析）
packages   课时包（total/used/expire_on）
sessions   最近 6 节（plan/record/feedback）
retests    最近 3 次复测（conclusion/next_stage）
upcoming   未来 5 次排课
```

## 使用规则

1. **先取数再回答**：涉及具体客户、课表、复测的问题，必须先跑桥；不凭记忆。
2. **只读**：不写库、不改排课、不扣次；这些由教练在 App 里做。
3. **化名**：引用客户用「化名 #id」，不写手机号尾号、真实姓名。
4. **对齐规则库**：红旗命中只出降阶 + 转介；剂量按 R-DOSE-01；进阶/降阶按 R-PROG-01 / R-REG-01。
5. **合规词表**：对外话术只用「改善/缓解/辅助/提升/恢复」，禁「修复/矫正/治疗/康复/根治/保证」。

## 常见任务配方

**课前 60 秒 brief**
```
today → 取今天每位客户 client <id>
每人输出：今天注意什么（红旗/上次疼痛/上次 next_change）+ 一句开场话术
```

**排下一节课**
```
client <id> → 看上一节 actual/pain/fatigue/next_change + 反馈 feel/intensity + 复测 next_stage
→ 给 6–8 个动作 + 剂量，标降阶/进阶依据
```

**续费提醒**
```
client <id> → balance / expire_on / last_visit / churn_risk
→ 判断该不该提、怎么提（结合近期到课与反馈）
```

**流失复盘**
```
list → 筛 churn_risk 高或 last_visit 久 → client <id> 看断档与反馈 → 给唤醒动作
```

## 边界

- 数据只在本机，**不外传、不截图发群**。
- 不做医疗诊断；红旗按 `rules.md` 转介。
- 分享链接 token 不生成、不修改。
