import { socket } from '@kit.NetworkKit';
import { ProtocolDecoder } from './ProtocolDecoder';
import { HeartbeatManager } from './HeartbeatManager';

export enum ConnectionState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2
}

export interface ConnectionInfo {
  host: string;
  port: number;
}

export class TcpConnectionManager {
  private static instance: TcpConnectionManager;
  private currentSocket: socket.TCPSocket | null = null;
  private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  private isServer: boolean = false;
  private protocolDecoder: ProtocolDecoder = new ProtocolDecoder();
  private messageCallback: ((data: Uint8Array) => void) | null = null;
  private stateChangeCallback: ((state: ConnectionState) => void) | null = null;
  private readonly DEFAULT_PORT: number = 8888;
  private reconnectAttempts: number = 0;
  private readonly MAX_RECONNECT: number = 5;
  private readonly RECONNECT_INTERVAL: number = 3000;
  private savedHost: string = '';
  private savedPort: number = 8888;

  public static getInstance(): TcpConnectionManager {
    if (!TcpConnectionManager.instance) {
      TcpConnectionManager.instance = new TcpConnectionManager();
    }
    return TcpConnectionManager.instance;
  }

  public setOnMessage(callback: (data: Uint8Array) => void): void {
    this.messageCallback = callback;
  }

  public setOnStateChange(callback: (state: ConnectionState) => void): void {
    this.stateChangeCallback = callback;
  }

  public getState(): ConnectionState {
    return this.connectionState;
  }

  public isGroupOwner(): boolean {
    return this.isServer;
  }

  public startServer(port?: number): void {
    this.isServer = true;
    this.connectionState = ConnectionState.CONNECTED;
  }

  public connect(host: string, port?: number): void {
    if (this.connectionState === ConnectionState.CONNECTED) {
      return;
    }
    this.isServer = false;
    this.connectionState = ConnectionState.CONNECTING;
    this.savedHost = host;
    this.savedPort = port ?? this.DEFAULT_PORT;
    let connectPort = this.savedPort;
    try {
      this.currentSocket = socket.constructTCPSocketInstance();
      this.currentSocket.bind({ address: '0.0.0.0', port: 0, family: 1 }, (err: Error) => {
        if (err) {
          this.connectionState = ConnectionState.DISCONNECTED;
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
            this.connectionState = ConnectionState.DISCONNECTED;
            this.attemptReconnect();
            return;
          }
          this.connectionState = ConnectionState.CONNECTED;
          HeartbeatManager.getInstance().start();
          this.setupListeners();
        });
      });
    } catch (error) {
      this.connectionState = ConnectionState.DISCONNECTED;
      this.attemptReconnect();
    }
  }

  private setupListeners(): void {
    if (!this.currentSocket) {
      return;
    }
    this.currentSocket.on('message', (data: socket.SocketMessageInfo) => {
      let messageData = data.message as ArrayBuffer;
      let uint8Data = new Uint8Array(messageData);
      if (this.messageCallback) {
        this.messageCallback(uint8Data);
      }
    });
    this.currentSocket.on('error', (err: Error) => {
      this.connectionState = ConnectionState.DISCONNECTED;
      this.attemptReconnect();
    });
    this.currentSocket.on('close', () => {
      this.connectionState = ConnectionState.DISCONNECTED;
      this.attemptReconnect();
    });
  }

  private attemptReconnect(): void {
    if (!this.isServer && this.savedHost && this.reconnectAttempts < this.MAX_RECONNECT) {
      this.reconnectAttempts++;
      setTimeout(() => {
        this.connect(this.savedHost, this.savedPort);
      }, this.RECONNECT_INTERVAL);
    }
  }

  public send(data: Uint8Array, callback?: (err: Error | null) => void): void {
    let framedData = ProtocolDecoder.buildFrame(data);
    if (this.currentSocket) {
      this.currentSocket.send({
        data: framedData.buffer as ArrayBuffer
      }, (err: Error) => {
        if (callback) {
          callback(err ?? null);
        }
      });
    }
  }

  public disconnect(): void {
    HeartbeatManager.getInstance().stop();
    if (this.currentSocket) {
      try {
        this.currentSocket.close();
      } catch (e) {
        // ignore close error
      }
      this.currentSocket = null;
    }
    this.connectionState = ConnectionState.DISCONNECTED;
    this.reconnectAttempts = 0;
  }
}
