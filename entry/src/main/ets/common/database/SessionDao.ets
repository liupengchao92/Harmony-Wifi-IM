import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from './DatabaseHelper';
import { SessionModel } from '../../model/SessionModel';

export class SessionDao {
  private getStore(): relationalStore.RdbStore | null {
    return DatabaseHelper.getInstance().getStore();
  }

  public async insert(session: SessionModel): Promise<void> {
    let store = this.getStore();
    if (!store) {
      return;
    }
    let values: relationalStore.ValuesBucket = {
      'session_id': session.sessionId,
      'session_type': session.sessionType,
      'peer_id': session.peerId,
      'peer_name': session.peerName,
      'last_message': session.lastMessage,
      'last_message_time': session.lastMessageTime,
      'unread_count': session.unreadCount,
      'member_count': session.memberCount
    };
    await store.insert('session', values);
  }

  public async update(session: SessionModel): Promise<void> {
    let store = this.getStore();
    if (!store) {
      return;
    }
    let predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('session_id', session.sessionId);
    let values: relationalStore.ValuesBucket = {
      'session_type': session.sessionType,
      'peer_id': session.peerId,
      'peer_name': session.peerName,
      'last_message': session.lastMessage,
      'last_message_time': session.lastMessageTime,
      'unread_count': session.unreadCount,
      'member_count': session.memberCount
    };
    await store.update(values, predicates);
  }

  public async getAll(): Promise<SessionModel[]> {
    let store = this.getStore();
    if (!store) {
      return [];
    }
    let predicates = new relationalStore.RdbPredicates('session');
    predicates.orderByDesc('last_message_time');
    let columns: string[] = ['session_id', 'session_type',
      'peer_id', 'peer_name', 'last_message', 'last_message_time',
      'unread_count', 'member_count'];
    let resultSet = await store.query(predicates, columns);
    let sessions: SessionModel[] = [];
    while (resultSet.goToNextRow()) {
      let session = this.parseSession(resultSet);
      sessions.push(session);
    }
    resultSet.close();
    return sessions;
  }

  public async getById(sessionId: string): Promise<SessionModel | null> {
    let store = this.getStore();
    if (!store) {
      return null;
    }
    let predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('session_id', sessionId);
    let columns: string[] = ['session_id', 'session_type',
      'peer_id', 'peer_name', 'last_message', 'last_message_time',
      'unread_count', 'member_count'];
    let resultSet = await store.query(predicates, columns);
    let session: SessionModel | null = null;
    if (resultSet.goToFirstRow()) {
      session = this.parseSession(resultSet);
    }
    resultSet.close();
    return session;
  }

  public async clearUnread(sessionId: string): Promise<void> {
    let store = this.getStore();
    if (!store) {
      return;
    }
    let predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('session_id', sessionId);
    let values: relationalStore.ValuesBucket = { 'unread_count': 0 };
    await store.update(values, predicates);
  }

  public async delete(sessionId: string): Promise<void> {
    let store = this.getStore();
    if (!store) {
      return;
    }
    let predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('session_id', sessionId);
    await store.delete(predicates);
  }

  public async upsert(session: SessionModel): Promise<void> {
    let existing = await this.getById(session.sessionId);
    if (existing) {
      await this.update(session);
    } else {
      await this.insert(session);
    }
  }

  private parseSession(rs: relationalStore.ResultSet): SessionModel {
    let sessionId = rs.getString(rs.getColumnIndex('session_id'));
    let sessionType = rs.getLong(rs.getColumnIndex('session_type'));
    let peerId = rs.getString(rs.getColumnIndex('peer_id'));
    let peerName = rs.getString(rs.getColumnIndex('peer_name'));
    let lastMessage = rs.getString(rs.getColumnIndex('last_message'));
    let lastMessageTime = rs.getLong(rs.getColumnIndex('last_message_time'));
    let unreadCount = rs.getLong(rs.getColumnIndex('unread_count'));
    let memberCount = rs.getLong(rs.getColumnIndex('member_count'));
    let session = new SessionModel();
    session.sessionId = sessionId;
    session.sessionType = sessionType;
    session.peerId = peerId;
    session.peerName = peerName;
    session.lastMessage = lastMessage;
    session.lastMessageTime = lastMessageTime;
    session.unreadCount = unreadCount;
    session.memberCount = memberCount;
    return session;
  }
}
