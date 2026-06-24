import { MessageModel, MessageType, MessageStatus } from '../model/MessageModel';
import { IMManager } from '../model/IMManager';
import { MessageRepository } from '../common/database/MessageRepository';
import { SessionRepository } from '../common/database/SessionRepository';

@Observed
export class ChatViewModel {
  messages: MessageModel[] = [];
  sessionId: string = '';
  sessionType: number = 1;
  peerName: string = '';
  isSending: boolean = false;
  groupMemberCount: number = 0;

  private imManager: IMManager = IMManager.getInstance();
  private messageRepository: MessageRepository = new MessageRepository();
  private sessionRepository: SessionRepository = new SessionRepository();

  public init(sessionId: string, sessionType: number, peerName: string): void {
    this.sessionId = sessionId;
    this.sessionType = sessionType;
    this.peerName = peerName;
    this.loadHistoryMessages();
    this.imManager.onNewMessage((message: MessageModel) => {
      if (message.sessionId === this.sessionId ||
        (message.receiverId === 'GROUP' && this.sessionType === 2)) {
        let newArr = new Array<MessageModel>(this.messages.length + 1);
        for (let i = 0; i < this.messages.length; i++) {
          newArr[i] = this.messages[i];
        }
        newArr[this.messages.length] = message;
        this.messages = newArr;
      }
    });
    if (sessionType === 2) {
      this.groupMemberCount = this.imManager.getGroupMembers().length;
    }
  }

  private async loadHistoryMessages(): Promise<void> {
    this.messages = await this.messageRepository.getAllMessagesBySession(this.sessionId);
  }

  public sendTextMessage(text: string): void {
    if (!text.trim()) {
      return;
    }
    let receiverId = this.sessionType === 1 ? this.sessionId : 'GROUP';
    let message = new MessageModel();
    message.type = MessageType.TEXT;
    message.content = text.trim();
    message.senderId = this.imManager.getLocalDeviceId();
    message.senderName = this.imManager.getLocalDeviceName();
    message.receiverId = receiverId;
    message.sessionId = this.sessionId;
    message.isLocal = true;
    message.status = MessageStatus.SENDING;
    let newArr = new Array<MessageModel>(this.messages.length + 1);
    for (let i = 0; i < this.messages.length; i++) {
      newArr[i] = this.messages[i];
    }
    newArr[this.messages.length] = message;
    this.messages = newArr;
    this.isSending = true;
    this.imManager.sendMessage(message);
    this.isSending = false;
  }

  public sendImageMessage(imagePath: string): void {
    let receiverId = this.sessionType === 1 ? this.sessionId : 'GROUP';
    let fileName = imagePath.split('/').pop() ?? 'image.jpg';
    let message = new MessageModel();
    message.type = MessageType.IMAGE;
    message.content = '[图片] ' + fileName;
    message.senderId = this.imManager.getLocalDeviceId();
    message.senderName = this.imManager.getLocalDeviceName();
    message.receiverId = receiverId;
    message.sessionId = this.sessionId;
    message.isLocal = true;
    message.status = MessageStatus.SENDING;
    message.imagePath = imagePath;
    message.imageSize = 0;
    let newArr = new Array<MessageModel>(this.messages.length + 1);
    for (let i = 0; i < this.messages.length; i++) {
      newArr[i] = this.messages[i];
    }
    newArr[this.messages.length] = message;
    this.messages = newArr;
    this.isSending = true;
    this.imManager.sendMessage(message);
    this.isSending = false;
  }

  public async clearUnread(): Promise<void> {
    await this.sessionRepository.clearUnread(this.sessionId);
  }

  public getLocalDeviceId(): string {
    return this.imManager.getLocalDeviceId();
  }
}
