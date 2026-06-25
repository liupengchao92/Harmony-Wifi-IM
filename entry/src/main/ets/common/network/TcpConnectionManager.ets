import { socket } from '@kit.NetworkKit';
import { ProtocolDecoder } from './ProtocolDecoder';
import { HeartbeatManager } from './HeartbeatManager';
import { Logger } from '../utils/Logger';

/**
 * TCP 连接状态枚举
 * DISCONNECTED - 未连接
 * CONNECTING   - 连接中
 * CONNECTED    - 已连接
 */
export enum ConnectionState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2
}

/**
 * TCP 连接管理器（单例）
 *
 * 负责所有 TCP Socket 通信，支持两种角色：
 * - 服务端（GO）：绑定 TCPSocketServer，监听并接受多个客户端连接，广播消息
 * - 客户端（GC）：创建 TCPSocket 连接到服务端，收发消息
 *
 * 特性：
 * - 自动断线重连（最多 5 次，间隔 3 秒，仅客户端角色）
 * - 连接状态变化回调通知
 * - 4 字节大端长度前缀组帧/拆帧
 */
export class TcpConnectionManager {
  private static instance: TcpConnectionManager;
  private currentSocket: socket.TCPSocket | null = null;
  private serverSocket: socket.TCPSocketServer | null = null;
  private clientConnections: socket.TCPSocketConnection[] = [];
  private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  private isServer: boolean = false;
  private messageCallback: ((data: Uint8Array) => void) | null = null;
  private stateChangeCallback: ((state: ConnectionState) => void) | null = null;
  private clientConnectedCallback: (() => void) | null = null;
  private readonly DEFAULT_PORT: number = 8888;
  private reconnectAttempts: number = 0;
  private readonly MAX_RECONNECT: number = 5;
  private readonly RECONNECT_INTERVAL: number = 3000;
  private savedHost: string = '';
  private savedPort: number = 8888;
  private logger: Logger = new Logger('TcpConnectionManager');

  public static getInstance(): TcpConnectionManager {
    if (!TcpConnectionManager.instance) {
      TcpConnectionManager.instance = new TcpConnectionManager();
    }
    return TcpConnectionManager.instance;
  }

  /**
   * 注册数据接收回调
   * 当收到任何连接（服务端客户端或直连）的消息时触发
   */
  public setOnMessage(callback: (data: Uint8Array) => void): void {
    this.messageCallback = callback;
  }

  /**
   * 注册连接状态变化回调
   * 当连接状态从 DISCONNECTED→CONNECTING→CONNECTED 切换时触发
   */
  public setOnStateChange(callback: (state: ConnectionState) => void): void {
    this.stateChangeCallback = callback;
  }

  /**
   * 注册新客户端连接回调（仅服务端有效）
   * 当新的 TCP 客户端连接到服务端时触发
   */
  public setOnClientConnected(callback: () => void): void {
    this.clientConnectedCallback = callback;
  }

  public getState(): ConnectionState {
    return this.connectionState;
  }

  public isGroupOwner(): boolean {
    return this.isServer;
  }

  /** 获取当前已连接的客户端数量（仅服务端有效） */
  public getClientCount(): number {
    return this.clientConnections.length;
  }

