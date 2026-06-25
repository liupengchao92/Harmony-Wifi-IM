import { TcpConnectionManager, ConnectionState } from '../common/network/TcpConnectionManager';
import { ProtocolDecoder } from '../common/network/ProtocolDecoder';
import { MessageModel, MessageType, MessageStatus } from './MessageModel';
import { SessionModel } from './SessionModel';
import { GroupMember } from './GroupMember';
import { MessageRepository } from '../common/database/MessageRepository';
import { SessionRepository } from '../common/database/SessionRepository';
import { Logger } from '../common/utils/Logger';

/** 协议消息中的 payload 字段结构 */
interface MessagePayload {
  content?: string;
  fileName?: string;
  fileSize?: number;
  fileMd5?: string;
}

/** 从协议 JSON 解析后的消息结构 */
interface ProtocolMessage {
  version: string;
  type: string;
  from: string;
  fromName: string;
  to: string;
  timestamp: number;
  payload: MessagePayload;
}

/**
 * IM 核心管理器（单例）
 *
 * 应用层通信枢纽，职责包括：
 * 1. 持有 TcpConnectionManager，管理 TCP 连接的启动/停止
 * 2. 协议消息的路由分发：TEXT / IMAGE / SYSTEM_JOIN / SYSTEM_LEAVE
 * 3. 群组成员管理（增删查）
 * 4. 消息与会话的持久化代理
 * 5. 向 ViewModel 层提供回调通知
 */
export class IMManager {
  private static instance: IMManager;
  private connectionManager: TcpConnectionManager = TcpConnectionManager.getInstance();
  private localDeviceId: string = '';
  private localDeviceName: string = '';
  private messageRepository: MessageRepository = new MessageRepository();
  private sessionRepository: SessionRepository = new SessionRepository();
  private newMessageCallback: ((message: MessageModel) => void) | null = null;
  private messageStatusCallback: ((message: MessageModel) => void) | null = null;
  private connectionStateCallback: ((state: ConnectionState) => void) | null = null;
  private groupMembers: GroupMember[] = [];
  private groupCreatedTime: number = 0;
  private reconnectTimer: number = -1;
  private logger: Logger = new Logger('IMManager');

  public static getInstance(): IMManager {
    if (!IMManager.instance) {
      IMManager.instance = new IMManager();
    }
    return IMManager.instance;
  }

  /**
   * 初始化 IM 管理器
   * 在 EntryAbility 中调用，注册消息接收和连接状态回调
   */
  public init(deviceId: string, deviceName: string): void {
    this.localDeviceId = deviceId;
    this.localDeviceName = deviceName;
    this.logger.info(`init: deviceId=${deviceId}, deviceName=${deviceName}`);

    // 注册 TCP 数据接收回调 → 解码 → 路由分发
    this.connectionManager.setOnMessage((data: Uint8Array) => {
      this.handleReceivedData(data);
    });

    // 注册新客户端连接回调 → 广播 SYSTEM_JOIN 给所有成员
    this.connectionManager.setOnClientConnected(() => {
      this.logger.info('init: 新客户端已连接');
      this.onClientConnected();
    });

    // 注册连接状态变化回调 → 通知 UI 层
    this.connectionManager.setOnStateChange((state: ConnectionState) => {
      this.logger.info(`init: 连接状态变化 -> ${ConnectionState[state]}`);
      if (this.connectionStateCallback) {
        this.connectionStateCallback(state);
      }
    });
  }

  public getLocalDeviceId(): string {
    return this.localDeviceId;
  }

  public getLocalDeviceName(): string {
    return this.localDeviceName;
  }

  public getConnectionState(): ConnectionState {
    return this.connectionManager.getState();
  }

  public isGroupOwner(): boolean {
    return this.connectionManager.isGroupOwner();
  }

  /** 获取群组成员列表 */
  public getGroupMembers(): GroupMember[] {
    let result: GroupMember[] = [];
    for (let i: number = 0; i < this.groupMembers.length; i++) {
      result.push(this.groupMembers[i]);
    }
    return result;
  }

  /** 获取群组成员数量 */
  public getGroupMemberCount(): number {
    return this.groupMembers.length;
  }

