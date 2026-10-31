# STATUS — 落 (Luò)

> 跨 session 状态交接文件。每次工作 session 收工前更新（规矩见 CLAUDE.md）。

**更新于：2026-10-31**

## 当前状态

主线功能已完整走通，app 可用：

- ✅ 读经：六十四卦目录（「名称」列表 / 「卦象」8×8 查卦表）+ 经文详情（卦象线条 + 卦辞/爻辞/白话）+ 「查卦」手动输入六爻查本卦/变卦；全 app 左缘右滑返回（build 4，2026-10-31）
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
- [ ] #4 App Store 上架准备 — 2.1 已过；**8/19 收 `Guideline 4.3(b) Design-Spam`（饱和品类，条文明文点名 fortune telling）**。8/26 按「产品差异化 > 文案重定位」重做：补「读经」功能 + 元数据重定位 + build 3，详见 8/26 日志；发布方式＝手动
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

- 2026-10-31：**朋友反馈两项——侧滑返回 + 卦象视图/按卦象查，发 TestFlight build 4**。① 侧滑根因：`RootView` 原是 `@State` 切换器，首页→读经/六爻/掷币/卦例是原地换 view，根本没有导航过渡可 pop，读经列表只能点自画 chevron。改为单个 `NavigationStack`，四个入口都是真 push（`Route` 枚举；`Int` 目的地统一注册在根，读经列表/网格/查卦都推卦号）。读经/卦例记录改用系统返回键；六爻/掷币仍隐藏导航栏、保留自画 chevron（`dismiss()`），用 `InteractivePopGestureEnabler` 恢复 UIKit 在隐藏导航栏时关掉的左缘右滑（给 `interactivePopGestureRecognizer` 换一个常驻 delegate，只在 `viewControllers.count > 1` 时放行——delegate 置 nil 会在根页右滑把导航卡死，别用那招）。另加全局 `.preferredColorScheme(.dark)`，Dusk Desk 只有深色，浅色系统设置下系统返回键/标题原本会看不见。② 读经加「名称 / 卦象」分段（`@AppStorage("sutra.viewMode")` 记住）：卦象 = 8×8 查卦表，**上卦横排、下卦竖排，乾兑离震巽坎艮坤**（`HexagramGrid` 纯数据 + `HexagramGridView`；线条用 `LinesGlyph` 画形状，不再靠字体 ⚊⚋ 回退）；详情页卦象同样改线条并标「上X 下Y」。③ 「查卦」= `HexagramLookupView`（`HexagramInput` 值类型）：六行自下而上，点线换阴阳、「动」标动爻，复用 `HexagramPairView` 实时显示本卦/变卦与释文，按钮进详情；页首一句「三枚硬币掷一次定一爻，自下而上记六爻」。④ 测试：`HexagramLookupTests` 4 项（64 卦 round-trip、动爻→变卦全 384 组合、查卦表覆盖），单测 43/43；**新增 `LuoUITests` target + `LuoUI` scheme**（`xcodebuild -scheme LuoUI test`），5 项在模拟器实测左缘右滑（详情→列表→首页、六爻→首页、卦例→首页、网格/查卦→详情→回）全过；截图 `docs/screenshots/2026-10-feedback/`（UI 测试 attachment 经 `xcresulttool export attachments` 导出）。⑤ build 4：archive → export → altool validate/upload 全绿（delivery `9bac474c-aaea-47c5-b6e3-92cd0dc25d9b`），BaiHua.key 在包内；上传后 ~2 分钟 `processingState=VALID`（build id 与 delivery UUID 相同）。TestFlight：zh-Hans What to Test 已写；**Internal 组自动分发，API 显式加 build 会回 422「Cannot add internal group to a build」但 build 4 已在组内**（Internal 现含 1/2/3/4，`internalBuildState=IN_BETA_TESTING`）；外部组「朋友」加入成功（现含 1/3/4），`betaAppReviewSubmissions` 201 后 `betaReviewState=APPROVED`、`externalBuildState=BETA_APPROVED`——公开链接 HbQ93fnd 现即可装 build 4。App Store 版本 1.0 / reviewSubmissions 未碰。⑥ 环境变化：本机已是 **Xcode 27.0**，iOS 26.5 运行时与 `menxia-test` 模拟器已不在，测试用 iPhone 17 `2E90DF92-CD71-4F76-A9B9-8DE5DAEE55B1`（iOS 27.0）。
- 2026-08-26：**4.3(b) 驳回应对——补「读经」功能后重提（build 3）**。① 8/19 苹果在受理 2.1 后另开 `4.3(b) Design-Spam`；现行条文明文点名 fortune telling，唯一出口是 "meaningfully different or improved experience"。② 先做的纯元数据重定位（品类 Reference/Education、关键词描述去占卜化、新增 en-US、截图删首页图）被跨模型对抗评审推翻：app 三个入口全部通向起卦、**没有阅读功能**，「古籍阅读工具」的定位反而暴露 Guideline 2.3 元数据不实。③ 因此新增 `SutraListView` / `SutraDetailView` / `KingWenTable.allInKingWenOrder`，**「读经」置于首页首位，不起卦即可通读 64 卦全文与白话**；「再占」→「再掷」；`SutraLibraryTests` 4 项，39/39 过。④ 描述把读经段置首、删掉「不提供任何预测」（与 8/18 已交录屏矛盾）；Review Notes 从「否认桶」改为正面认领差异化；首图换成六十四卦目录。⑤ **教训：ASC 版本页的「Update Review」只是把 item 装进提交，真正送出去要在 App Review 详情页按「Resubmit to App Review」**——8/18 那次就是卡在这里空等 8 天。⑥ 另：新增 locale 必须单独补 `privacyPolicyUrl`，否则提交被拦；元数据一律走 ASC API 写（`appInfoLocalizations`/`appStoreVersionLocalizations`/`appInfos`/`appStoreReviewDetails`），别怼网页 contenteditable。
- 2026-08-18：**回复 Guideline 2.1「Information Needed」（8/14 来信）**。① 真机录屏：iPhone 16 Pro / iOS 26.6，控制中心录制 92s（1206×2622），覆盖启动→首页（娱乐声明）→六爻 6 掷→释文（卦辞+白话+变卦，本次摇出咸→豫带动爻）→占卜记录（详情编辑+左滑删除）→掷币；抽帧逐项验收通过后才发。② 回复=英文 7 项逐条（无账号/无内购/无网络/无三方 SDK；调参面板长按 1.5s 一并如实申报；语料出处与 OFL 口径与上架材料一致），在 Resolution Center **原 submission 内回复 + 挂录屏附件**——不改 app、不重传 build、不点 Cancel Submission，回复后审核自动恢复。③ 发布方式仍为 MANUAL，过审后需手动按 Release This Version；luo-review-watch（30 min 轮询）在岗，状态变化推 ntfy。回复全文存档：Resolution Center 消息串即原文。
- 2026-08-08：**付费 Apple Developer 会员到位，真机管线全线打通**（Mac mini）。① 补交 7/10 遗留改动（判面翻转 + 阳阴读数），真机实测读数正确。② Team ID **沿用 `Q8XV65MMXK` 不变** —— 个人账号 enroll 后 Personal Team 原地升级为付费 team，`project.yml` 无需改 ID，profile 有效期 7 天→**一年（2027-08-08）**。③ Release 版已装上 iPhone MKB，整趟 8/11–8/18 旅行不会过期。④ archive + export 全通，`Luo.ipa` 已产出。⑤ **补 `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`** —— `GENERATE_INFOPLIST_FILE: YES` 不生成版本号，ASC 拒收无版本号的包；**每次上传必须 bump `CURRENT_PROJECT_VERSION`**。⑥ 坑：本机 Xcode 缺 iOS 平台，报错是 `iOS 26.5 is not installed` 但 `iPhoneOS26.5.sdk` **明明在** —— 别被误导去查 SDK，就是要跑 `xcodebuild -downloadPlatform iOS`（8.5GB）。另：Xcode 运行时不刷 plist，`com.apple.dt.Xcode.plist` 里的 team 信息是**陈的**，别拿它判断账号状态，看 GUI。⑦ **`TARGETED_DEVICE_FAMILY` 写在项目级从来没生效过** —— target 级默认 `1,2` 压过项目级，`UIDeviceFamily` 一直是 `[1,2]`（通用 app），上传被 **90474**（iPad 多任务要求四个方向全给）打回。已挪进 Luo target，`UIDeviceFamily` 现为 `[1]`。⑧ ASC app 记录已建（App ID `6799511231`，名 `Luo`），API key `PF5P272XQX` / Issuer `b6d96df3-d27a-40a9-95b5-b8a94ad4e721`（`.p8` 在 `~/.appstoreconnect/private_keys/`，**不入库**）。**TestFlight 内部测试已跑通**：build 1.0 (1) 上传成功 → Ready to Submit（90 天有效）→ 内部组 `Internal`（automatic distribution 开，**建后不可改**）→ 测试员 charliezong18@gmail.com 已邀请。出口合规 Charlie 选「None of the algorithms」（只用 Apple CryptoKit，无自带实现），已固化为 `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO`，以后不再逐次询问。
- 2026-08-08（下午，接上条）：**上架材料 #4 推进，机械项清零。** ✅ 已完成：截图 4 张 6.9"（1320×2868，顺序＝铜钱／乾→姤释文／首页／掷币，6.5" 及以下由 Apple 自动缩放）｜定价免费 175 区域｜**上架区域 148，EU-27 全排除**（避开 DSA trader status ——个人开发者的住址会公开在欧盟区商店页）｜关掉 Apple Silicon Mac 上架（落靠摇一摇，Mac 无加速度计）｜App Privacy 问卷「Data Not Collected」**已 Publish**｜Privacy Policy URL + Support URL（见下）｜Copyright `2026 Hang Zong`｜审核联系方式｜build 1.0 (1) 已关联。
  **新增站点**：GitHub Pages 开在 `main` 分支 `/docs`，`charliezong18.github.io/luo/`（支持页）与 `/luo/privacy.html`（隐私政策），中英双语，配色取 DESIGN.md。隐私政策每条都对着代码核过（零网络 API／零追踪 SDK／零外部依赖／SwiftData 本地无 CloudKit／仅 NSMotion 权限）。
  **两个坑**：① `Sign-in required` 默认是**勾着**的，落无登录，不取消必被驳回。② 截图脚手架（`-shot-*` 启动参数 + `seedForScreenshot`）拍完已整块删除，**别让它进生产包**；下次要拍照抄这招：喂 `IChingRitualViewModel.appendThrow` 这个纯函数缝可以不跑物理直接摆出一卦。
  **同日稍后全部补齐**：Category＝Lifestyle（主）／Reference（次，随版本可改）｜Age Rating **4+**（7 步问卷全 NONE；第 6 步「概率类活动」查过定义——Apple 的 Simulated Gambling 指**下注博彩**，落掷币是起卦无输赢，NONE 站得住）｜Content Rights＝Yes 有必要权利（底账：《周易》原文公有领域＋出处 JSON 在库；白话是自作；**Noto Serif SC 实测 name table ID 13 为 OFL 1.1 且无 Reserved Font Name**——所以 instance 静态字重后保留 Noto 原名合规，有 RFN 就违规了；開元通寶币面是运行时程序化烘焙）｜Subtitle`周易六爻 · 铜钱物理起卦`｜Keywords 93/100（不与名称副标题重复、逗号后不留空格、掺 4 个英文词覆盖中文圈外）｜Description 537 字｜Promotional Text 61 字。
  **「Add for Review」已激活**，材料齐备，等 Charlie 按提交。⚠️ 账号级 EU trader 横幅仍在——落已排除 EU-27 理论上不拦，但**只有真按提交才验得出**。
  OFL 致谢段落已补进支持页并上线（中英双语），OFL §2 的随附许可要求有了公开落点。
  **⚡ 15:05 双线提交（Charlie 人在外面，授权代按）**：① **App Store 审核已提交**，状态 Waiting for Review，最长 48h。**提交前把发布方式从 `AFTER_APPROVAL` 改成 `MANUAL`** —— 否则会在 8/11–8/18 他失联期间自动上线、出问题无人响应。② **TestFlight 外部测试**：新建外部组「朋友」，加 build 1.0 (1)，填 Test Information（Beta 描述复用已批文案，联系方式同上，**Sign-in required 这里默认又是勾着的，再次取消**），提交 Beta App Review。③ **公开链接 https://testflight.apple.com/join/HbQ93fnd**（Open to Anyone，无人数上限）—— ⚠️ ASC 明示「Testers cannot join public link until this group has an approved build」，**Beta 审核通过后自动激活，无需再操作**。
  **EU trader 悬案已解**：横幅仍在账号页，但**不影响提交**——落排除 EU-27 后一路畅通。
  **坑（第三次遇到同一个）**：ASC 的富文本框是 `contenteditable` div，`execCommand('insertText')` 写进去 React 不认、界面仍空白；**必须走 devtools 的原生 fill**。另：`document.querySelector('[contenteditable]')` 会读到上一步残留的同类元素，**验证要靠截图不能靠 DOM 读数**。
