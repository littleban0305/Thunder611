const fs = require('fs');
const path = require('path');

let SQL = null;
let db = null;
let dbFile = null;

async function initStorage(dataDir) {
  const initSqlJs = require('sql.js');
  fs.mkdirSync(dataDir, { recursive: true });
  dbFile = path.join(dataDir, 'thunder611.sqlite');

  SQL = await initSqlJs({
    locateFile: (file) => require.resolve(`sql.js/dist/${file}`),
  });

  if (fs.existsSync(dbFile)) {
    db = new SQL.Database(fs.readFileSync(dbFile));
  } else {
    db = new SQL.Database();
  }

  db.run(`
    PRAGMA foreign_keys = ON;

    CREATE TABLE IF NOT EXISTS users (
      username TEXT PRIMARY KEY,
      salt TEXT NOT NULL,
      hash TEXT NOT NULL,
      coins INTEGER NOT NULL DEFAULT 1250,
      wins INTEGER NOT NULL DEFAULT 0,
      role TEXT NOT NULL DEFAULT 'member',
      banned INTEGER NOT NULL DEFAULT 0,
      avatar_url TEXT,
      created_at TEXT NOT NULL,
      last_seen TEXT
    );

    CREATE TABLE IF NOT EXISTS inventory (
      username TEXT NOT NULL,
      item_id TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (username, item_id),
      FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS lobby_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sender TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS private_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sender TEXT NOT NULL,
      target TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL,
      kind TEXT NOT NULL,
      amount INTEGER NOT NULL,
      balance INTEGER NOT NULL,
      meta TEXT,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS daily_claims (
      username TEXT NOT NULL,
      claim_date TEXT NOT NULL,
      PRIMARY KEY (username, claim_date),
      FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS friendships (
      username TEXT NOT NULL,
      friend TEXT NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (username, friend),
      FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE,
      FOREIGN KEY (friend) REFERENCES users(username) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS friend_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sender TEXT NOT NULL,
      target TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT NOT NULL,
      responded_at TEXT,
      UNIQUE(sender, target, status)
    );

    CREATE TABLE IF NOT EXISTS announcements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS game_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL,
      game_id TEXT NOT NULL,
      result TEXT NOT NULL,
      reward INTEGER NOT NULL DEFAULT 0,
      meta TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL,
      type TEXT NOT NULL,
      payload TEXT NOT NULL,
      read INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS memories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uploader TEXT NOT NULL,
      kind TEXT NOT NULL,
      url TEXT NOT NULL,
      caption TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      FOREIGN KEY (uploader) REFERENCES users(username) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS voice_room_defs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      locked INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS chat_rooms (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_by TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (created_by) REFERENCES users(username) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS chat_room_members (
      room_id TEXT NOT NULL,
      username TEXT NOT NULL,
      joined_at TEXT NOT NULL,
      PRIMARY KEY (room_id, username),
      FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE,
      FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS chat_room_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id TEXT NOT NULL,
      sender TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at TEXT NOT NULL,
      client_id TEXT,
      kind TEXT NOT NULL DEFAULT 'text',
      payload TEXT NOT NULL DEFAULT '{}',
      edited INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE
    );
  `);

  ensureColumn('users', 'role', "TEXT NOT NULL DEFAULT 'member'");
  ensureColumn('users', 'banned', "INTEGER NOT NULL DEFAULT 0");
  ensureColumn('users', 'avatar_url', 'TEXT');
  ensureColumn('lobby_messages', 'kind', "TEXT NOT NULL DEFAULT 'text'");
  ensureColumn('lobby_messages', 'payload', "TEXT NOT NULL DEFAULT '{}'");
  ensureColumn('private_messages', 'kind', "TEXT NOT NULL DEFAULT 'text'");
  ensureColumn('private_messages', 'payload', "TEXT NOT NULL DEFAULT '{}'");
  ensureColumn('lobby_messages', 'edited', "INTEGER NOT NULL DEFAULT 0");
  ensureColumn('private_messages', 'edited', "INTEGER NOT NULL DEFAULT 0");
  ensureColumn('chat_room_messages', 'edited', "INTEGER NOT NULL DEFAULT 0");


  const defaults = [
    ['lobby', '大廳'],
    ['chill', '聊天房'],
    ['game', '遊戲房'],
  ];
  defaults.forEach(([id, name]) => {
    run('INSERT OR IGNORE INTO voice_room_defs(id, name, locked, created_at) VALUES (?, ?, 0, ?)', [id, name, new Date().toISOString()]);
  });

  migrateLegacyUsers(dataDir);

  const chatDefaults = [
    ['chat', '聊天房'],
    ['game', '遊戲房'],
  ];
  const firstUser = get('SELECT username FROM users ORDER BY created_at ASC LIMIT 1');
  if (firstUser?.username) {
    for (const [id, name] of chatDefaults) {
      run('INSERT OR IGNORE INTO chat_rooms(id, name, created_by, created_at) VALUES (?, ?, ?, ?)', [id, name, firstUser.username, new Date().toISOString()]);
    }
    const rooms = query('SELECT id FROM chat_rooms');
    const users = query('SELECT username FROM users');
    const stmt = db.prepare('INSERT OR IGNORE INTO chat_room_members(room_id, username, joined_at) VALUES (?, ?, ?)');
    const now = new Date().toISOString();
    for (const room of rooms) {
      for (const u of users) stmt.run([room.id, u.username, now]);
    }
    stmt.free();
    persist();
  }
  const adminCount = Number(get("SELECT COUNT(*) AS count FROM users WHERE role = 'admin'")?.count || 0);
  if (adminCount === 0) {
    const first = get('SELECT username FROM users ORDER BY created_at ASC LIMIT 1');
    if (first?.username) run("UPDATE users SET role = 'admin' WHERE username = ?", [first.username]);
  }
  persist();
}

