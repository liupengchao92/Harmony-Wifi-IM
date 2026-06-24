import { relationalStore } from '@kit.ArkData';

export class DatabaseHelper {
  private static instance: DatabaseHelper;
  private rdbStore: relationalStore.RdbStore | null = null;
  private readonly DB_NAME: string = 'IMDatabase.db';
  private readonly DB_VERSION: number = 1;

  public static getInstance(): DatabaseHelper {
    if (!DatabaseHelper.instance) {
      DatabaseHelper.instance = new DatabaseHelper();
    }
    return DatabaseHelper.instance;
  }

  public async init(context: Context): Promise<void> {
    if (this.rdbStore) {
      return;
    }
    let config: relationalStore.StoreConfig = {
      name: this.DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.rdbStore = await relationalStore.getRdbStore(context, config);
    await this.createTables();
  }

  private async createTables(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }
    let createMessageTable: string =
      'CREATE TABLE IF NOT EXISTS message (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'message_id TEXT UNIQUE NOT NULL, ' +
      'session_id TEXT NOT NULL, ' +
      'type INTEGER NOT NULL, ' +
      'content TEXT, ' +
      'sender_id TEXT NOT NULL, ' +
      'sender_name TEXT, ' +
      'receiver_id TEXT NOT NULL, ' +
      'timestamp INTEGER NOT NULL, ' +
      'status INTEGER DEFAULT 0, ' +
      'is_local INTEGER DEFAULT 1, ' +
      'image_path TEXT, ' +
      'image_size INTEGER DEFAULT 0' +
      ')';
    await this.rdbStore.executeSql(createMessageTable);

    let createSessionTable: string =
      'CREATE TABLE IF NOT EXISTS session (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'session_id TEXT UNIQUE NOT NULL, ' +
      'session_type INTEGER NOT NULL, ' +
      'peer_id TEXT NOT NULL, ' +
      'peer_name TEXT, ' +
      'last_message TEXT, ' +
      'last_message_time INTEGER, ' +
      'unread_count INTEGER DEFAULT 0, ' +
      'member_count INTEGER DEFAULT 0' +
      ')';
    await this.rdbStore.executeSql(createSessionTable);

    await this.rdbStore.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_message_session ON message(session_id)'
    );
    await this.rdbStore.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_message_time ON message(timestamp)'
    );
  }

  public getStore(): relationalStore.RdbStore | null {
    return this.rdbStore;
  }
}