  /**
   * 启动 TCP 服务端（GO 角色调用）
   *
   * 1. 创建 TCPSocketServer 实例
   * 2. 绑定 0.0.0.0:port 并开始监听
   * 3. 监听 'connect' 事件，接受客户端连接
   * 4. 为每个客户端设置 message/close/error 监听器
   */
  public startServer(port?: number): void {
    if (this.connectionState === ConnectionState.CONNECTED) {
      this.logger.info('startServer: 已连接，跳过');
      return;
    }
    this.isServer = true;
    let listenPort: number = port ?? this.DEFAULT_PORT;
    this.logger.info(`startServer: 启动 TCP 服务端，端口=${listenPort}`);
    try {
      this.serverSocket = socket.constructTCPSocketServerInstance();
      this.serverSocket.listen({
        address: '0.0.0.0',
        port: listenPort,
        family: 1
      }, () => {
        this.logger.info('startServer: 服务端监听成功');
        this.setConnectionState(ConnectionState.CONNECTED);
        this.serverSocket!.on('connect', (client: socket.TCPSocketConnection) => {
          this.logger.info('startServer: 新客户端连接');
          this.clientConnections.push(client);
          // 转发该客户端的所有消息到上层
          client.on('message', (data: socket.SocketMessageInfo) => {
            let uint8Data: Uint8Array = new Uint8Array(data.message as ArrayBuffer);
            if (this.messageCallback) {
              this.messageCallback(uint8Data);
            }
          });
          // 客户端断开时从列表移除
          client.on('close', () => {
            this.logger.info('startServer: 客户端断开');
            let idx: number = this.clientConnections.indexOf(client);
            if (idx >= 0) {
              this.clientConnections.splice(idx, 1);
            }
          });
          client.on('error', () => {
            this.logger.info('startServer: 客户端连接错误');
            let idx: number = this.clientConnections.indexOf(client);
            if (idx >= 0) {
              this.clientConnections.splice(idx, 1);
            }
          });
          // 通知上层有新客户端加入
          if (this.clientConnectedCallback) {
            this.clientConnectedCallback();
          }
        });
      });
    } catch (error) {
      this.logger.error('startServer: 启动失败', error as Error);
      this.setConnectionState(ConnectionState.DISCONNECTED);
    }
  }

  /**
   * 连接到 TCP 服务端（GC 角色调用）
   *
   * 1. 创建 TCPSocket 实例
   * 2. 绑定本地随机端口
   * 3. 连接到目标 host:port
   * 4. 连接成功后启动心跳和消息监听
   * 5. 连接失败自动重连
   */
  public connect(host: string, port?: number): void {
    if (this.connectionState === ConnectionState.CONNECTED) {
      this.logger.info('connect: 已连接，跳过');
      return;
    }
    this.isServer = false;
    this.setConnectionState(ConnectionState.CONNECTING);
    this.savedHost = host;
    this.savedPort = port ?? this.DEFAULT_PORT;
    let connectPort: number = this.savedPort;
    this.logger.info(`connect: 连接 ${host}:${connectPort}`);
    try {
      this.currentSocket = socket.constructTCPSocketInstance();
      this.currentSocket.bind({ address: '0.0.0.0', port: 0, family: 1 }, (err: Error) => {
        if (err) {
          this.logger.error('connect: bind 失败', err);
          this.setConnectionState(ConnectionState.DISCONNECTED);
          return;
        }
        if (!this.currentSocket) {
          return;
        }
        this.currentSocket.connect({
          address: { address: host, port: connectPort },
          timeout: 6000
        }, (connectErr: Error) => {
          if (connectErr) {
            this.logger.error('connect: 连接失败', connectErr);
            this.setConnectionState(ConnectionState.DISCONNECTED);
            this.attemptReconnect();
            return;
          }
          this.logger.info('connect: 连接成功');
          this.setConnectionState(ConnectionState.CONNECTED);
          HeartbeatManager.getInstance().start();
          this.setupListeners();
        });
      });
    } catch (error) {
      this.logger.error('connect: 异常', error as Error);
      this.setConnectionState(ConnectionState.DISCONNECTED);
      this.attemptReconnect();
    }
  }

  /**
   * 为客户端 socket 设置事件监听器
   * - message: 收到数据 → 回调上层
   * - error: 连接错误 → 断线重连
   * - close: 连接关闭 → 断线重连
   */
  private setupListeners(): void {
    if (!this.currentSocket) {
      return;
    }
    this.currentSocket.on('message', (data: socket.SocketMessageInfo) => {
      let messageData: ArrayBuffer = data.message as ArrayBuffer;
      let uint8Data: Uint8Array = new Uint8Array(messageData);
      if (this.messageCallback) {
        this.messageCallback(uint8Data);
      }
      // 收到消息说明连接正常，重置心跳计时器
      HeartbeatManager.getInstance().reset();
    });
    this.currentSocket.on('error', () => {
      this.logger.info('setupListeners: socket error');
      this.setConnectionState(ConnectionState.DISCONNECTED);
      this.attemptReconnect();
    });
    this.currentSocket.on('close', () => {
      this.logger.info('setupListeners: socket close');
      this.setConnectionState(ConnectionState.DISCONNECTED);
      this.attemptReconnect();
    });
  }