  /** 获取群组创建时间 */
  public getGroupCreatedTime(): number {
    return this.groupCreatedTime;
  }

  /** 启动为服务端（GO 角色），绑定 TCP 监听端口 */
  public startServer(port?: number): void {
    this.logger.info(`startServer: port=${port ?? 8888}`);
    this.connectionManager.startServer(port);
    this.groupCreatedTime = Date.now();
    this.addGroupMember(this.localDeviceId, this.localDeviceName, true);
  }

  /** 连接到服务端（GC 角色） */
  public connect(host: string, port?: number): void {
    this.logger.info(`connect: host=${host}, port=${port ?? 8888}`);
    this.connectionManager.connect(host, port);
  }

  /**
   * 发送消息
   * 1. 序列化为协议 JSON
   * 2. 构建长度前缀帧
   * 3. 通过 TCP 发送
   * 4. 持久化到本地数据库
   * 5. 更新会话记录
   */
  public async sendMessage(message: MessageModel): Promise<void> {
    let jsonStr: string = message.toProtocolJson();
    let data: Uint8Array = ProtocolDecoder.stringToUint8Array(jsonStr);
    this.logger.info(`sendMessage: type=${MessageType[message.type]}, to=${message.receiverId}`);

    this.connectionManager.send(data, (err: Error | null) => {
      if (err) {
        message.status = MessageStatus.FAILED;
        this.logger.error('sendMessage: 发送失败', err);
      } else {
        message.status = MessageStatus.DELIVERED;
      }
      if (this.messageStatusCallback) {
        this.messageStatusCallback(message);
      }
    });

    await this.messageRepository.saveMessage(message);
    await this.updateSession(message);
  }

  /** UI 层注册新消息回调（ViewModel 在进入聊天页时注册） */
  public onNewMessage(callback: (message: MessageModel) => void): void {
    this.newMessageCallback = callback;
  }

  /** UI 层注册消息状态变更回调 */
  public onMessageStatusChanged(callback: (message: MessageModel) => void): void {
    this.messageStatusCallback = callback;
  }

  /** UI 层注册连接状态变更回调 */
  public onConnectionStateChanged(callback: (state: ConnectionState) => void): void {
    this.connectionStateCallback = callback;
  }

  /**
   * 当有新 TCP 客户端连接时调用（仅 GO 端）
   * 广播一条系统消息告知所有成员
   */
  private onClientConnected(): void {
    this.logger.info('onClientConnected: 广播群组状态');
    let joinMsg: MessageModel = new MessageModel();
    joinMsg.type = MessageType.SYSTEM_JOIN;
    joinMsg.content = this.localDeviceName + ' 已在群组中';
    joinMsg.senderId = this.localDeviceId;
    joinMsg.senderName = this.localDeviceName;
    joinMsg.receiverId = 'GROUP';
    joinMsg.sessionId = 'group_' + this.localDeviceId;
    joinMsg.isLocal = true;
    joinMsg.status = MessageStatus.DELIVERED;
    this.sendMessage(joinMsg);
  }

  /**
   * 创建 1-on-1 单聊会话
   * @returns 会话 ID（即对方设备 ID）
   */
  public async createSingleSession(peerId: string, peerName: string): Promise<string> {
    this.logger.info(`createSingleSession: peerId=${peerId}, peerName=${peerName}`);
    let session: SessionModel = new SessionModel();
    session.sessionId = peerId;
    session.sessionType = 1; // 单聊
    session.peerId = peerId;
    session.peerName = peerName;
    session.lastMessage = '已建立连接';
    session.lastMessageTime = Date.now();
    session.unreadCount = 0;
    await this.sessionRepository.saveSession(session);
    return peerId;
  }

  // =================== 消息处理 ===================

