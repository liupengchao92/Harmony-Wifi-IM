import { TcpConnectionManager, ConnectionState } from '../common/network/TcpConnectionManager';
import { ProtocolDecoder } from '../common/network/ProtocolDecoder';
import { MessageModel, MessageType, MessageStatus } from './MessageModel';
import { SessionModel } from './SessionModel';
import { MessageRepository } from '../common/database/MessageRepository';
import { SessionRepository } from '../common/database/SessionRepository';

interface MessagePayload {
  content?: string;
  fileName?: string;
  fileSize?: number;
  fileMd5?: string;
}

interface ProtocolMessage {
  version: string;
  type: string;
  from: string;
  fromName: string;
  to: string;
  timestamp: number;
  payload: MessagePayload;
}

export class IMManager {
  private static instance: IMManager;
  private connectionManager: TcpConnectionManager = TcpConnectionManager.getInstance();
  private localDeviceId: string = '';
  private localDeviceName: string = '';
  private messageRepository: MessageRepository = new MessageRepository();
  private sessionRepository: SessionRepository = new SessionRepository();
  private newMessageCallback: ((message: MessageModel) => void) | null = null;
  private messageStatusCallback: ((message: MessageModel) => void) | null = null;
  private groupMemberSet: string[] = [];
  private reconnectTimer: number = -1;

  public static getInstance(): IMManager {
    if (!IMManager.instance) {
      IMManager.instance = new IMManager();
    }
    return IMManager.instance;
  }