function ensureColumn(table, column, definition) {
  const cols = query(`PRAGMA table_info(${table})`);
  if (!cols.some((c) => c.name === column)) db.run(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
}

function migrateLegacyUsers(dataDir) {
  const legacy = path.join(dataDir, 'users.json');
  if (!fs.existsSync(legacy)) return;

  let users = {};
  try { users = JSON.parse(fs.readFileSync(legacy, 'utf8')); } catch { return; }

  const existing = db.exec('SELECT COUNT(*) AS count FROM users');
  const count = existing[0]?.values?.[0]?.[0] ?? 0;
  if (count > 0) return;

  const now = new Date().toISOString();
  const stmt = db.prepare(`
    INSERT OR IGNORE INTO users(username, salt, hash, coins, wins, created_at, last_seen)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);

  for (const [username, user] of Object.entries(users)) {
    stmt.run([
      username,
      String(user.salt || ''),
      String(user.hash || ''),
      Number(user.coins ?? 1250),
      Number(user.wins ?? 0),
      now,
      now,
    ]);
  }
  stmt.free();
}

function persist() {
  if (!db || !dbFile) return;
  const data = db.export();
  fs.writeFileSync(dbFile, Buffer.from(data));
}

function query(sql, params = []) {
  const stmt = db.prepare(sql);
  stmt.bind(params);
  const rows = [];
  while (stmt.step()) {
    const row = stmt.getAsObject();
    rows.push(row);
  }
  stmt.free();
  return rows;
}

function get(sql, params = []) {
  return query(sql, params)[0] || null;
}

function run(sql, params = []) {
  const stmt = db.prepare(sql);
  stmt.run(params);
  stmt.free();
  persist();
}

function transaction(callback) {
  db.run('BEGIN');
  try {
    const result = callback();
    db.run('COMMIT');
    persist();
    return result;
  } catch (error) {
    try { db.run('ROLLBACK'); } catch {}
    throw error;
  }
}

function user(username) {
  return get('SELECT username, coins, wins, role, banned, avatar_url, created_at, last_seen FROM users WHERE username = ?', [username]);
}

function fullProfile(username) {
  const profile = user(username);
  if (!profile) return null;
  const inventory = query(
    'SELECT item_id, quantity FROM inventory WHERE username = ? AND quantity > 0',
    [username]
  );
  return {
    coins: Number(profile.coins || 0),
    wins: Number(profile.wins || 0),
    inventory: Object.fromEntries(inventory.map((row) => [row.item_id, Number(row.quantity)])),
    role: profile.role || 'member',
    banned: Number(profile.banned || 0) === 1,
    avatarUrl: profile.avatar_url || '',
  };
}

function setLastSeen(username) {
  run('UPDATE users SET last_seen = ? WHERE username = ?', [new Date().toISOString(), username]);
}

function addCoins(username, amount, kind = 'unknown', meta = {}) {
  return transaction(() => {
    const current = get('SELECT coins FROM users WHERE username = ?', [username]);
    if (!current) throw new Error('user_not_found');
    const balance = Number(current.coins) + Number(amount);
    if (balance < 0) throw new Error('insufficient_coins');

    {
      const stmt = db.prepare('UPDATE users SET coins = ? WHERE username = ?');
      stmt.run([balance, username]);
      stmt.free();
    }
    {
      const stmt = db.prepare(`
        INSERT INTO transactions(username, kind, amount, balance, meta, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `);
      stmt.run([
        username,
        kind,
        Number(amount),
        balance,
        JSON.stringify(meta),
        new Date().toISOString(),
      ]);
      stmt.free();
    }

    return balance;
  });
}

function buyItem(username, itemId, cost) {
  return transaction(() => {
    const current = get('SELECT coins FROM users WHERE username = ?', [username]);
    if (!current) throw new Error('user_not_found');
    const coins = Number(current.coins);
    if (coins < cost) throw new Error('insufficient_coins');
    const balance = coins - cost;

    {
      const stmt = db.prepare('UPDATE users SET coins = ? WHERE username = ?');
      stmt.run([balance, username]);
      stmt.free();
    }
    {
      const stmt = db.prepare(`
        INSERT INTO inventory(username, item_id, quantity) VALUES (?, ?, 1)
        ON CONFLICT(username, item_id) DO UPDATE SET quantity = quantity + 1
      `);
      stmt.run([username, itemId]);
      stmt.free();
    }
    {
      const stmt = db.prepare(`
        INSERT INTO transactions(username, kind, amount, balance, meta, created_at)
        VALUES (?, 'shop.buy', ?, ?, ?, ?)
      `);
      stmt.run([
        username,
        -cost,
        balance,
        JSON.stringify({ itemId }),
        new Date().toISOString(),
      ]);
      stmt.free();
    }

    return fullProfile(username);
  });
}

function claimDaily(username) {
  const date = new Date().toISOString().slice(0, 10);
  return transaction(() => {
    const already = get(
      'SELECT username FROM daily_claims WHERE username = ? AND claim_date = ?',
      [username, date]
    );
    if (already) return { claimed: false, profile: fullProfile(username) };

    {
      const stmt = db.prepare('INSERT INTO daily_claims(username, claim_date) VALUES (?, ?)');
      stmt.run([username, date]);
      stmt.free();
    }

    const current = get('SELECT coins FROM users WHERE username = ?', [username]);
    const balance = Number(current.coins) + 10;
    {
      const stmt = db.prepare('UPDATE users SET coins = ? WHERE username = ?');
      stmt.run([balance, username]);
      stmt.free();
    }
    {
      const stmt = db.prepare(`
        INSERT INTO transactions(username, kind, amount, balance, meta, created_at)
        VALUES (?, 'daily', 10, ?, '{}', ?)
      `);
      stmt.run([username, balance, new Date().toISOString()]);
      stmt.free();
    }

    return { claimed: true, profile: fullProfile(username) };
  });
}

function insertLobbyMessage(sender, text, createdAt, clientId, kind = 'text', payload = {}) {
  return transaction(() => {
    const stmt = db.prepare(`
      INSERT INTO lobby_messages(sender, text, created_at, kind, payload)
      VALUES (?, ?, ?, ?, ?)
    `);
    stmt.run([sender, text, createdAt, kind, JSON.stringify(payload || {})]);
    stmt.free();
    const row = get('SELECT last_insert_rowid() AS id');
    return { id: Number(row.id), sender, text, time: formatTime(createdAt), clientId: clientId || null, kind, payload: payload || {} };
  });
}

function insertPrivateMessage(sender, target, text, createdAt, clientId, kind = 'text', payload = {}) {
  return transaction(() => {
    const stmt = db.prepare(`
      INSERT INTO private_messages(sender, target, text, created_at, kind, payload)
      VALUES (?, ?, ?, ?, ?, ?)
    `);
    stmt.run([sender, target, text, createdAt, kind, JSON.stringify(payload || {})]);
    stmt.free();
    const row = get('SELECT last_insert_rowid() AS id');
    return { id: Number(row.id), sender, target, text, time: formatTime(createdAt), clientId: clientId || null, kind, payload: payload || {} };
  });
}

function parsePayload(value) { try { return value ? JSON.parse(value) : {}; } catch { return {}; } }

function lobbyHistory(limit = 100) {
  return query(`
    SELECT id, sender, text, created_at, kind, payload, edited
    FROM lobby_messages
    ORDER BY id DESC
    LIMIT ?
  `, [limit]).reverse().map((row) => {
    const payload = parsePayload(row.payload);
    payload.id = Number(row.id);
    if (Number(row.edited) === 1) payload.edited = true;
    return {
      id: Number(row.id),
      sender: row.sender,
      text: row.text,
      time: formatTime(row.created_at),
      kind: row.kind || 'text',
      payload,
    };
  });
}

function privateHistory(username, other, limit = 100) {
  return query(`
    SELECT id, sender, target, text, created_at, kind, payload, edited
    FROM private_messages
    WHERE (sender = ? AND target = ?) OR (sender = ? AND target = ?)
    ORDER BY id DESC
    LIMIT ?
  `, [username, other, other, username, limit]).reverse().map((row) => {
    const payload = parsePayload(row.payload);
    payload.id = Number(row.id);
    if (Number(row.edited) === 1) payload.edited = true;
    return {
      id: Number(row.id),
      sender: row.sender,
      target: row.target,
      text: row.text,
      time: formatTime(row.created_at),
      kind: row.kind || 'text',
      payload,
    };
  });
}

function leaderboardLegacy(limit = 20) {
  return query(`
    SELECT username AS name, coins, wins
    FROM users
    ORDER BY coins DESC
    LIMIT ?
  `, [limit]).map((row) => ({
    name: row.name,
    coins: Number(row.coins),
    wins: Number(row.wins),
  }));
}

function transactions(username, limit = 50) {
  return query(`
    SELECT id, kind, amount, balance, meta, created_at
    FROM transactions
    WHERE username = ?
    ORDER BY id DESC
    LIMIT ?
  `, [username, limit]).map((row) => ({
    id: Number(row.id),
    kind: row.kind,
    amount: Number(row.amount),
    balance: Number(row.balance),
    meta: row.meta ? JSON.parse(row.meta) : {},
    time: formatTime(row.created_at),
  }));
}

function friends(username) {
  return query(`
    SELECT u.username AS name, u.coins, u.wins, u.last_seen
    FROM friendships f
    JOIN users u ON u.username = f.friend
    WHERE f.username = ?
    ORDER BY u.username COLLATE NOCASE
  `, [username]).map((row) => ({
    name: row.name,
    coins: Number(row.coins || 0),
    wins: Number(row.wins || 0),
    lastSeen: row.last_seen || null,
  }));
}

function friendRequests(username) {
  return query(`
    SELECT id, sender, target, status, created_at
    FROM friend_requests
    WHERE (target = ? AND status = 'pending') OR (sender = ? AND status = 'pending')
    ORDER BY id DESC
  `, [username, username]).map((row) => ({
    id: Number(row.id),
    sender: row.sender,
    target: row.target,
    status: row.status,
    time: formatTime(row.created_at),
  }));
}

function isFriend(username, other) {
  return Boolean(get('SELECT username FROM friendships WHERE username = ? AND friend = ?', [username, other]));
}

function requestFriend(sender, target) {
  if (sender === target) throw new Error('不能加自己');
  if (!user(target)) throw new Error('找不到這位成員');
  if (isFriend(sender, target)) throw new Error('你們已經是好友');
  const existing = get(`
    SELECT id, sender, target, status FROM friend_requests
    WHERE ((sender = ? AND target = ?) OR (sender = ? AND target = ?)) AND status = 'pending'
    LIMIT 1
  `, [sender, target, target, sender]);
  if (existing) throw new Error('已有待處理的好友邀請');
  const now = new Date().toISOString();
  const stmt = db.prepare('INSERT INTO friend_requests(sender, target, status, created_at) VALUES (?, ?, \'pending\', ?)');
  stmt.run([sender, target, now]);
  stmt.free();
  addNotification(target, 'friend.request', { sender });
  persist();
  return { sender, target };
}

function respondFriendRequest(username, requestId, accept) {
  const req = get('SELECT id, sender, target, status FROM friend_requests WHERE id = ?', [requestId]);
  if (!req || req.target !== username || req.status !== 'pending') throw new Error('邀請不存在');
  const now = new Date().toISOString();
  return transaction(() => {
    const stmt = db.prepare('UPDATE friend_requests SET status = ?, responded_at = ? WHERE id = ?');
    stmt.run([accept ? 'accepted' : 'declined', now, requestId]);
    stmt.free();
    if (accept) {
      const add = db.prepare('INSERT OR IGNORE INTO friendships(username, friend, created_at) VALUES (?, ?, ?)');
      add.run([req.sender, req.target, now]);
      add.run([req.target, req.sender, now]);
      add.free();
      addNotification(req.sender, 'friend.accepted', { friend: req.target });
    }
    return { accepted: accept, sender: req.sender, target: req.target };
  });
}

function removeFriend(username, other) {
  run('DELETE FROM friendships WHERE (username = ? AND friend = ?) OR (username = ? AND friend = ?)', [username, other, other, username]);
}

function addNotification(username, type, payload) {
  const stmt = db.prepare(`INSERT INTO notifications(username, type, payload, read, created_at) VALUES (?, ?, ?, 0, ?)`);
  stmt.run([username, type, JSON.stringify(payload || {}), new Date().toISOString()]);
  stmt.free();
}

function notifications(username, limit = 50) {
  return query(`SELECT id, type, payload, read, created_at FROM notifications WHERE username = ? ORDER BY id DESC LIMIT ?`, [username, limit]).map((row) => ({
    id: Number(row.id),
    type: row.type,
    payload: row.payload ? JSON.parse(row.payload) : {},
    read: Number(row.read) === 1,
    time: formatTime(row.created_at),
  }));
}

function markNotificationsRead(username) {
  run('UPDATE notifications SET read = 1 WHERE username = ?', [username]);
}

function transferCoins(sender, target, amount) {
  if (sender === target) throw new Error('不能轉給自己');
  if (!user(target)) throw new Error('找不到這位成員');
  if (!Number.isInteger(amount) || amount <= 0 || amount > 100000) throw new Error('金額無效');
  return transaction(() => {
    const from = get('SELECT coins FROM users WHERE username = ?', [sender]);
    const to = get('SELECT coins FROM users WHERE username = ?', [target]);
    if (!from || !to) throw new Error('user_not_found');
    if (Number(from.coins) < amount) throw new Error('insufficient_coins');
    const fromBalance = Number(from.coins) - amount;
    const toBalance = Number(to.coins) + amount;
    const upd = db.prepare('UPDATE users SET coins = ? WHERE username = ?');
    upd.run([fromBalance, sender]);
    upd.run([toBalance, target]);
    upd.free();
    const tx = db.prepare(`INSERT INTO transactions(username, kind, amount, balance, meta, created_at) VALUES (?, ?, ?, ?, ?, ?)`);
    const now = new Date().toISOString();
    tx.run([sender, 'transfer.out', -amount, fromBalance, JSON.stringify({ target }), now]);
    tx.run([target, 'transfer.in', amount, toBalance, JSON.stringify({ sender }), now]);
    tx.free();
    return { fromBalance, toBalance };
  });
}

function consumeItem(username, itemId) {
  return transaction(() => {
    const row = get('SELECT quantity FROM inventory WHERE username = ? AND item_id = ?', [username, itemId]);
    if (!row || Number(row.quantity) <= 0) throw new Error('沒有這個道具');
    const left = Number(row.quantity) - 1;
    if (left === 0) run('DELETE FROM inventory WHERE username = ? AND item_id = ?', [username, itemId]);
    else run('UPDATE inventory SET quantity = ? WHERE username = ? AND item_id = ?', [left, username, itemId]);
    return left;
  });
}

function stealCoins(username, target) {
  if (username === target) throw new Error('不能偷自己');
  if (!user(target)) throw new Error('找不到這位成員');
  return transaction(() => {
    const item = get('SELECT quantity FROM inventory WHERE username = ? AND item_id = \'steal\'', [username]);
    if (!item || Number(item.quantity) <= 0) throw new Error('沒有偷金幣卡');
    const targetShield = get('SELECT quantity FROM inventory WHERE username = ? AND item_id = \'shield\'', [target]);
    const takeShield = targetShield && Number(targetShield.quantity) > 0;
    const now = new Date().toISOString();
    // Consume the steal card either way.
    const stealLeft = Number(item.quantity) - 1;
    if (stealLeft === 0) run('DELETE FROM inventory WHERE username = ? AND item_id = ?', [username, 'steal']);
    else run('UPDATE inventory SET quantity = ? WHERE username = ? AND item_id = \'steal\'', [stealLeft, username]);

    if (takeShield) {
      const shieldLeft = Number(targetShield.quantity) - 1;
      if (shieldLeft === 0) run('DELETE FROM inventory WHERE username = ? AND item_id = \'shield\'', [target]);
      else run('UPDATE inventory SET quantity = ? WHERE username = ? AND item_id = \'shield\'', [shieldLeft, target]);
      return { stolen: 0, blocked: true, attackerBalance: Number(user(username).coins), targetBalance: Number(user(target).coins) };
    }

    const attacker = get('SELECT coins FROM users WHERE username = ?', [username]);
    const victim = get('SELECT coins FROM users WHERE username = ?', [target]);
    const victimCoins = Number(victim.coins);
    if (victimCoins <= 0) return { stolen: 0, blocked: false, attackerBalance: Number(attacker.coins), targetBalance: victimCoins };
    const percent = 0.05 + Math.random() * 0.10;
    const stolen = Math.max(1, Math.min(2000, Math.floor(victimCoins * percent)));
    const attackerBalance = Number(attacker.coins) + stolen;
    const targetBalance = victimCoins - stolen;
    const upd = db.prepare('UPDATE users SET coins = ? WHERE username = ?');
    upd.run([attackerBalance, username]);
    upd.run([targetBalance, target]);
    upd.free();
    const tx = db.prepare(`INSERT INTO transactions(username, kind, amount, balance, meta, created_at) VALUES (?, ?, ?, ?, ?, ?)`);
    tx.run([username, 'steal.in', stolen, attackerBalance, JSON.stringify({ target }), now]);
    tx.run([target, 'steal.out', -stolen, targetBalance, JSON.stringify({ attacker: username }), now]);
    tx.free();
    return { stolen, blocked: false, attackerBalance, targetBalance };
  });
}

function useBox(username) {
  const items = ['steal', 'shield', 'scan', 'dice', 'magnet'];
  return transaction(() => {
    const row = get('SELECT quantity FROM inventory WHERE username = ? AND item_id = \'box\'', [username]);
    if (!row || Number(row.quantity) <= 0) throw new Error('沒有神秘箱');
    const left = Number(row.quantity) - 1;
    if (left === 0) {
      const del = db.prepare('DELETE FROM inventory WHERE username = ? AND item_id = ?');
      del.run([username, 'box']);
      del.free();
    } else {
      const upd = db.prepare('UPDATE inventory SET quantity = ? WHERE username = ? AND item_id = ?');
      upd.run([left, username, 'box']);
      upd.free();
    }
    const itemId = items[Math.floor(Math.random() * items.length)];
    const add = db.prepare(`INSERT INTO inventory(username, item_id, quantity) VALUES (?, ?, 1) ON CONFLICT(username, item_id) DO UPDATE SET quantity = quantity + 1`);
    add.run([username, itemId]);
    add.free();
    return itemId;
  });
}

function rollDice(username) {
  return transaction(() => {
    const row = get('SELECT quantity FROM inventory WHERE username = ? AND item_id = \'dice\'', [username]);
    if (!row || Number(row.quantity) <= 0) throw new Error('沒有幸運骰子');
    const left = Number(row.quantity) - 1;
    const updInventory = db.prepare(left === 0
      ? 'DELETE FROM inventory WHERE username = ? AND item_id = ?'
      : 'UPDATE inventory SET quantity = ? WHERE username = ? AND item_id = ?');
    if (left === 0) updInventory.run([username, 'dice']);
    else updInventory.run([left, username, 'dice']);
    updInventory.free();

    const rewards = [100, 200, 300, 500, 800];
    const reward = rewards[Math.floor(Math.random() * rewards.length)];
    const current = get('SELECT coins FROM users WHERE username = ?', [username]);
    const balance = Number(current.coins) + reward;
    const upd = db.prepare('UPDATE users SET coins = ? WHERE username = ?');
    upd.run([balance, username]);
    upd.free();
    const tx = db.prepare(`INSERT INTO transactions(username, kind, amount, balance, meta, created_at) VALUES (?, 'item.dice', ?, ?, '{}', ?)`);
    tx.run([username, reward, balance, new Date().toISOString()]);
    tx.free();
    return { reward, balance };
  });
}

function addInventory(username, itemId, quantity = 1) {
  run(`INSERT INTO inventory(username, item_id, quantity) VALUES (?, ?, ?) ON CONFLICT(username, item_id) DO UPDATE SET quantity = quantity + excluded.quantity`, [username, itemId, quantity]);
}

function formatTime(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return date.toLocaleTimeString('zh-TW', { hour: '2-digit', minute: '2-digit', hour12: false });
}



function recordGame(username, gameId, result, reward = 0, meta = {}) {
  run(`INSERT INTO game_history(username, game_id, result, reward, meta, created_at) VALUES (?, ?, ?, ?, ?, ?)`, [
    username, gameId, result, Number(reward), JSON.stringify(meta), new Date().toISOString()
  ]);
}

function gameHistory(username, limit = 50) {
  return query(`SELECT id, game_id, result, reward, meta, created_at FROM game_history WHERE username = ? ORDER BY id DESC LIMIT ?`, [username, limit])
    .map((row) => ({ id: Number(row.id), gameId: row.game_id, result: row.result, reward: Number(row.reward || 0), meta: row.meta ? JSON.parse(row.meta) : {}, time: formatTime(row.created_at) }));
}



function votePoll(messageId, username, optionIndex) {
  return transaction(() => {
    const row = get('SELECT payload, kind FROM lobby_messages WHERE id = ?', [messageId]);
    if (!row || row.kind !== 'poll') throw new Error('投票不存在');
    const payload = parsePayload(row.payload);
    const options = Array.isArray(payload.options) ? payload.options : [];
    if (!Number.isInteger(optionIndex) || optionIndex < 0 || optionIndex >= options.length) throw new Error('選項無效');
    const votes = payload.votes && typeof payload.votes === 'object' ? payload.votes : {};
    if (votes[username] != null) throw new Error('你已經投過票了');
    votes[username] = optionIndex;
    payload.votes = votes;
    const stmt = db.prepare('UPDATE lobby_messages SET payload = ? WHERE id = ?');
    stmt.run([JSON.stringify(payload), messageId]);
    stmt.free();
    return payload;
  });
}

function chatHistoryCount(username) {
  const row = get('SELECT COUNT(*) AS count FROM lobby_messages WHERE sender = ?', [username]);
  return Number(row?.count || 0);
}

function gameStats(username, gameId = 'werewolf') {
  const totalRow = get('SELECT COUNT(*) AS count FROM game_history WHERE username = ? AND game_id = ?', [username, gameId]);
  const winsRow = get('SELECT COUNT(*) AS count FROM game_history WHERE username = ? AND game_id = ? AND result = \'win\'', [username, gameId]);
  const total = Number(totalRow?.count || 0);
  const wins = Number(winsRow?.count || 0);
  return { total, wins, rate: total ? Math.round((wins / total) * 100) : 0 };
}

function leaderboard(limit = 50) {
  return query(`
    SELECT u.username AS name, u.coins, u.wins,
      (SELECT COUNT(*) FROM lobby_messages lm WHERE lm.sender = u.username) AS chatCount,
      (SELECT COUNT(*) FROM game_history gh WHERE gh.username = u.username) AS gameCount
    FROM users u
    WHERE u.banned = 0
    ORDER BY u.coins DESC, u.wins DESC
    LIMIT ?
  `, [limit]).map((row) => ({
    name: row.name,
    coins: Number(row.coins || 0),
    wins: Number(row.wins || 0),
    chatCount: Number(row.chatCount || 0),
    gameCount: Number(row.gameCount || 0),
  }));
}

function isAdmin(username) {
  return Boolean(get("SELECT username FROM users WHERE username = ? AND role = 'admin' AND banned = 0", [username]));
}

function setAdmin(username, isAdminValue) {
  run("UPDATE users SET role = ? WHERE username = ?", [isAdminValue ? 'admin' : 'member', username]);
}

function listUsers(limit = 100) {
  return query(`SELECT username, coins, wins, role, banned, avatar_url, created_at, last_seen FROM users ORDER BY username COLLATE NOCASE LIMIT ?`, [limit]);
}

function setBanned(username, banned) {
  if (!user(username)) throw new Error('找不到這位成員');
  run('UPDATE users SET banned = ? WHERE username = ?', [banned ? 1 : 0, username]);
}

function setAvatar(username, avatarUrl) {
  run('UPDATE users SET avatar_url = ? WHERE username = ?', [avatarUrl || '', username]);
}

function saveMemory(uploader, kind, url, caption) {
  return transaction(() => {
    const stmt = db.prepare('INSERT INTO memories(uploader, kind, url, caption, created_at) VALUES (?, ?, ?, ?, ?)');
    const now = new Date().toISOString();
    stmt.run([uploader, kind, url, String(caption || '').slice(0, 300), now]);
    stmt.free();
    const row = get('SELECT last_insert_rowid() AS id');
    return { id: Number(row.id), uploader, kind, url, caption: String(caption || ''), time: formatTime(now) };
  });
}

function memories(limit = 100) {
  return query('SELECT id, uploader, kind, url, caption, created_at FROM memories ORDER BY id DESC LIMIT ?', [limit])
    .map((row) => ({ id: Number(row.id), uploader: row.uploader, kind: row.kind, url: row.url, caption: row.caption, time: formatTime(row.created_at) }));
}

function deleteMemory(id) { run('DELETE FROM memories WHERE id = ?', [Number(id)]); }

function ensureDefaultChatRooms(username) {
  if (!user(username)) return;
  const defaults = [
    ['chat', '聊天房'],
    ['game', '遊戲房'],
  ];
  const now = new Date().toISOString();
  for (const [id, name] of defaults) {
    run('INSERT OR IGNORE INTO chat_rooms(id, name, created_by, created_at) VALUES (?, ?, ?, ?)', [id, name, username, now]);
    run('INSERT OR IGNORE INTO chat_room_members(room_id, username, joined_at) VALUES (?, ?, ?)', [id, username, now]);
  }
}

function chatRooms(username) {
  return query(`
    SELECT r.id, r.name, r.created_by, r.created_at,
           EXISTS(SELECT 1 FROM chat_room_members m2 WHERE m2.room_id = r.id AND m2.username = ?) AS joined,
           (SELECT COUNT(*) FROM chat_room_members m3 WHERE m3.room_id = r.id) AS members
    FROM chat_rooms r
    ORDER BY r.created_at ASC, r.name COLLATE NOCASE
  `, [username]).map((row) => ({
    id: row.id,
    name: row.name,
    createdBy: row.created_by,
    createdAt: row.created_at,
    joined: Number(row.joined) === 1,
    members: Number(row.members || 0),
    voiceRoom: true,
  }));
}

function createChatRoom(name, creator) {
  const clean = String(name || '').trim().slice(0, 30);
  if (!clean) throw new Error('聊天室名稱不能空白');
  if (!user(creator)) throw new Error('找不到建立者');
  const id = `room_${Date.now()}_${Math.floor(Math.random() * 1e6).toString(36)}`;
  const now = new Date().toISOString();
  run('INSERT INTO chat_rooms(id, name, created_by, created_at) VALUES (?, ?, ?, ?)', [id, clean, creator, now]);
  run('INSERT INTO chat_room_members(room_id, username, joined_at) VALUES (?, ?, ?)', [id, creator, now]);
  return { id, name: clean, createdBy: creator, createdAt: now, joined: true, members: 1, voiceRoom: true };
}

function joinChatRoom(roomId, username) {
  const room = get('SELECT id, name, created_by, created_at FROM chat_rooms WHERE id = ?', [roomId]);
  if (!room) throw new Error('聊天室不存在');
  run('INSERT OR IGNORE INTO chat_room_members(room_id, username, joined_at) VALUES (?, ?, ?)', [roomId, username, new Date().toISOString()]);
  return chatRooms(username).find((r) => r.id === roomId) || null;
}

function leaveChatRoom(roomId, username) {
  if (!get('SELECT id FROM chat_rooms WHERE id = ?', [roomId])) throw new Error('聊天室不存在');
  run('DELETE FROM chat_room_members WHERE room_id = ? AND username = ?', [roomId, username]);
}

function isChatRoomMember(roomId, username) {
  return Boolean(get('SELECT room_id FROM chat_room_members WHERE room_id = ? AND username = ?', [roomId, username]));
}

function chatRoomHistory(roomId, limit = 100) {
  return query(`
    SELECT id, room_id, sender, text, created_at, client_id, kind, payload, edited
    FROM chat_room_messages
    WHERE room_id = ?
    ORDER BY id DESC
    LIMIT ?
  `, [roomId, limit]).reverse().map((row) => {
    const payload = parsePayload(row.payload);
    payload.id = Number(row.id);
    if (Number(row.edited) === 1) payload.edited = true;
    return { id: Number(row.id), roomId: row.room_id, sender: row.sender, text: row.text, time: formatTime(row.created_at), clientId: row.client_id || null, kind: row.kind || 'text', payload };
  });
}

function insertChatRoomMessage(roomId, sender, text, createdAt, clientId, kind = 'text', payload = {}) {
  return transaction(() => {
    const stmt = db.prepare(`
      INSERT INTO chat_room_messages(room_id, sender, text, created_at, client_id, kind, payload)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);
    stmt.run([roomId, sender, text, createdAt, clientId || null, kind, JSON.stringify(payload || {})]);
    stmt.free();
    const row = get('SELECT last_insert_rowid() AS id');
    return { id: Number(row.id), roomId, sender, text, time: formatTime(createdAt), clientId: clientId || null, kind, payload: payload || {} };
  });
}

