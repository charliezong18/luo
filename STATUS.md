# STATUS — 落 (Luò)

> 跨 session 状态交接文件。每次工作 session 收工前更新（规矩见 CLAUDE.md）。

**更新于：2026-07-04**（由 Claude 根据 git history 整理初版）

## 当前状态

主线功能已完整走通，app 可用：

- ✅ Coin Ritual：物理掷币（方孔圆钱 + PBR 古铜材质 + 落定推镜），摇一摇走完整 Throw 保证公平
- ✅ 六爻起卦 → 本卦/变爻完整流程，结果页可滚动 + 再占常驻
- ✅ ZhouYiCorpus 全 64 卦（卦辞 + 384 爻辞），已订正賁卦上九
- ✅ 白话 gloss 层**全量**：64 卦辞 + 384 爻辞 + 乾坤用九/用六，AES-GCM 加密 bundle 资源（解密完整性有单测 `BaiHuaCorpusTests` 兜底）
- ✅ 占卜记录（Cast Log）：列表 + swipe 删除 + 清空
- ✅ App 图标（真渲染铜钱）、内置 Noto Serif SC、LICENSE（source-available）、首页娱乐声明

## 下一步

**待办以 [GitHub Issues](https://github.com/charliezong18/luo/issues) 为准**，此处只留索引（勾掉 = issue 已关）：

- [x] #1 语料标点统一（`ship-blocker`）— 2026-07-04 完成，通行本轻标点，49 行
- [x] #2 README 门面升级 — 2026-07-04 完成，v1 状态 + 三张截图
- [ ] #3 真机测试 + TestFlight（阻塞项：Apple Developer 会员未购）
- [ ] #4 App Store 上架准备（依赖 #3）
- [ ] #5 LLM 解读层（远期）
- [x] #6 再占后释文 toggle 不重置 — 2026-07-04 完成，一行重置

注：白话 384 爻辞 gloss 无需再做——已全量完成并在加密语料内（见上方「当前状态」）。

## 已知问题 / 坑

- 技术坑统一记在 CLAUDE.md「已知坑」一节，别重复记两处
- （暂无未修复的功能 bug 记录）

## Session 日志（最近 5 条，旧的删掉）

- 2026-07-04：白话语料改加密交付（BaiHua.enc + 密钥不入库）、git 历史重写（明文清除 + 作者邮箱统一）、LICENSE source-available、repo 转 public
- 2026-07-04：建立 CLAUDE.md + STATUS.md（第一层状态外化），无代码改动
- 2026-07-04：待办迁移至 GitHub Issues #1–#6，修正 STATUS 中"384 爻辞 gloss 待做"的过期记载（实际已全量完成）
- 2026-07-04：关闭 #1（语料标点统一为通行本轻标点，DeepSeek 重断句 + 字符硬校验 + 人工 QA；重断句工作目录 ~/luo-punct-work 可复用）+ #2（README v1 状态 + docs/screenshots/ 三张截图；截图 scaffold 用启动参数 -shot-coin/-shot-pair 临时进 RootView，已 revert，重拍照抄这招）
