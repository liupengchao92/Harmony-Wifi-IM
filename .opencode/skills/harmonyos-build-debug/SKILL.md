---
name: "harmonyos-build-debug"
description: "HarmonyOS项目编译调试技能。执行编译指令、识别编译错误、分析问题根源并实施修复。Invoke when用户需要编译HarmonyOS项目、遇到编译错误、或需要调试ArkTS代码问题。"
---

# HarmonyOS 编译调试技能

## 概述

本技能提供HarmonyOS项目（ArkTS）的完整编译调试流程，包括编译指令执行、错误识别、问题分析和修复实施的标准化操作指南。

## 何时使用此技能

- 需要编译HarmonyOS项目生成HAP包
- 遇到ArkTS编译错误需要诊断和修复
- 需要理解编译错误信息和警告
- 需要验证代码修改后的构建结果

---

## 1. 编译指令执行

### 1.1 基础编译命令

```powershell
# 标准编译命令（Module模式）
& 'D:\Huawei\DevEco Studio\tools\node\node.exe' 'D:\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' --mode module -p module=entry@default -p product=default assembleHap
```

### 1.2 命令参数详解

| 参数 | 说明 | 示例值 |
|------|------|--------|
| `--mode` | 构建模式 | `module` / `project` |
| `-p module` | 指定模块 | `entry@default` |
| `-p product` | 指定产品 | `default` |
| `assembleHap` | 构建目标 | 生成HAP安装包 |
| `--analyze=normal` | 分析模式 | 正常分析级别 |
| `--parallel` | 并行构建 | 加速编译 |
| `--incremental` | 增量编译 | 只编译变更部分 |
| `--daemon` | 守护进程 | 保持构建服务运行 |

### 1.3 完整编译脚本（推荐）

```powershell
& 'D:\Huawei\DevEco Studio\tools\node\node.exe' 'D:\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' `
  --mode module `
  -p module=entry@default `
  -p product=default `
  -p requiredDeviceType=phone `
  assembleHap `
  --analyze=normal `
  --parallel `
  --incremental `
  --daemon
```

---

## 2. 编译错误识别方法

### 2.1 错误信息提取

使用PowerShell过滤错误信息：

```powershell
# 提取所有ERROR行及上下文
& 'hvigorw.js路径' ... 2>&1 | Select-String -Pattern "ERROR" -Context 2,2

# 查看最后30行输出
& 'hvigorw.js路径' ... 2>&1 | Select-Object -Last 30
```

### 2.2 常见错误类型识别

#### Type 1: 属性不存在错误
```
ERROR: 10505001 ArkTS Compiler Error
Error Message: Property 'XXX' does not exist on type 'typeof YYY'
```
**特征**：使用了ArkTS/API中不存在的属性或方法

#### Type 2: 资源未找到错误
```
ERROR: 10903329 ArkTS Compiler Error
Error Message: Unknown resource name 'icon_xxx'
```
**特征**：引用了不存在的资源文件（图片、字符串等）

#### Type 3: 导入缺失错误
```
ERROR: Cannot find name 'XXX'
```
**特征**：使用了未导入的类、接口或变量

#### Type 4: 类型不匹配错误
```
ERROR: Type 'XXX' is not assignable to type 'YYY'
```
**特征**：赋值或传参时类型不兼容

---

## 3. 问题根源分析技巧

### 3.1 分析流程图

```
编译失败
    ↓
提取ERROR信息 → 定位文件和行号
    ↓
识别错误类型 → 匹配已知模式
    ↓
查看相关代码 → 理解上下文
    ↓
确定根本原因 → 制定修复方案
```

### 3.2 常见API变更对照表

| 弃用/不存在的API | 替代方案 | 说明 |
|-----------------|----------|------|
| `Curve.Spring` | `Curve.EaseOut` / `Curve.EaseInOut` | 动画曲线 |
| `FontWeight.SemiBold` | `FontWeight.Bold` / `FontWeight.Medium` | 字体粗细 |
| `FontWeight.Light` | `FontWeight.Lighter` | 轻量字体 |
| `animateTo()` (全局) | `animateTo({})` 对象参数形式 | 动画API |
| `getContext()` | `getContext(this)` | 获取上下文 |

### 3.3 资源引用检查清单

- [ ] 图片资源是否存在于 `resources/base/media/` 目录
- [ ] 资源名称是否正确（区分大小写）
- [ ] 是否使用了 `$r('app.media.xxx')` 正确语法
- [ ] 替代方案：使用emoji或Text字符代替图片

---

## 4. 解决方案制定与实施

### 4.1 修复流程

1. **定位问题**：根据错误信息找到具体文件和行号
2. **理解上下文**：阅读相关代码，理解功能意图
3. **选择替代方案**：参考API对照表选择合适的替代
4. **实施修复**：使用 `SearchReplace` 工具修改代码
5. **验证修复**：重新编译确认错误已解决

### 4.2 典型修复案例

#### 案例1：修复不存在的Curve类型
```typescript
// 错误代码
animateTo({ duration: 250, curve: Curve.Spring }, () => { ... })