function editChatRoomMessage(roomId, id, username, text, isAdmin = false) {
  const row = get('SELECT id, sender, kind, payload FROM chat_room_messages WHERE id = ? AND room_id = ?', [Number(id), roomId]);
  if (!row) throw new Error('訊息不存在');
  if (row.sender !== username && !isAdmin) throw new Error('只能編輯自己的訊息');
  const payload = parsePayload(row.payload);
  payload.id = Number(row.id);
  payload.edited = true;
  run('UPDATE chat_room_messages SET text = ?, payload = ?, edited = 1 WHERE id = ? AND room_id = ?', [text.slice(0, 500), JSON.stringify(payload), Number(id), roomId]);
  return { id: Number(id), roomId, text: text.slice(0, 500), kind: row.kind || 'text', payload, sender: row.sender };
}

function deleteChatRoomMessage(roomId, id, username, isAdmin = false) {
  const row = get('SELECT id, sender FROM chat_room_messages WHERE id = ? AND room_id = ?', [Number(id), roomId]);
  if (!row) throw new Error('訊息不存在');
  if (row.sender !== username && !isAdmin) throw new Error('只能刪除自己的訊息');
  run('DELETE FROM chat_room_messages WHERE id = ? AND room_id = ?', [Number(id), roomId]);
  return { id: Number(id), roomId };
}