  /**
   * TCP 数据接收入口
   * 1. 通过 ProtocolDecoder 拆帧
   * 2. JSON 解析
   * 3. 路由分发到对应的 handler
   */
  private handleReceivedData(rawData: Uint8Array): void {
    let decoder: ProtocolDecoder = new ProtocolDecoder();
    let messages: Uint8Array[] = decoder.decode(rawData);

    for (let i: number = 0; i < messages.length; i++) {
      let msgData: Uint8Array = messages[i];
      let jsonStr: string = ProtocolDecoder.uint8ArrayToString(msgData);
      try {
        let parsed: Record<string, Object> = JSON.parse(jsonStr);
        let payloadObj: Record<string, Object> = parsed.payload as Record<string, Object>;
        let protocolMsg: ProtocolMessage = {
          version: parsed.version as string,
          type: parsed.type as string,
          from: parsed.from as string,
          fromName: parsed.fromName as string,
          to: parsed.to as string,
          timestamp: parsed.timestamp as number,
          payload: {
            content: payloadObj.content as string,
            fileName: payloadObj.fileName as string,
            fileSize: payloadObj.fileSize as number,
            fileMd5: payloadObj.fileMd5 as string
          }
        };
        this.logger.info(`handleReceivedData: type=${protocolMsg.type}, from=${protocolMsg.fromName}`);
        this.routeMessage(protocolMsg);
      } catch (e) {
        this.logger.error('handleReceivedData: JSON 解析失败');
      }
    }
  }

  /** 消息路由：根据 type 字段分发给不同的 handler */
  private async routeMessage(protocolMsg: ProtocolMessage): Promise<void> {
    let type: string = protocolMsg.type;
    let from: string = protocolMsg.from;

    // 忽略自己发送的消息（已通过本地 sendMessage 处理）
    if (from === this.localDeviceId) {
      return;
    }

    if (type === 'TEXT') {
      await this.handleTextMessage(protocolMsg);
    } else if (type === 'IMAGE') {
      await this.handleImageMessage(protocolMsg);
    } else if (type === 'SYSTEM_JOIN') {
      this.handleSystemJoin(protocolMsg);
    } else if (type === 'SYSTEM_LEAVE') {
      this.handleSystemLeave(protocolMsg);
    }
  }

  /** 处理文本消息：创建 MessageModel → 持久化 → 更新会话 → 通知 UI */
  private async handleTextMessage(msg: ProtocolMessage): Promise<void> {
    let sessionId: string = msg.to === 'GROUP' ? 'group_' + this.localDeviceId : msg.from;
    let content: string = msg.payload.content ?? '';

    let message: MessageModel = new MessageModel();
    message.messageId = `${msg.timestamp}_${msg.from}`;
    message.sessionId = sessionId;
    message.type = MessageType.TEXT;
    message.content = content;
    message.senderId = msg.from;
    message.senderName = msg.fromName;
    message.receiverId = msg.to;
    message.timestamp = msg.timestamp;
    message.isLocal = false;
    message.status = MessageStatus.DELIVERED;

    await this.messageRepository.saveMessage(message);
    await this.updateSession(message);

    if (this.newMessageCallback) {
      this.newMessageCallback(message);
    }
  }

  /** 处理图片消息：创建包含文件元数据的 MessageModel */
  private async handleImageMessage(msg: ProtocolMessage): Promise<void> {
    let sessionId: string = msg.to === 'GROUP' ? 'group_' + this.localDeviceId : msg.from;
    let fileName: string = msg.payload.fileName ?? 'image.jpg';
    let fileSize: number = msg.payload.fileSize ?? 0;
    let fileMd5: string = msg.payload.fileMd5 ?? '';

    let message: MessageModel = new MessageModel();
    message.messageId = `${msg.timestamp}_${msg.from}`;
    message.sessionId = sessionId;
    message.type = MessageType.IMAGE;
    message.content = '[图片] ' + fileName;
    message.senderId = msg.from;
    message.senderName = msg.fromName;
    message.receiverId = msg.to;
    message.timestamp = msg.timestamp;
    message.isLocal = false;
    message.status = MessageStatus.DELIVERED;
    message.imagePath = fileName;
    message.imageSize = fileSize;
    message.imageMd5 = fileMd5;

    await this.messageRepository.saveMessage(message);
    await this.updateSession(message);

    if (this.newMessageCallback) {
      this.newMessageCallback(message);
    }
  }

