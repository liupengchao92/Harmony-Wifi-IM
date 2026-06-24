import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from './DatabaseHelper';
import { MessageModel, MessageType, MessageStatus } from '../../model/MessageModel';

export class MessageDao {
  private getStore(): relationalStore.RdbStore | null {
    return DatabaseHelper.getInstance().getStore();
  }

  public async insert(message: MessageModel): Promise<void> {
    let store = this.getStore();
    if (!store) {
      return;
    }
    let values: relationalStore.ValuesBucket = {
      'message_id': message.messageId,
      'session_id': message.sessionId,
      'type': message.type,
      'content': message.content,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'receiver_id': message.receiverId,
      'timestamp': message.timestamp,
      'status': message.status,
      'is_local': message.isLocal ? 1 : 0,
      'image_path': message.imagePath,
      'image_size': message.imageSize
    };
    await store.insert('message', values);
  }

  public async getBySessionId(sessionId: string, limit: number, offset: number): Promise<MessageModel[]> {
    let store = this.getStore();
    if (!store) {
      return [];
    }
    let predicates = new relationalStore.RdbPredicates('message');
    predicates.equalTo('session_id', sessionId);
    predicates.orderByDesc('timestamp');
    let columns: string[] = ['message_id', 'session_id', 'type',
      'content', 'sender_id', 'sender_name', 'receiver_id', 'timestamp', 'status',
      'is_local', 'image_path', 'image_size'];
    let resultSet = await store.query(predicates, columns);
    let messages: MessageModel[] = [];
    while (resultSet.goToNextRow()) {
      let msg = this.parseMessage(resultSet);
      messages.push(msg);
    }
    resultSet.close();
    return messages.reverse();
  }

  public async getAllBySessionId(sessionId: string): Promise<MessageModel[]> {
    let store = this.getStore();
    if (!store) {
      return [];
    }
    let predicates = new relationalStore.RdbPredicates('message');
    predicates.equalTo('session_id', sessionId);
    predicates.orderByAsc('timestamp');
    let columns: string[] = ['message_id', 'session_id', 'type',
      'content', 'sender_id', 'sender_name', 'receiver_id', 'timestamp', 'status',
      'is_local', 'image_path', 'image_size'];
    let resultSet = await store.query(predicates, columns);
    let messages: MessageModel[] = [];
    while (resultSet.goToNextRow()) {
      let msg = this.parseMessage(resultSet);
      messages.push(msg);
    }
    resultSet.close();
    return messages;
  }

  public async updateStatus(messageId: string, status: MessageStatus): Promise<void> {
    let store = this.getStore();
    if (!store) {
      return;
    }
    let predicates = new relationalStore.RdbPredicates('message');
    predicates.equalTo('message_id', messageId);
    let values: relationalStore.ValuesBucket = { 'status': status };
    await store.update(values, predicates);
  }

  public async deleteBySessionId(sessionId: string): Promise<void> {
    let store = this.getStore();
    if (!store) {
      return;
    }
    let predicates = new relationalStore.RdbPredicates('message');
    predicates.equalTo('session_id', sessionId);
    await store.delete(predicates);
  }

  private parseMessage(rs: relationalStore.ResultSet): MessageModel {
    let mid = rs.getString(rs.getColumnIndex('message_id'));
    let sid = rs.getString(rs.getColumnIndex('session_id'));
    let typeVal = rs.getLong(rs.getColumnIndex('type'));
    let content = rs.getString(rs.getColumnIndex('content'));
    let senderId = rs.getString(rs.getColumnIndex('sender_id'));
    let senderName = rs.getString(rs.getColumnIndex('sender_name'));
    let receiverId = rs.getString(rs.getColumnIndex('receiver_id'));
    let timestamp = rs.getLong(rs.getColumnIndex('timestamp'));
    let statusVal = rs.getLong(rs.getColumnIndex('status'));
    let isLocalVal = rs.getLong(rs.getColumnIndex('is_local'));
    let imagePath = rs.getString(rs.getColumnIndex('image_path'));
    let imageSize = rs.getLong(rs.getColumnIndex('image_size'));
    let msg = new MessageModel();
    msg.messageId = mid;
    msg.sessionId = sid;
    msg.type = typeVal as MessageType;
    msg.content = content;
    msg.senderId = senderId;
    msg.senderName = senderName;
    msg.receiverId = receiverId;
    msg.timestamp = timestamp;
    msg.status = statusVal as MessageStatus;
    msg.isLocal = isLocalVal === 1;
    msg.imagePath = imagePath;
    msg.imageSize = imageSize;
    return msg;
  }
}