function editLobbyMessage(id, username, text, isAdmin = false) {
  const row = get('SELECT id, sender, kind, payload FROM lobby_messages WHERE id = ?', [Number(id)]);
  if (!row) throw new Error('訊息不存在');
  if (row.sender !== username && !isAdmin) throw new Error('只能編輯自己的訊息');
  const payload = parsePayload(row.payload);
  payload.id = Number(row.id);
  payload.edited = true;
  run('UPDATE lobby_messages SET text = ?, payload = ?, edited = 1 WHERE id = ?', [text.slice(0, 500), JSON.stringify(payload), Number(id)]);
  return { id: Number(id), text: text.slice(0, 500), kind: row.kind || 'text', payload, sender: row.sender };
}

function deleteLobbyMessage(id, username, isAdmin = false) {
  const row = get('SELECT id, sender FROM lobby_messages WHERE id = ?', [Number(id)]);
  if (!row) throw new Error('訊息不存在');
  if (row.sender !== username && !isAdmin) throw new Error('只能刪除自己的訊息');
  run('DELETE FROM lobby_messages WHERE id = ?', [Number(id)]);
  return { id: Number(id) };
}

function editPrivateMessage(id, username, text) {
  const row = get('SELECT id, sender, target, kind, payload FROM private_messages WHERE id = ?', [Number(id)]);
  if (!row) throw new Error('訊息不存在');
  if (row.sender !== username) throw new Error('只能編輯自己的訊息');
  const payload = parsePayload(row.payload);
  payload.edited = true;
  payload.id = Number(id);
  run('UPDATE private_messages SET text = ?, payload = ?, edited = 1 WHERE id = ?', [text.slice(0, 500), JSON.stringify(payload), Number(id)]);
  return { id: Number(id), sender: row.sender, target: row.target, text: text.slice(0, 500), kind: row.kind || 'text', payload };
}

