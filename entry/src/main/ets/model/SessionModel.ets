export class SessionModel {
  sessionId: string = '';
  sessionType: number = 1;
  peerId: string = '';
  peerName: string = '';
  lastMessage: string = '';
  lastMessageTime: number = 0;
  unreadCount: number = 0;
  memberCount: number = 0;

  constructor(data?: Partial<SessionModel>) {
    if (data) {
      this.sessionId = data.sessionId ?? this.sessionId;
      this.sessionType = data.sessionType ?? this.sessionType;
      this.peerId = data.peerId ?? this.peerId;
      this.peerName = data.peerName ?? this.peerName;
      this.lastMessage = data.lastMessage ?? this.lastMessage;
      this.lastMessageTime = data.lastMessageTime ?? this.lastMessageTime;
      this.unreadCount = data.unreadCount ?? this.unreadCount;
      this.memberCount = data.memberCount ?? this.memberCount;
    }
  }
}
