# Voice Synthesis Log Collection Guide

## 概述

语音合成流程中添加了详细的文件日志系统，用于追踪和诊断语音播放中的卡顿、丢失等问题。

## 日志文件位置

### 在设备上
- **路径**：Files.app → On My iPhone → AuraVoiceAssistant → VoiceLogs
- **文件格式**：`voice_YYYY-MM-DDTHH-MM-SS.log`
- **自动生成**：每次启动 app 时创建一个新的日志文件

### 在 Mac 上导出
```bash
# 通过 Xcode 导出（真机）
# 1. 连接 iPhone
# 2. Xcode → Window → Devices and Simulators
# 3. 选择设备 → App Container
# 4. 选择 AuraVoiceAssistant → Download Container
# 5. 解压后进入 AppData/Documents/VoiceLogs

# 或者用 Finder 的 iPad/iPhone 侧边栏直接拖取文件
```

## 日志内容说明

### 日志格式
```
[ISO8601时间戳] [日志级别] 消息内容
```

例如：
```
[2026-06-13T21:49:47.123Z] [DEBUG] Streaming token: '你好，今天天气很好。' (12 chars)
[2026-06-13T21:49:47.234Z] [INFO] Enqueued 12 chars → 1 segments. Total pending: 1
[2026-06-13T21:49:47.345Z] [INFO] Drain worker started. Gen: 12345678-1234-1234-1234-123456789012
[2026-06-13T21:49:47.456Z] [INFO] Synthesis START: '你好，今天天气很好。' (length: 12)
[2026-06-13T21:49:49.567Z] [DEBUG] speak() DONE: took 2.11s, reason: 0
[2026-06-13T21:49:49.678Z] [INFO] Synthesis DONE: '你好，今天天气很好。' | Processed: 1, Remaining: 0
[2026-06-13T21:49:49.789Z] [INFO] Drain ended. Processed: 1, Skipped: 0, Errors: 0, Pending: 0
```

## 关键日志点

### 1. 文本流入 (VoiceCallCoordinator)
```
Streaming token: '文本内容' (字符数 chars)
Final text enqueue: '文本内容' (字符数 chars)
Final text empty, sending flush signal
```
**说明**：tracking AI 的流式回复何时到达

### 2. 分段处理 (TTSPlaybackQueue.enqueue)
```
Enqueued X chars → Y segments. Total pending: Z
Final flush remainder: X chars. Total pending now: Z
```
**说明**：
- `X chars` = 这次输入的字符数
- `Y segments` = 分解后的句子段数
- `Z` = 当前等待队列中的总段数

### 3. 播放工作线程 (TTSPlaybackQueue.drain)
```
Drain worker started. Gen: UUID
Synthesis START: '文本' (length: N)
Synthesis DONE: '文本' | Processed: X, Remaining: Y
Drain ended. Processed: X, Skipped: Y, Errors: Z, Pending: W
```
**说明**：
- `Processed` = 成功合成并播放的段数
- `Skipped` = 被过滤掉的空段
- `Errors` = 合成失败的段数
- `Pending` = 结束时还未处理的段数
- `Remaining` = 每个段合成后剩余的待处理段数

### 4. Azure 合成调用 (AzureSpeechSynthesizer)
```
speak() START: '文本' (length: N)
speak() DONE: took X.XXs, reason: 0
```
**说明**：
- `X.XXs` = 这个段的合成耗时
- `reason` = Azure SDK 的返回码（0 = 成功）

## 诊断指南

### 问题：播放卡顿

**检查点**：
1. **合成耗时**：`speak() DONE: took X.XXs`
   - 如果每个段都 > 2s，说明是 Azure 网络/API 慢
   - 如果大部分 < 1s，说明不是合成本身

2. **分段长度**：`Enqueued X chars → Y segments`
   - 分段太长（40+ 字符）会导致等待
   - 分段太短（< 5 字符）会导致频繁切换

3. **队列堆积**：`Total pending: Z` 持续增长
   - 说明合成速度 < 文本流入速度
   - 检查 `Processed` vs `Remaining` 的比率

### 问题：声音丢失

**检查点**：
1. **有没有错误**：`Errors: X > 0`
   - 查看对应的 ERROR 级别日志

2. **有没有跳过**：`Skipped: X > 0`
   - SpeechTextSanitizer 过滤掉了内容

3. **Generation mismatch**：
   ```
   Generation mismatch. Current: UUID
   ```
   - 说明用户中断了（barge-in 或取消），这是正常的