function deletePrivateMessage(id, username) {
  const row = get('SELECT id, sender, target FROM private_messages WHERE id = ?', [Number(id)]);
  if (!row) throw new Error('訊息不存在');
  if (row.sender !== username) throw new Error('只能刪除自己的訊息');
  run('DELETE FROM private_messages WHERE id = ?', [Number(id)]);
  return { id: Number(id), sender: row.sender, target: row.target };
}

function voiceRoomDefs() {
  return query('SELECT id, name, locked, created_at FROM voice_room_defs ORDER BY id COLLATE NOCASE')
    .map((row) => ({ id: row.id, name: row.name, locked: Number(row.locked) === 1, createdAt: row.created_at }));
}

function upsertVoiceRoom(id, name, locked = false) {
  run(`INSERT INTO voice_room_defs(id, name, locked, created_at) VALUES (?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET name = excluded.name, locked = excluded.locked`, [id, name, locked ? 1 : 0, new Date().toISOString()]);
}

function deleteVoiceRoom(id) { run('DELETE FROM voice_room_defs WHERE id = ?', [id]); }
function setVoiceRoomLocked(id, locked) { run('UPDATE voice_room_defs SET locked = ? WHERE id = ?', [locked ? 1 : 0, id]); }

function createAnnouncement(title, body) {
  const now = new Date().toISOString();
  run('INSERT INTO announcements(title, body, created_at) VALUES (?, ?, ?)', [title, body, now]);
  const row = get('SELECT last_insert_rowid() AS id');
  return { id: Number(row.id), title, body, time: formatTime(now) };
}
function deleteAnnouncement(id) { run('DELETE FROM announcements WHERE id = ?', [Number(id)]); }