// 修复方案
animateTo({ duration: 250, curve: Curve.EaseOut }, () => { ... })
// 或
animateTo({ duration: 250, curve: Curve.EaseInOut }, () => { ... })
```

#### 案例2：修复FontWeight
```typescript
// 错误代码
.fontWeight(FontWeight.SemiBold)

// 修复方案
.fontWeight(FontWeight.Bold)
// 或
.fontWeight(FontWeight.Medium)
```

#### 案例3：替换不存在的图标资源
```typescript
// 错误代码
Image($r('app.media.icon_settings'))
  .width(24)
  .height(24)
  .fillColor(Colors.WHITE)

// 修复方案 - 使用emoji
Text('⚙')
  .fontSize(24)
  .fontColor(Colors.WHITE)
```

#### 案例4：补充缺失导入
```typescript
// 错误 - 未导入Dimensions
import { Colors, Spacing, BorderRadius } from '../constants/StyleConstants'

// 修复 - 添加Dimensions导入
import { Colors, Spacing, BorderRadius, Dimensions } from '../constants/StyleConstants'
```

---

## 5. 修复验证标准与步骤

### 5.1 验证流程

```
实施修复
    ↓
重新编译项目
    ↓
检查ERROR数量
    ↓
ERROR = 0 ? 成功 : 继续修复
    ↓
检查WARN（可选优化）
    ↓
构建成功确认
```

### 5.2 验证命令

```powershell
# 完整编译并检查错误
& 'hvigorw.js路径' ... 2>&1 | Select-String -Pattern "ERROR|BUILD SUCCESSFUL|BUILD FAILED" -Context 0,0
```

### 5.3 成功标准

| 检查项 | 标准 | 说明 |
|--------|------|------|
| ERROR数量 | 0 | 无编译错误 |
| BUILD结果 | SUCCESSFUL | 构建成功消息 |
| HAP生成 | 存在 | 检查 `build/outputs/default/` 目录 |

### 5.4 警告处理建议

WARN信息不影响构建，但建议优化：

| 警告类型 | 建议处理 |
|----------|----------|
| `'animateTo' has been deprecated` | 使用新的动画API |
| `'back' has been deprecated` | 使用新的路由API |
| `Function may throw exceptions` | 添加try-catch处理 |

---

## 6. 工具与资源

### 6.1 相关工具

- **DevEco Studio**: HarmonyOS官方IDE
- **Hvigor**: HarmonyOS构建工具
- **ArkTS Compiler**: ArkTS语言编译器

### 6.2 参考文档

- [ArkTS API参考](https://developer.harmonyos.com/cn/docs/documentation/doc-guides-V3/arkts-api-reference-0000001427744560-V3)
- [HarmonyOS开发指南](https://developer.harmonyos.com/cn/docs/documentation/doc-guides-V3/development-intro-0000001427902512-V3)

### 6.3 项目文件结构

```
project/
├── entry/src/main/ets/          # ArkTS源码
│   ├── pages/                   # 页面组件
│   ├── components/              # 可复用组件
│   ├── constants/               # 常量定义
│   └── ...
├── entry/src/main/resources/    # 资源文件
│   └── base/media/              # 图片资源
└── build/outputs/default/       # 构建输出
```

---

## 7. 最佳实践

### 7.1 编码建议

1. **使用类型安全**：充分利用ArkTS的静态类型检查
2. **避免弃用API**：关注编译警告，及时更新API
3. **资源管理**：确保引用的资源文件存在
4. **模块化导入**：显式导入所有依赖

### 7.2 调试技巧

1. **增量编译**：使用 `--incremental` 加速调试
2. **错误过滤**：使用 `Select-String` 快速定位错误
3. **分步修复**：一次修复一类错误，避免混乱
4. **版本控制**：修复前提交代码，便于回滚

---

## 8. 快速参考卡片

### 常用修复速查

| 问题 | 快速修复 |
|------|----------|
| `Curve.Spring` 不存在 | 改为 `Curve.EaseOut` |
| `FontWeight.SemiBold` 不存在 | 改为 `FontWeight.Bold` |
| `FontWeight.Light` 不存在 | 改为 `FontWeight.Lighter` |
| 图标资源不存在 | 改用emoji或Text字符 |
| `Dimensions` 未定义 | 添加导入 |

### 编译状态速查

```powershell
# 只看关键信息
hvigorw ... 2>&1 | Select-String "ERROR|SUCCESSFUL|FAILED"
```

---

*文档版本: 1.0*
*最后更新: 2026-02-09*
*适用项目: HarmonyOS ArkTS项目*