4. **最后统计**：`Drain ended. Processed: X, Pending: Y`
   - 如果 `Pending > 0`，说明有段没被处理

## 日志收集步骤

### 在真机上测试

1. **启动 app**
   - 此时已开始记录日志

2. **进行完整对话**
   - 测试正常流程和边界情况
   - 记录主观感受（流畅 / 卡顿 / 丢失）

3. **导出日志**
   - 连接 Mac，用 Xcode Device Window 或 Finder 导出
   - 保存到本地

4. **分析日志**
   ```bash
   # 查看日志文件大小
   wc -l voice_*.log
   
   # 查看合成耗时分布
   grep "speak() DONE" voice_*.log | sed 's/.*took //' | sed 's/s.*//' | sort -n
   
   # 查看是否有错误
   grep "ERROR\|FAILED" voice_*.log
   
   # 查看段处理统计
   grep "Drain ended" voice_*.log
   ```

## 日志级别说明

| 级别 | 用途 |
|-----|-----|
| DEBUG | 详细的流程信息（token 到达、合成耗时) |
| INFO | 关键事件（worker 启动/停止、段统计) |
| WARNING | 警告性情况（generation mismatch、合成被中止) |
| ERROR | 错误情况（合成失败、异常) |

## 配置修改

### 修改分段策略
文件：`AuraVoiceAssistant/ViewModels/VoiceCallViewModel.swift`

```swift
playback: TTSPlaybackQueue(
    synthesizer: speechServices.synthesizer,
    maxSegmentLength: 30,      // 最大字符数，改小会更流畅但合成频率高
    firstSegmentMinLength: 1   // 首段最小字符数，改小会更快响应
)
```

### 修改日志刷新间隔
文件：`VoiceCore/Sources/VoiceCore/Utilities/LogCapture.swift`

```swift
private let bufferFlushInterval: TimeInterval = 0.5  // 改小 = 更及时但 I/O 更频繁
```

## 常见场景日志示例

### 场景 1：正常流畅对话

```
[...] [DEBUG] Streaming token: '你好' (2 chars)
[...] [INFO] Enqueued 2 chars → 1 segments. Total pending: 1
[...] [INFO] Drain worker started. Gen: xxx
[...] [INFO] Synthesis START: '你好' (length: 2)
[...] [DEBUG] speak() START: '你好' (length: 2)
[...] [DEBUG] speak() DONE: took 0.85s, reason: 0
[...] [INFO] Synthesis DONE: '你好' | Processed: 1, Remaining: 0
[...] [DEBUG] Streaming token: '，今天' (2 chars)
[...] [INFO] Enqueued 2 chars → 1 segments. Total pending: 1
[...] [INFO] Synthesis START: '，今天' (length: 2)
[...] [DEBUG] speak() DONE: took 0.92s, reason: 0
[...] [INFO] Synthesis DONE: '，今天' | Processed: 2, Remaining: 0
```
**预期**：合成耗时稳定在 0.8~1.2s

### 场景 2：合成缓慢

```
[...] [INFO] Synthesis START: '今天天气很好' (length: 6)
[...] [DEBUG] speak() DONE: took 3.45s, reason: 0
```
**问题**：单个段耗时 > 3s，可能是网络或 Azure 节流

### 场景 3：文本堆积

```
[...] [INFO] Enqueued 50 chars → 2 segments. Total pending: 5
[...] [INFO] Enqueued 48 chars → 2 segments. Total pending: 9
[...] [INFO] Enqueued 52 chars → 2 segments. Total pending: 13
```
**问题**：`Total pending` 持续增长，合成速度跟不上

### 场景 4：用户中断

```
[...] [INFO] Drain worker started. Gen: xxx
[...] [INFO] Synthesis START: '...' (length: N)
[...] [WARNING] Generation mismatch. Current: yyy
[...] [INFO] Drain ended. Processed: X, Skipped: 0, Errors: 0, Pending: 3
```
**预期**：generation 改变说明启动了新的播放周期（barge-in 或 cancel）

## 记录日志时的清单

测试完成后，请提供：

- [ ] 日志文件名和时间戳
- [ ] 完整对话内容（输入和 AI 回复）
- [ ] 主观感受（流畅 / 卡顿 / 丢失位置）
- [ ] 可选：主要统计数据（合成耗时范围、段数、错误率）

## 联系方式

遇到问题或有疑问，参考这个文档的诊断指南进行初步分析，然后提供日志文件和上述清单。
