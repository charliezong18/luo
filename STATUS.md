# STATUS — 落 (Luò)

> 跨 session 状态交接文件。每次工作 session 收工前更新（规矩见 CLAUDE.md）。

**更新于：2026-08-08**

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
- [x] #3 真机测试 + TestFlight — 2026-08-08 完成。真机装机 + TestFlight 内部测试全通
- [ ] #4 App Store 上架准备 — **材料已全部填完，「Add for Review」已激活，等 Charlie 按提交**（详见下方 8/8 日志）
- [ ] #5 LLM 解读层（远期）
- [x] #6 再占后释文 toggle 不重置 — 2026-07-04 完成，一行重置
- [x] #7 首次进 Ritual 卡 5 秒+（真机首测发现）— 2026-07-05 完成，贴图 static 缓存 + 启动预热
- [x] #8 摇一摇手感分级（轻抖=颤 / 甩=高抛）— 2026-07-05 完成，常量待真机回归调感
- [x] #9 斜靠币判面不可信 — 2026-07-05 完成，平整度检查 + 自动重掷

注：白话 384 爻辞 gloss 无需再做——已全量完成并在加密语料内（见上方「当前状态」）。

## 已知问题 / 坑

- 技术坑统一记在 CLAUDE.md「已知坑」一节，别重复记两处
- （暂无未修复的功能 bug 记录）

## Session 日志（最近 5 条，旧的删掉）

- 2026-08-08：**付费 Apple Developer 会员到位，真机管线全线打通**（Mac mini）。① 补交 7/10 遗留改动（判面翻转 + 阳阴读数），真机实测读数正确。② Team ID **沿用 `Q8XV65MMXK` 不变** —— 个人账号 enroll 后 Personal Team 原地升级为付费 team，`project.yml` 无需改 ID，profile 有效期 7 天→**一年（2027-08-08）**。③ Release 版已装上 iPhone MKB，整趟 8/11–8/18 旅行不会过期。④ archive + export 全通，`Luo.ipa` 已产出。⑤ **补 `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`** —— `GENERATE_INFOPLIST_FILE: YES` 不生成版本号，ASC 拒收无版本号的包；**每次上传必须 bump `CURRENT_PROJECT_VERSION`**。⑥ 坑：本机 Xcode 缺 iOS 平台，报错是 `iOS 26.5 is not installed` 但 `iPhoneOS26.5.sdk` **明明在** —— 别被误导去查 SDK，就是要跑 `xcodebuild -downloadPlatform iOS`（8.5GB）。另：Xcode 运行时不刷 plist，`com.apple.dt.Xcode.plist` 里的 team 信息是**陈的**，别拿它判断账号状态，看 GUI。⑦ **`TARGETED_DEVICE_FAMILY` 写在项目级从来没生效过** —— target 级默认 `1,2` 压过项目级，`UIDeviceFamily` 一直是 `[1,2]`（通用 app），上传被 **90474**（iPad 多任务要求四个方向全给）打回。已挪进 Luo target，`UIDeviceFamily` 现为 `[1]`。⑧ ASC app 记录已建（App ID `6799511231`，名 `Luo`），API key `PF5P272XQX` / Issuer `b6d96df3-d27a-40a9-95b5-b8a94ad4e721`（`.p8` 在 `~/.appstoreconnect/private_keys/`，**不入库**）。**TestFlight 内部测试已跑通**：build 1.0 (1) 上传成功 → Ready to Submit（90 天有效）→ 内部组 `Internal`（automatic distribution 开，**建后不可改**）→ 测试员 charliezong18@gmail.com 已邀请。出口合规 Charlie 选「None of the algorithms」（只用 Apple CryptoKit，无自带实现），已固化为 `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO`，以后不再逐次询问。
- 2026-08-08（下午，接上条）：**上架材料 #4 推进，机械项清零。** ✅ 已完成：截图 4 张 6.9"（1320×2868，顺序＝铜钱／乾→姤释文／首页／掷币，6.5" 及以下由 Apple 自动缩放）｜定价免费 175 区域｜**上架区域 148，EU-27 全排除**（避开 DSA trader status ——个人开发者的住址会公开在欧盟区商店页）｜关掉 Apple Silicon Mac 上架（落靠摇一摇，Mac 无加速度计）｜App Privacy 问卷「Data Not Collected」**已 Publish**｜Privacy Policy URL + Support URL（见下）｜Copyright `2026 Hang Zong`｜审核联系方式｜build 1.0 (1) 已关联。
  **新增站点**：GitHub Pages 开在 `main` 分支 `/docs`，`charliezong18.github.io/luo/`（支持页）与 `/luo/privacy.html`（隐私政策），中英双语，配色取 DESIGN.md。隐私政策每条都对着代码核过（零网络 API／零追踪 SDK／零外部依赖／SwiftData 本地无 CloudKit／仅 NSMotion 权限）。
  **两个坑**：① `Sign-in required` 默认是**勾着**的，落无登录，不取消必被驳回。② 截图脚手架（`-shot-*` 启动参数 + `seedForScreenshot`）拍完已整块删除，**别让它进生产包**；下次要拍照抄这招：喂 `IChingRitualViewModel.appendThrow` 这个纯函数缝可以不跑物理直接摆出一卦。
  **同日稍后全部补齐**：Category＝Lifestyle（主）／Reference（次，随版本可改）｜Age Rating **4+**（7 步问卷全 NONE；第 6 步「概率类活动」查过定义——Apple 的 Simulated Gambling 指**下注博彩**，落掷币是起卦无输赢，NONE 站得住）｜Content Rights＝Yes 有必要权利（底账：《周易》原文公有领域＋出处 JSON 在库；白话是自作；**Noto Serif SC 实测 name table ID 13 为 OFL 1.1 且无 Reserved Font Name**——所以 instance 静态字重后保留 Noto 原名合规，有 RFN 就违规了；開元通寶币面是运行时程序化烘焙）｜Subtitle`周易六爻 · 铜钱物理起卦`｜Keywords 93/100（不与名称副标题重复、逗号后不留空格、掺 4 个英文词覆盖中文圈外）｜Description 537 字｜Promotional Text 61 字。
  **「Add for Review」已激活**，材料齐备，等 Charlie 按提交。⚠️ 账号级 EU trader 横幅仍在——落已排除 EU-27 理论上不拦，但**只有真按提交才验得出**。
  **未了**：`docs/index*.html` 的 OFL 致谢段落已写好但**未 push**（等 Charlie 过文案）；OFL 第 2 条要求随附许可证，目前仅存于 ttf name table。
