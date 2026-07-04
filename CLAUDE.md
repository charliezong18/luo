# CLAUDE.md — 落 (Luò)

物理级掷币起卦的 I Ching iOS app。SwiftUI + SceneKit + CoreMotion/CoreHaptics，iOS 17+，仅 iPhone。

## Session 协议（重要）

1. **开工先读 `STATUS.md`** — 当前进度、下一步、已知坑都在那里，不要靠猜或翻 commit 推断。
2. **收工前更新 `STATUS.md`** — 本次做了什么、下一步是什么、新踩的坑。这是跨 session 的唯一状态交接，漏写等于让下一个 session 失忆。

## 构建与验证

```bash
xcodegen generate    # project.yml → Luo.xcodeproj（.xcodeproj 不手工编辑，随时可重生成）
xcodebuild -project Luo.xcodeproj -scheme Luo \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

改了 `project.yml` 必须重新 `xcodegen generate`。跑测试用 scheme `Luo` 的 LuoTests target。

## 目录

- `Luo/` — 全部 Swift 源码；`LuoTests/` — 单测
- `project.yml` — XcodeGen 配置（SSOT，别动 .xcodeproj）
- `scripts/` — `baihua-crypt.swift`（白话语料 AES-GCM 加密打包）、`make_app_icon.py`
- `DESIGN.md` / `DESIGN-paper.md` — 公开设计文档；完整设计 + 9 个 ADR 在私有 vault `2nd Brain/Hang/Plans/Divination_App`

## 已知坑（别再踩）

- **Swift 5 语言模式**（project.yml 里锁死）— CoreMotion 闭包跨 @MainActor 在 Swift 6 strict concurrency 下会炸，别升。
- **SceneKit 物理**：厘米尺度下 PhysX 不稳定；铜钱速度上报不可信；tumble 用 `applyTorque`。调试用 headless 流程：NSLog 探针 + `simctl install/launch` + `log show` 读轨迹，不用肉眼盯动画。
- **白话语料是加密资源**：明文在 `scripts/baihua-plaintext.json`，改完要用 `baihua-crypt.swift` 重新加密进 bundle，直接改 bundle 无效。
- 结果页等长内容页面：内容包 ScrollView、主操作钉在外面（历史教训，commit 01344bc）。