function announcements(limit = 20) {
  return query(`SELECT id, title, body, created_at FROM announcements ORDER BY id DESC LIMIT ?`, [limit])
    .map((row) => ({ id: Number(row.id), title: row.title, body: row.body, time: formatTime(row.created_at) }));
}
module.exports = {
  initStorage,
  persist,
  query,
  get,
  run,
  transaction,
  user,
  fullProfile,
  setLastSeen,
  addCoins,
  buyItem,
  claimDaily,
  insertLobbyMessage,
  insertPrivateMessage,
  lobbyHistory,
  privateHistory,
  leaderboard,
  transactions,
  recordGame,
  gameHistory,
  announcements,
  friends,
  friendRequests,
  isFriend,
  requestFriend,
  respondFriendRequest,
  removeFriend,
  addNotification,
  notifications,
  markNotificationsRead,
  transferCoins,
  consumeItem,
  stealCoins,
  useBox,
  rollDice,
  addInventory,
  votePoll,
  chatHistoryCount,
  gameStats,
  isAdmin,
  setAdmin,
  listUsers,
  setBanned,
  setAvatar,
  saveMemory,
  memories,
  deleteMemory,
  voiceRoomDefs,
  upsertVoiceRoom,
  deleteVoiceRoom,
  setVoiceRoomLocked,
  ensureDefaultChatRooms,
  chatRooms,
  createChatRoom,
  joinChatRoom,
  leaveChatRoom,
  isChatRoomMember,
  chatRoomHistory,
  insertChatRoomMessage,
  editChatRoomMessage,
  deleteChatRoomMessage,
  editLobbyMessage,
  deleteLobbyMessage,
  editPrivateMessage,
  deletePrivateMessage,
  createAnnouncement,
  deleteAnnouncement,
};
