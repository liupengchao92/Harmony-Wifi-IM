export enum MessageType {
  TEXT = 1,
  IMAGE = 2,
  SYSTEM_JOIN = 3,
  SYSTEM_LEAVE = 5,
  HEARTBEAT = 6,
  ACK = 7
}

export enum MessageStatus {
  SENDING = 0,
  DELIVERED = 1,
  FAILED = 2
}

interface MessagePayload {
  content?: string;
  fileName?: string;
  fileSize?: number;
  fileMd5?: string;
}

export class MessageModel {
  messageId: string = '';
  sessionId: string = '';
  type: MessageType = MessageType.TEXT;
  content: string = '';
  senderId: string = '';
  senderName: string = '';
  receiverId: string = '';
  timestamp: number = Date.now();
  status: MessageStatus = MessageStatus.SENDING;
  isLocal: boolean = true;
  imagePath: string = '';
  imageSize: number = 0;
  imageMd5: string = '';

  constructor(data?: Partial<MessageModel>) {
    if (data) {
      this.messageId = data.messageId ?? this.messageId;
      this.sessionId = data.sessionId ?? this.sessionId;
      this.type = data.type ?? this.type;
      this.content = data.content ?? this.content;
      this.senderId = data.senderId ?? this.senderId;
      this.senderName = data.senderName ?? this.senderName;
      this.receiverId = data.receiverId ?? this.receiverId;
      this.timestamp = data.timestamp ?? this.timestamp;
      this.status = data.status ?? this.status;
      this.isLocal = data.isLocal ?? this.isLocal;
      this.imagePath = data.imagePath ?? this.imagePath;
      this.imageSize = data.imageSize ?? this.imageSize;
      this.imageMd5 = data.imageMd5 ?? this.imageMd5;
    }
    if (!this.messageId) {
      this.messageId = this.generateMessageId();
    }
  }

  private generateMessageId(): string {
    return `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  public toProtocolJson(): string {
    let payload: MessagePayload = { content: this.content };
    if (this.type === MessageType.IMAGE) {
      payload.fileName = this.imagePath.split('/').pop() ?? 'image.jpg';
      payload.fileSize = this.imageSize;
      payload.fileMd5 = this.imageMd5;
    }
    return JSON.stringify({
      version: '1.0',
      type: MessageType[this.type],
      from: this.senderId,
      fromName: this.senderName,
      to: this.receiverId,
      timestamp: this.timestamp,
      payload: payload
    });
  }
}