  /** 处理成员加入系统消息：添加到群组成员列表 → 通知 UI */
  private handleSystemJoin(msg: ProtocolMessage): void {
    this.logger.info(`handleSystemJoin: ${msg.fromName} 加入群聊`);
    this.addGroupMember(msg.from, msg.fromName, false);

    let message: MessageModel = new MessageModel();
    message.messageId = `sys_join_${Date.now()}_${msg.from}`;
    message.sessionId = 'group_' + this.localDeviceId;
    message.type = MessageType.SYSTEM_JOIN;
    message.content = msg.fromName + ' 加入了群聊';
    message.senderId = msg.from;
    message.senderName = msg.fromName;
    message.receiverId = 'GROUP';
    message.isLocal = false;
    message.status = MessageStatus.DELIVERED;

    if (this.newMessageCallback) {
      this.newMessageCallback(message);
    }
  }

  /** 处理成员离开系统消息：从群组成员列表移除 → 通知 UI */
  private handleSystemLeave(msg: ProtocolMessage): void {
    this.logger.info(`handleSystemLeave: ${msg.fromName} 离开群聊`);
    this.removeGroupMember(msg.from);

    let message: MessageModel = new MessageModel();
    message.messageId = `sys_leave_${Date.now()}_${msg.from}`;
    message.sessionId = 'group_' + this.localDeviceId;
    message.type = MessageType.SYSTEM_LEAVE;
    message.content = msg.fromName + ' 离开了群聊';
    message.senderId = msg.from;
    message.senderName = msg.fromName;
    message.receiverId = 'GROUP';
    message.isLocal = false;
    message.status = MessageStatus.DELIVERED;

    if (this.newMessageCallback) {
      this.newMessageCallback(message);
    }
  }

  // =================== 群组成员管理 ===================

  /** 添加群组成员（去重） */
  private addGroupMember(id: string, name: string, isOwner: boolean): void {
    let exists: boolean = false;
    for (let i: number = 0; i < this.groupMembers.length; i++) {
      if (this.groupMembers[i].deviceId === id) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      this.logger.info(`addGroupMember: id=${id}, name=${name}, isOwner=${isOwner}`);
      let member: GroupMember = new GroupMember(id, name, isOwner, true);
      let newArr: GroupMember[] = new Array(this.groupMembers.length + 1);
      for (let i: number = 0; i < this.groupMembers.length; i++) {
        newArr[i] = this.groupMembers[i];
      }
      newArr[this.groupMembers.length] = member;
      this.groupMembers = newArr;
    }
  }

  /** 移除群组成员 */
  private removeGroupMember(id: string): void {
    this.logger.info(`removeGroupMember: id=${id}`);
    let newArr: GroupMember[] = [];
    for (let i: number = 0; i < this.groupMembers.length; i++) {
      if (this.groupMembers[i].deviceId !== id) {
        newArr.push(this.groupMembers[i]);
      }
    }
    this.groupMembers = newArr;
  }

  // =================== 会话管理 ===================

  /**
   * 更新或创建会话记录
   * - 已存在的会话：更新最后一条消息和时间戳，未读+1
   * - 新会话：创建并初始化
   */
  private async updateSession(message: MessageModel): Promise<void> {
    let sessionId: string = message.sessionId;
    let existing: SessionModel | null = await this.sessionRepository.getSessionById(sessionId);

    if (existing) {
      existing.lastMessage = message.content;
      existing.lastMessageTime = message.timestamp;
      if (!message.isLocal) {
        existing.unreadCount += 1;
      }
      await this.sessionRepository.saveSession(existing);
    } else {
      let session: SessionModel = new SessionModel();
      session.sessionId = sessionId;
      session.sessionType = message.receiverId === 'GROUP' ? 2 : 1;
      session.peerId = message.receiverId === 'GROUP' ? 'GROUP' : message.senderId;
      session.peerName = message.senderName;
      session.lastMessage = message.content;
      session.lastMessageTime = message.timestamp;
      session.unreadCount = message.isLocal ? 0 : 1;
      await this.sessionRepository.saveSession(session);
    }
  }

  /** 断开连接并清理所有状态 */
  public disconnect(): void {
    this.logger.info('disconnect: 断开连接');
    this.connectionManager.disconnect();
    this.groupMembers = [];
    this.groupCreatedTime = 0;
    if (this.reconnectTimer !== -1) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = -1;
    }
  }
}