  /**
   * 断线重连机制（仅客户端角色生效）
   * 最多重试 MAX_RECONNECT 次，每次间隔 RECONNECT_INTERVAL 毫秒
   */
  private attemptReconnect(): void {
    if (!this.isServer && this.savedHost && this.reconnectAttempts < this.MAX_RECONNECT) {
      this.reconnectAttempts++;
      this.logger.info(`attemptReconnect: 第 ${this.reconnectAttempts}/${this.MAX_RECONNECT} 次重连，目标 ${this.savedHost}:${this.savedPort}`);
      setTimeout(() => {
        this.connect(this.savedHost, this.savedPort);
      }, this.RECONNECT_INTERVAL);
    } else if (this.reconnectAttempts >= this.MAX_RECONNECT) {
      this.logger.info('attemptReconnect: 已达最大重试次数，放弃重连');
    }
  }

  /**
   * 发送数据
   * - 服务端模式：广播给所有已连接客户端
   * - 客户端模式：发送给连接的服务端
   *
   * 数据会自动通过 ProtocolDecoder.buildFrame() 添加 4 字节长度前缀
   */
  public send(data: Uint8Array, callback?: (err: Error | null) => void): void {
    let framedData: Uint8Array = ProtocolDecoder.buildFrame(data);
    let buffer: ArrayBuffer = framedData.buffer as ArrayBuffer;
    if (this.isServer) {
      // 服务端：广播给所有已连接客户端
      let clientCount: number = this.clientConnections.length;
      this.logger.info(`send: 服务端广播消息，客户端数=${clientCount}`);
      let hasError: boolean = false;
      for (let i: number = 0; i < clientCount; i++) {
        this.clientConnections[i].send({ data: buffer }, (err: Error) => {
          if (err) {
            hasError = true;
            this.logger.error('send: 广播失败', err);
          }
        });
      }
      if (callback) {
        callback(hasError ? new Error('部分客户端发送失败') : null);
      }
    } else if (this.currentSocket) {
      this.currentSocket.send({ data: buffer }, (err: Error) => {
        if (callback) {
          callback(err ?? null);
        }
        if (err) {
          this.logger.error('send: 发送失败', err);
        }
      });
    }
  }

  /**
   * 断开所有连接
   * 1. 停止心跳检测
   * 2. 关闭所有客户端连接
   * 3. 关闭服务端 socket
   * 4. 关闭客户端 socket
   * 5. 重置状态
   */
  public disconnect(): void {
    this.logger.info('disconnect: 断开所有连接');
    HeartbeatManager.getInstance().stop();
    // 断开所有客户端连接
    for (let i: number = 0; i < this.clientConnections.length; i++) {
      try {
        this.clientConnections[i].close();
      } catch (e) {
        // ignore close error
      }
    }
    this.clientConnections = [];
    // 关闭服务端 socket
    if (this.serverSocket) {
      try {
        this.serverSocket.off('connect');
      } catch (e) {
        // ignore
      }
      this.serverSocket = null;
    }
    // 关闭客户端 socket
    if (this.currentSocket) {
      try {
        this.currentSocket.close();
      } catch (e) {
        // ignore close error
      }
      this.currentSocket = null;
    }
    this.setConnectionState(ConnectionState.DISCONNECTED);
    this.reconnectAttempts = 0;
    this.isServer = false;
  }

  /** 更新连接状态并通知上层回调 */
  private setConnectionState(state: ConnectionState): void {
    if (this.connectionState !== state) {
      this.logger.info(`setConnectionState: ${ConnectionState[this.connectionState]} -> ${ConnectionState[state]}`);
    }
    this.connectionState = state;
    if (this.stateChangeCallback) {
      this.stateChangeCallback(state);
    }
  }
}