- 2026-07-10：朋友试用反馈「硬币正反不明显」→ 不动贴图，改 UI 读数：六爻落定后 hint 下显示本掷「阳 阳 阴」+ 爻堆每爻带三枚小字记录（castFaces 存进 VM，两处 View 显示）。顺带修出一个正反颠倒 bug：`PhysicsScene.face(of:)` 原来把字面朝上读成 heads/阳，与传统三钱法（**背为阳、字为阴**，Yao.swift 注释本来就这么写）相反，已翻转判定并订正相关注释。历史考证：开元通宝真钱背面就是光背，现有两面贴图无需改。截图 scaffold（-shot-tally）已 revert。
- 2026-07-05：**首次真机运行成功**（免费 Personal Team 侧载，MacBook + iPhone"MKB"）。首测三反馈当晚修毕（#7 贴图缓存/预热、#8 摇一摇分级+多记一爻门闩、#9 斜靠重掷）。摇感常量（castMagnitude 2.4g、nudge 强度、vigor 封顶 1.8×）在 MotionService/PhysicsScene，待 Charlie 真机回归再调。

- 2026-07-04：白话语料改加密交付（BaiHua.enc + 密钥不入库）、git 历史重写（明文清除 + 作者邮箱统一）、LICENSE source-available、repo 转 public
- 2026-07-04：建立 CLAUDE.md + STATUS.md（第一层状态外化），无代码改动
- 2026-07-04：待办迁移至 GitHub Issues #1–#6，修正 STATUS 中"384 爻辞 gloss 待做"的过期记载（实际已全量完成）
- 2026-07-04：关闭 #1（语料标点统一为通行本轻标点，DeepSeek 重断句 + 字符硬校验 + 人工 QA；重断句工作目录 ~/luo-punct-work 可复用）+ #2（README v1 状态 + docs/screenshots/ 三张截图；截图 scaffold 用启动参数 -shot-coin/-shot-pair 临时进 RootView，已 revert，重拍照抄这招）
