# 落 (Luò)

> 🌐 **中文** · [English](README.en.md)

原生 iOS 卜筮应用 —— 物理级 Ritual(铜钱、六爻,后续 Dice / 塔罗 / 签筒)。设计的单一事实来源(SSOT)在 2nd Brain vault:`Hang/Plans/Divination_App/`(CONTEXT.md + ADR 0001–0009)。

## 视觉身份 —— `DESIGN.md`

视觉系统用 Google 的 [design.md](https://github.com/google-labs-code/design.md) 格式描述(`@google/design.md` —— YAML 设计 token + 散文式理念)。共两个变体,字体/间距/形状完全一致(都从 ADR 推导而来),只在配色上不同:

| 文件 | 变体 | 状态 |
|---|---|---|
| `DESIGN.md` | **Dusk Desk(暮案)** —— 暖近黑桌面、旧纸墨字、唯一朱砂强调色 | **当前默认**(与暗色 SceneKit 场景一致) |
| `DESIGN-paper.md` | **Rice Paper(宣纸)** —— 暖宣纸米白、研磨墨字、深朱砂印 | 备选,parked |

暗/浅之选**有意推迟到 Phase 2**(真机、上手判断)。两份都干净通过 `npx @google/design.md lint <file>`。改任何 token 前先用 lint CLI 校验。中文阅读版:`DESIGN.zh.md` / `DESIGN-paper.zh.md`(token 以英文版为准)。

## 当前状态 —— Phase 0/1 staging

依 [ADR-0007](../../Library/CloudStorage/GoogleDrive-charliezong18@gmail.com/My%20Drive/2nd%20Brain/Hang/Plans/Divination_App/docs/adr/0007-build-cadence-coin-harness-then-iching.md),第一个要造的是 *Coin Harness* —— 一个故意做得很丑的 SceneKit + CoreMotion + CoreHaptics 装置,用来在单枚铜钱原型上调 Settle 的手感。Harness 是一次性的;只有收敛后的物理常数会进入 v1。

Harness 的 Swift 源码已预置在 `Luo/`:

| 文件 | 职责 |
|---|---|
| `LuoApp.swift` | `@main` SwiftUI App 入口 |
| `HarnessView.swift` | 顶层 SceneView、Settle 指示器、Throw / Reset / Shake 控件、滑块列表 |
| `CoinHarnessScene.swift` | SceneKit 场景:单枚铜钱 + 桌面 + Settle 检测器 |
| `PhysicsParams.swift` | 所有可调旋钮的 Observable 模型 |
| `MotionService.swift` | CoreMotion 封装,持续加速度的摇晃触发 |
| `HapticsService.swift` | CoreHaptics 封装,settle 闷响 + 翻滚 tick |

## 配置 —— XcodeGen

Xcode 工程由 `project.yml` 经 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成 —— 不手工提交 `.xcodeproj`,随时可重新生成。源码在 `Luo/`。

```bash
brew install xcodegen        # 一次性(Mac mini 上已装)
cd ~/Developer/luo
xcodegen generate            # 由 project.yml 生成 Luo.xcodeproj
open Luo.xcodeproj           # 然后 ⌘R
```

命令行构建 + 验证(无签名,模拟器):

```bash
xcodebuild -project Luo.xcodeproj -scheme Luo \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

- 最低部署 **iOS 17**(Phase 2 起需 iPhone 15+,见 ADR-0007);`TARGETED_DEVICE_FAMILY=1`(仅 iPhone)。
- **模拟器**能看到画面 + Throw 按钮,但触觉静默、CoreMotion 摇晃很弱 —— 真机调校是 Phase 2。
- **真机**:在 `project.yml`(或 Xcode → Signing)里把 `DEVELOPMENT_TEAM` 设成你的 Apple ID team,`xcodegen generate`,运行。

## Phase 2 调校循环

跑在真机上之后,循环是:
1. Throw → 看 + 感受。
2. 一次只调一个滑块。
3. 再 Throw。
4. 重复,直到 Settle 读起来"像那张桌子"。
5. 记下收敛值;它们成为 v1 里 `PhysicsScene` 的常数。
