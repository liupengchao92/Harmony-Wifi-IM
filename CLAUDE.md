# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指引。

## 项目概述

WiFi IM — 一款基于 HarmonyOS 的即时通讯应用，通过 Wi-Fi Direct (P2P) 连接实现设备间通信，无需互联网接入。设备通过 Wi-Fi P2P 互相发现、组建群组，然后通过 TCP socket 使用自定义 JSON 协议进行通信。

- **平台**: HarmonyOS 6.0 (API 20), ArkTS 语言, Stage 模型
- **Bundle**: `com.lpc.wifiim`
- **权限**: INTERNET, GET_WIFI_INFO, SET_WIFI_INFO

## 构建与测试

```bash
# 构建项目 (debug)
hvigorw assembleHap --mode module -p product=default

# 构建 release
hvigorw assembleHap --mode module -p product=default -p buildMode=release

# 运行测试（本地单元测试）
hvigorw test

# 代码检查
hvigorw lint
```

## 架构

应用采用 **MVVM** 模式，跨组件服务使用单例模式：

### 数据流
```
Wi-Fi Direct P2P → DeviceListViewModel（设备发现）
                 → DeviceListViewModel.createGroup() / connectToDevice()
                 → IMManager.startServer() 或 connect()
                 → TcpConnectionManager（TCP socket）
                 → ProtocolDecoder（拆帧 → JSON）
                 → IMManager.routeMessage() → 数据库 + callback → ViewModel → UI
```

### 核心类（均为单例）

| 类 | 职责 |
|---|---|
| `IMManager` | 核心枢纽 — 持有 TcpConnectionManager，路由协议消息到对应处理器，管理群组成员，代理持久化操作 |
| `TcpConnectionManager` | 原始 TCP socket 操作（连接、发送、接收、断线重连，最多重试 5 次，间隔 3 秒）。服务端角色即为群组所有者 (GO) |
| `ProtocolDecoder` | 长度前缀帧协议：4 字节大端无符号整数长度 + JSON 负载。通过累积缓冲区进行流式解码 |
| `HeartbeatManager` | 基于超时的心跳检测：如果在 3×10 秒内未调用 reset，触发 `onHeartbeatTimeout`。当前只检测超时，需要调用方主动调用 `reset()` |
| `DatabaseHelper` | 初始化 RDB 数据库，创建 `message` 和 `session` 表及索引 |

### 网络协议

所有消息均为 JSON 格式，由 `ProtocolDecoder.buildFrame()` 进行组帧：
```json
{
  "version": "1.0",
  "type": "TEXT|IMAGE|SYSTEM_JOIN|SYSTEM_LEAVE|HEARTBEAT|ACK",
  "from": "<deviceId>",
  "fromName": "<deviceName>",
  "to": "<deviceId>|GROUP",
  "timestamp": <number>,
  "payload": { "content": "...", "fileName": "...", "fileSize": 0, "fileMd5": "..." }
}
```

- 群聊：`to` = `"GROUP"`，session ID = `"group_<本地deviceId>"`
- 单聊：`to` = 对方 device ID，session ID = 发送方 device ID
- IMAGE 类型在 payload 中包含文件元数据；实际文件传输尚未实现（仅放置照片占位符）

### 数据库表结构

- **message**: `id`, `message_id` (UNIQUE), `session_id` (已建索引), `type`, `content`, `sender_id`, `sender_name`, `receiver_id`, `timestamp` (已建索引), `status`, `is_local`, `image_path`, `image_size`
- **session**: `id`, `session_id` (UNIQUE), `session_type` (1=个人, 2=群聊), `peer_id`, `peer_name`, `last_message`, `last_message_time`, `unread_count`, `member_count`

采用 DAO→Repository 模式：`MessageDao` / `SessionDao` 处理原始 SQL；`MessageRepository` / `SessionRepository` 封装业务逻辑。

### 目录结构

```
entry/src/main/ets/
  entryability/EntryAbility.ets    — 应用入口，初始化数据库与 IMManager
  model/                           — 数据模型 + IMManager 单例
  viewmodel/                       — @Observed 视图模型（MVVM 状态层）
  components/                      — 可复用的 UI @Component 组件
  pages/                           — @Entry 页面 (Index, ChatPage, ImagePreviewPage)
  common/
    network/                       — TCP、协议帧解析、心跳
    database/                      — RDB 辅助类、DAO、Repository
    utils/                         — DateUtil, Logger
```

`main_pages.json` 中注册了三个页面：`pages/Index`、`pages/ChatPage`、`pages/ImagePreviewPage`。

### 关键模式

- **MVVM + @Observed**：ViewModel 是 `@Observed` 类。组件持有 `@State viewModel` 引用。状态变化会触发 UI 重新渲染。
- **手动替换数组**：ArkTS 的 `@State` 不会深度观察数组的变化（如 push/pop），因此必须整体替换数组（如 `this.messages = [...this.messages, newMsg]` 而非 `.push()`）。
- **Session ID 约定**：单聊 session 以对方 device ID 作为 `sessionId`；群聊 session 使用 `"group_<本地deviceId>"`。

### 测试

使用 `@ohos/hypium` (1.0.25) 测试框架。测试目录：
- `entry/src/test/` — 本地单元测试（在开发机上运行）
- `entry/src/ohosTest/` — 设备集成测试
- `entry/src/mock/` — `@ohos/hamock` 的 mock 配置

当前测试仅为模板代码。

### 注意事项

- `TcpConnectionManager` 的 `startServer()` 方法并未实际绑定服务端 socket — 仅设置 `isServer = true` 和 `CONNECTED` 状态。Wi-Fi P2P 群组的创建/连接在 `DeviceListViewModel` 层通过 `@kit.ConnectivityKit` 处理。
- Device ID 通过 `"device_" + Date.now().toString(36)` 生成，重启应用后不持久。
- 图片发送为占位实现（`sendImageMessage('photo.jpg')`），文件路径是硬编码的，未实现真正的文件选择。
- UI 中大量硬编码中文字符串，未使用资源文件。
- 代码检查启用安全规则（禁止不安全的 AES、RSA、DH、DSA、ECDSA、3DES、哈希算法）。