  public init(deviceId: string, deviceName: string): void {
    this.localDeviceId = deviceId;
    this.localDeviceName = deviceName;
    this.connectionManager.setOnMessage((data: Uint8Array) => {
      this.handleReceivedData(data);
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

  public getGroupMembers(): string[] {
    let result: string[] = [];
    for (let i = 0; i < this.groupMemberSet.length; i++) {
      result.push(this.groupMemberSet[i]);
    }
    return result;
  }

  public startServer(port?: number): void {
    this.connectionManager.startServer(port);
    this.addGroupMember(this.localDeviceId);
  }

  public connect(host: string, port?: number): void {
    this.connectionManager.connect(host, port);
  }

  public async sendMessage(message: MessageModel): Promise<void> {
    let jsonStr = message.toProtocolJson();
    let data = ProtocolDecoder.stringToUint8Array(jsonStr);
    this.connectionManager.send(data, (err: Error | null) => {
      if (err) {
        message.status = MessageStatus.FAILED;
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

  public onNewMessage(callback: (message: MessageModel) => void): void {
    this.newMessageCallback = callback;
  }

  public onMessageStatusChanged(callback: (message: MessageModel) => void): void {
    this.messageStatusCallback = callback;
  }

  private handleReceivedData(rawData: Uint8Array): void {
    let decoder = new ProtocolDecoder();
    let messages = decoder.decode(rawData);
    for (let i = 0; i < messages.length; i++) {
      let msgData = messages[i];
      let jsonStr = ProtocolDecoder.uint8ArrayToString(msgData);
      try {
        let parsed: Record<string, Object> = JSON.parse(jsonStr);
        let payloadObj = parsed.payload as Record<string, Object>;
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
        this.routeMessage(protocolMsg);
      } catch (e) {
        // parse error
      }
    }
  }

  private async routeMessage(protocolMsg: ProtocolMessage): Promise<void> {
    let type = protocolMsg.type;
    let from = protocolMsg.from;
    let fromName = protocolMsg.fromName;
    let to = protocolMsg.to;
    let timestamp = protocolMsg.timestamp;
    let payload = protocolMsg.payload;

    if (from === this.localDeviceId) {
      return;
    }

    if (type === 'TEXT') {
      await this.handleTextMessage(from, fromName, to, timestamp, payload);
    } else if (type === 'IMAGE') {
      await this.handleImageMessage(from, fromName, to, timestamp, payload);
    } else if (type === 'SYSTEM_JOIN') {
      this.handleSystemJoin(from, fromName);
    } else if (type === 'SYSTEM_LEAVE') {
      this.handleSystemLeave(from, fromName);
    }
  }

  private async handleTextMessage(from: string, fromName: string, to: string,
    timestamp: number, payload: MessagePayload): Promise<void> {
    let sessionId = to === 'GROUP' ? 'group_' + this.localDeviceId : from;
    let content = payload.content ?? '';
    let message = new MessageModel();
    message.messageId = `${timestamp}_${from}`;
    message.sessionId = sessionId;
    message.type = MessageType.TEXT;
    message.content = content;
    message.senderId = from;
    message.senderName = fromName;
    message.receiverId = to;
    message.timestamp = timestamp;
    message.isLocal = false;
    message.status = MessageStatus.DELIVERED;
    await this.messageRepository.saveMessage(message);
    await this.updateSession(message);
    if (this.newMessageCallback) {
      this.newMessageCallback(message);
    }
  }

  private async handleImageMessage(from: string, fromName: string, to: string,
    timestamp: number, payload: MessagePayload): Promise<void> {
    let sessionId = to === 'GROUP' ? 'group_' + this.localDeviceId : from;
    let fileName = payload.fileName ?? 'image.jpg';
    let fileSize = payload.fileSize ?? 0;
    let fileMd5 = payload.fileMd5 ?? '';
    let message = new MessageModel();
    message.messageId = `${timestamp}_${from}`;
    message.sessionId = sessionId;
    message.type = MessageType.IMAGE;
    message.content = '[图片] ' + fileName;
    message.senderId = from;
    message.senderName = fromName;
    message.receiverId = to;
    message.timestamp = timestamp;
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

  private handleSystemJoin(from: string, fromName: string): void {
    this.addGroupMember(from);
    let message = new MessageModel();
    message.type = MessageType.SYSTEM_JOIN;
    message.content = fromName + ' 加入了群聊';
    message.senderId = from;
    message.senderName = fromName;
    message.receiverId = 'GROUP';
    message.isLocal = false;
    message.status = MessageStatus.DELIVERED;
    if (this.newMessageCallback) {
      this.newMessageCallback(message);
    }
  }

  private handleSystemLeave(from: string, fromName: string): void {
    this.removeGroupMember(from);
    let message = new MessageModel();
    message.type = MessageType.SYSTEM_LEAVE;
    message.content = fromName + ' 离开了群聊';
    message.senderId = from;
    message.senderName = fromName;
    message.receiverId = 'GROUP';
    message.isLocal = false;
    message.status = MessageStatus.DELIVERED;
    if (this.newMessageCallback) {
      this.newMessageCallback(message);
    }
  }

  private addGroupMember(id: string): void {
    let exists = false;
    for (let i = 0; i < this.groupMemberSet.length; i++) {
      if (this.groupMemberSet[i] === id) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      let newArr = new Array<string>(this.groupMemberSet.length + 1);
      for (let i = 0; i < this.groupMemberSet.length; i++) {
        newArr[i] = this.groupMemberSet[i];
      }
      newArr[this.groupMemberSet.length] = id;
      this.groupMemberSet = newArr;
    }
  }

  private removeGroupMember(id: string): void {
    let newArr: string[] = [];
    for (let i = 0; i < this.groupMemberSet.length; i++) {
      if (this.groupMemberSet[i] !== id) {
        newArr.push(this.groupMemberSet[i]);
      }
    }
    this.groupMemberSet = newArr;
  }

  private async updateSession(message: MessageModel): Promise<void> {
    let sessionId = message.sessionId;
    let existing = await this.sessionRepository.getSessionById(sessionId);
    if (existing) {
      existing.lastMessage = message.content;
      existing.lastMessageTime = message.timestamp;
      if (!message.isLocal) {
        existing.unreadCount += 1;
      }
      await this.sessionRepository.saveSession(existing);
    } else {
      let session = new SessionModel();
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

  public disconnect(): void {
    this.connectionManager.disconnect();
    this.groupMemberSet = [];
    if (this.reconnectTimer !== -1) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = -1;
    }
  }
}
