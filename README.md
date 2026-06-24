# Harmony-WiFi-IM

基于 HarmonyOS NEXT 的跨设备即时通信系统 — 无需互联网、无需账号体系，通过 Wi-Fi Direct (P2P) 实现设备间文字和图片的实时通信。

## 特性

- **零基础设施依赖** — 无需 Wi-Fi 热点、路由器、蜂窝网络或互联网接入
- **零账号体系** — 无需注册登录，设备即身份
- **设备发现** — 自动扫描附近支持 Wi-Fi Direct 的鸿蒙设备
- **即时通信** — 支持单聊（一对一）和群聊（一对多）两种模式
- **文字 + 图片** — 支持发送文字消息和图片消息（图片支持点击查看大图）
- **消息持久化** — 本地 SQLite 存储历史消息与会话记录
- **断线重连** — 连接异常断开后自动重连（间隔 3 秒，最多 5 次）
- **心跳检测** — 每 10 秒检测连接状态，连续 3 次无响应判定离线

## 技术栈

| 领域 | 方案 |
|---|---|
| 开发语言 | ArkTS |
| UI 框架 | ArkUI（声明式） |
| 设备发现/连接 | `@kit.ConnectivityKit` — Wi-Fi Direct P2P |
| 网络通信 | `@kit.NetworkKit` — TCP Socket |
| 数据持久化 | `@kit.ArkData` — relationalStore (SQLite) |
| 状态管理 | `@State` / `@Observed` (V1 状态管理装饰器) |
| 目标 SDK | HarmonyOS 6.0 (API 20) |

## 架构概览

```
┌─────────────────────────────────────────┐
│                Pages                    │
│   Index (Tab) / ChatPage / ImagePreview │
├─────────────────────────────────────────┤
│              ViewModels                 │
│   ChatVM / SessionListVM / DeviceListVM │
├─────────────────────────────────────────┤
│             Models / Managers           │
│      IMManager (单例，核心枢纽)         │
├──────────────────┬──────────────────────┤
│  Network Layer   │  Database Layer      │
│  TcpConnection   │  DatabaseHelper      │
│  ProtocolDecoder │  MessageDao/Repo     │
│  Heartbeat       │  SessionDao/Repo     │
└──────────────────┴──────────────────────┘
```

### 网络拓扑（星型结构）

```
                   ┌─────────────┐
                   │   GO 设备    │
                   │ (群组所有者)  │
                   └──────┬──────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
     ┌────┴────┐    ┌────┴────┐    ┌────┴────┐
     │ GC 设备 │    │ GC 设备 │    │ GC 设备 │
     │ (成员A) │    │ (成员B) │    │ (成员C) │
     └─────────┘    └─────────┘    └─────────┘
```

### 通信协议

自定义应用层协议，JSON 消息体 + 4 字节大端长度前缀帧（解决 TCP 粘包）：

```
┌──────────────────┬──────────────────────┐
│  4 字节长度(BE)  │    JSON 消息体        │
└──────────────────┴──────────────────────┘
```

消息类型：`TEXT` | `IMAGE` | `SYSTEM_JOIN` | `SYSTEM_LEAVE` | `HEARTBEAT` | `ACK`

## 构建

```bash
# 构建 debug
hvigorw assembleHap --mode module -p product=default

# 构建 release
hvigorw assembleHap --mode module -p product=default -p buildMode=release

# 运行本地单元测试
hvigorw test

# 代码检查
hvigorw lint
```

## 项目结构

```
wifi_im/
├── AppScope/                    # 应用全局配置
├── entry/                       # 主模块
│   └── src/main/ets/
│       ├── entryability/        # 应用入口 (EntryAbility)
│       ├── pages/               # 页面: Index, ChatPage, ImagePreviewPage
│       ├── components/          # 可复用 UI 组件
│       ├── viewmodel/           # 视图模型 (MVVM 状态层)
│       ├── model/               # 数据模型 + IMManager 核心管理器
│       └── common/
│           ├── network/         # TCP 连接管理、协议解码、心跳
│           ├── database/        # RDB 初始化、DAO、Repository
│           └── utils/           # 工具类
├── doc/                         # 需求文档与 UI 效果图
└── hvigor/                      # 构建配置
```

## 权限

```json
{
  "requestPermissions": [
    { "name": "ohos.permission.INTERNET" },
    { "name": "ohos.permission.GET_WIFI_INFO" },
    { "name": "ohos.permission.SET_WIFI_INFO" }
  ]
}
```

## 约束与限制

- 所有参与通信的设备必须开启 Wi-Fi 功能
- 设备需支持 Wi-Fi Direct (`SystemCapability.Communication.WiFi.P2P`)
- 不支持离线消息（设备离线期间的消息无法接收）
- 不支持跨子网通信（所有设备必须在同一 P2P 群组内）
- 单群组最大支持约 8 台设备
