# STATUS — 落 (Luò)

> 跨 session 状态交接文件。每次工作 session 收工前更新（规矩见 CLAUDE.md）。

**更新于：2026-07-04**（由 Claude 根据 git history 整理初版）

## 当前状态

主线功能已完整走通，app 可用：

- ✅ Coin Ritual：物理掷币（方孔圆钱 + PBR 古铜材质 + 落定推镜），摇一摇走完整 Throw 保证公平
- ✅ 六爻起卦 → 本卦/变爻完整流程，结果页可滚动 + 再占常驻
- ✅ ZhouYiCorpus 全 64 卦（卦辞 + 384 爻辞），已订正賁卦上九
- ✅ 白话 gloss 层：64 卦辞 + 变爻爻辞白话，AES-GCM 加密 bundle 资源
- ✅ 占卜记录（Cast Log）：列表 + swipe 删除 + 清空
- ✅ App 图标（真渲染铜钱）、内置 Noto Serif SC、LICENSE（source-available）、首页娱乐声明

## 下一步

（未定 — 等 Charlie 拍板，候选项：）

- [ ] 真机测试 + TestFlight —— 被 $99 Apple Developer 会员卡着（在购物清单里，已推迟）
- [ ] App Store 上架准备（截图、文案、隐私标注）
- [ ] 其他 feature 想法先记到这里再动手

## 已知问题 / 坑

- 技术坑统一记在 CLAUDE.md「已知坑」一节，别重复记两处
- （暂无未修复的功能 bug 记录）

## Session 日志（最近 5 条，旧的删掉）

- 2026-07-04：建立 CLAUDE.md + STATUS.md（第一层状态外化），无代码改动
