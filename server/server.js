const http = require('http');
const crypto = require('crypto');
const WebSocket = require('ws');
const storage = require('./storage');

const PORT = Number(process.env.PORT || 6110);
const SERVER_VERSION = '1.0.2';
const path = require('path');
const fs = require('fs');
const DATA_DIR = path.join(__dirname, 'data');
const UPLOAD_DIR = path.join(DATA_DIR, 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });
const online = new Map();
const sessions = new Map();
const activeBoosts = new Map();
const ITEM_PRICES = Object.freeze({ steal: 800, shield: 700, scan: 1500, dice: 600, magnet: 1000, box: 500 });

function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return { salt, hash };
}
function verifyPassword(password, salt, expected) {
  const actual = crypto.scryptSync(password, salt, 64).toString('hex');
  return crypto.timingSafeEqual(Buffer.from(actual, 'hex'), Buffer.from(expected, 'hex'));
}
function sendJson(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  });
  res.end(body);
}
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 20 * 1024 * 1024) reject(new Error('body_too_large'));
    });
    req.on('end', () => {
      try { resolve(body ? JSON.parse(body) : {}); } catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}
function tokenFor(username) {
  return crypto.randomBytes(32).toString('hex') + '.' + crypto.createHash('sha256').update(username + Date.now()).digest('hex').slice(0, 16);
}
function tokenFromRequest(req) {
  const header = String(req.headers.authorization || '');
  return header.startsWith('Bearer ') ? header.slice(7).trim() : '';
}
function usernameFromToken(token) {
  return token ? sessions.get(token) || null : null;
}
function timeNow() {
  return new Date().toISOString();
}

function profilePayload(username) {
  return {
    username,
    profile: storage.fullProfile(username),
    transactions: storage.transactions(username, 30),
    gameHistory: storage.gameHistory(username, 20),
    werewolfStats: storage.gameStats(username, 'werewolf'),
    chatCount: storage.chatHistoryCount(username),
    isAdmin: storage.isAdmin(username),
  };
}


function saveUpload(username, kind, dataBase64, ext = 'bin') {
  const raw = String(dataBase64 || '');
  const cleaned = raw.includes(',') ? raw.slice(raw.indexOf(',') + 1) : raw;
  const buffer = Buffer.from(cleaned, 'base64');
  if (!buffer.length) throw new Error('檔案內容為空');
  if (buffer.length > 10 * 1024 * 1024) throw new Error('檔案太大，單檔上限 10MB');
  const safeExt = String(ext || 'bin').replace(/[^a-zA-Z0-9]/g, '').slice(0, 8) || 'bin';
  const id = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}`;
  const filename = `${id}.${safeExt}`;
  fs.writeFileSync(path.join(UPLOAD_DIR, filename), buffer);
  return `/media/${filename}`;
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return sendJson(res, 204, {});
  if (req.method === 'POST' && req.url === '/api/upload') {
    try {
      const username = usernameFromToken(tokenFromRequest(req));
      if (!username) return sendJson(res, 401, { error: 'unauthorized' });
      const body = await parseBody(req);
      const kind = String(body.kind || '').trim();
      if (!['avatar', 'image', 'video', 'memory'].includes(kind)) {
        return sendJson(res, 400, { error: 'unsupported_upload_type' });
      }
      const maxBytes = kind === 'avatar' ? 5 * 1024 * 1024 : 10 * 1024 * 1024;
      const raw = String(body.dataBase64 || '');
      const cleaned = raw.includes(',') ? raw.slice(raw.indexOf(',') + 1) : raw;
      const buffer = Buffer.from(cleaned, 'base64');
      if (!buffer.length) return sendJson(res, 400, { error: 'empty_file' });
      if (buffer.length > maxBytes) return sendJson(res, 413, { error: `file_too_large_${maxBytes}` });
      const url = saveUpload(username, kind, raw, String(body.ext || 'bin'));
      return sendJson(res, 200, { url, kind, version: SERVER_VERSION });
    } catch (error) {
      console.error('[upload]', error);
      return sendJson(res, 400, { error: error?.message || 'upload_failed' });
    }
  }

  if (req.method === 'GET' && req.url === '/api/health') {
    return sendJson(res, 200, { ok: true, service: 'thunder611', version: SERVER_VERSION, database: 'sqlite', upload: true });
  }
  if (req.method === 'GET' && req.url.startsWith('/media/')) {
    const requestPath = new URL(req.url, 'http://127.0.0.1').pathname;
    const filename = path.basename(decodeURIComponent(requestPath.slice('/media/'.length)));
    const file = path.join(UPLOAD_DIR, filename);
    if (!fs.existsSync(file)) {
      console.warn('[media 404]', file);
      return sendJson(res, 404, { error: 'media_not_found', filename });
    }
    const ext = path.extname(file).toLowerCase();
    const types = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.gif': 'image/gif', '.webp': 'image/webp', '.mp4': 'video/mp4', '.mov': 'video/quicktime', '.webm': 'video/webm', '.m4v': 'video/mp4' };
    const stat = fs.statSync(file);
    const range = req.headers.range;
    const contentType = types[ext] || 'application/octet-stream';
    if (range) {
      const match = /^bytes=(\d*)-(\d*)$/.exec(String(range));
      if (match) {
        const start = match[1] ? Number(match[1]) : 0;
        const end = match[2] ? Number(match[2]) : stat.size - 1;
        const safeStart = Math.max(0, Math.min(start, stat.size - 1));
        const safeEnd = Math.max(safeStart, Math.min(end, stat.size - 1));
        res.writeHead(206, {
          'Content-Type': contentType,
          'Content-Range': `bytes ${safeStart}-${safeEnd}/${stat.size}`,
          'Accept-Ranges': 'bytes',
          'Content-Length': safeEnd - safeStart + 1,
          'Cache-Control': 'public, max-age=31536000, immutable',
          'Access-Control-Allow-Origin': '*',
        });
        fs.createReadStream(file, { start: safeStart, end: safeEnd }).pipe(res);
        return;
      }
    }
    res.writeHead(200, {
      'Content-Type': contentType,
      'Content-Length': stat.size,
      'Accept-Ranges': 'bytes',
      'Cache-Control': 'public, max-age=31536000, immutable',
      'Access-Control-Allow-Origin': '*',
    });
    fs.createReadStream(file).pipe(res);
    return;
  }

  try {
    if (req.method === 'POST' && (req.url === '/api/auth/register' || req.url === '/api/auth/login')) {
      const body = await parseBody(req);
      const username = String(body.username || '').trim();
      const password = String(body.password || '');
      if (username.length < 2 || password.length < 4) {
        return sendJson(res, 400, { error: '暱稱至少 2 個字，密碼至少 4 碼' });
      }

      if (req.url.endsWith('/register')) {
        if (body.code !== '611') return sendJson(res, 400, { error: '班級代碼錯誤' });
        if (storage.user(username)) return sendJson(res, 409, { error: '這個暱稱已被使用' });
        const pw = hashPassword(password);
        const adminCount = Number(storage.get("SELECT COUNT(*) AS count FROM users WHERE role = 'admin'").count || 0);
        storage.run(`
          INSERT INTO users(username, salt, hash, coins, wins, role, banned, created_at, last_seen)
          VALUES (?, ?, ?, 1250, 0, ?, 0, ?, ?)
        `, [username, pw.salt, pw.hash, adminCount === 0 ? 'admin' : 'member', timeNow(), timeNow()]);
        storage.ensureDefaultChatRooms(username);
      } else {
        const row = storage.get('SELECT username, salt, hash, banned FROM users WHERE username = ?', [username]);
        if (!row || !verifyPassword(password, row.salt, row.hash)) {
          return sendJson(res, 401, { error: '帳號或密碼不正確' });
        }
        if (Number(row.banned || 0) === 1) return sendJson(res, 403, { error: '此帳號已被封禁' });
      }

      const token = tokenFor(username);
      sessions.set(token, username);
      storage.setLastSeen(username);
      return sendJson(res, 200, {
        username,
        token,
        ...profilePayload(username),
      });
    }

    if (req.method === 'GET' && req.url === '/api/me') {
      const username = usernameFromToken(tokenFromRequest(req));
      if (!username) return sendJson(res, 401, { error: 'unauthorized' });
      storage.setLastSeen(username);
      return sendJson(res, 200, profilePayload(username));
    }

    if (req.method === 'GET' && req.url === '/api/leaderboard') {
      return sendJson(res, 200, { members: storage.leaderboard(20) });
    }

    if (req.method === 'GET' && req.url.startsWith('/api/private/')) {
      const username = usernameFromToken(tokenFromRequest(req));
      if (!username) return sendJson(res, 401, { error: 'unauthorized' });
      const other = decodeURIComponent(req.url.slice('/api/private/'.length));
      return sendJson(res, 200, { messages: storage.privateHistory(username, other, 100) });
    }

    if (req.method === 'GET' && req.url === '/api/game-history') {
      const username = usernameFromToken(tokenFromRequest(req));
      if (!username) return sendJson(res, 401, { error: 'unauthorized' });
      return sendJson(res, 200, { games: storage.gameHistory(username, 50) });
    }

    if (req.method === 'GET' && req.url === '/api/announcements') {
      return sendJson(res, 200, { announcements: storage.announcements(20) });
    }

    if (req.method === 'GET' && req.url === '/api/transactions') {
      const username = usernameFromToken(tokenFromRequest(req));
      if (!username) return sendJson(res, 401, { error: 'unauthorized' });
      return sendJson(res, 200, { transactions: storage.transactions(username, 100) });
    }

    return sendJson(res, 404, { error: 'not_found' });
  } catch (error) {
    console.error(error);
    return sendJson(res, 500, { error: 'server_error' });
  }
});

const wss = new WebSocket.Server({ server });

function broadcast(payload, except = null) {
  const text = JSON.stringify(payload);
  for (const [ws] of online) {
    if (ws.readyState === WebSocket.OPEN && ws !== except) ws.send(text);
  }
}
function sendToUsername(username, payload) {
  const target = [...online.entries()].find(([, u]) => u.username === username)?.[0];
  if (target && target.readyState === WebSocket.OPEN) {
    target.send(JSON.stringify(payload));
    return true;
  }
  return false;
}
function snapshot() {
  return [...online.values()].map((user) => ({
    name: user.username,
    online: true,
    status: user.status || '在線',
    coins: user.coins,
  }));
}

function balanceBroadcast(username, balance) {
  sendToUsername(username, { type: 'balance.update', username, coins: balance });
  broadcast({ type: 'member.balance', username, coins: balance });
}

function socialSnapshot(username) {
  return {
    friends: storage.friends(username),
    requests: storage.friendRequests(username),
    notifications: storage.notifications(username, 30),
  };
}

function sendSocialSnapshot(username) {
  sendToUsername(username, { type: 'social.snapshot', ...socialSnapshot(username) });
}


// ─────────────────────────────────────────────────────────────
// 狼人殺：純文字社交推理房間
// 玩法：夜晚行動 → 白天自由發言 → 投票 → 下一輪。
// 不含地圖、任務或即時移動。
const werewolfRooms = new Map();
const truthRooms = new Map();
const voiceRooms = new Map(); // key -> Map(username, { ws, muted })
let roomSequence = 1000;

function randomRoomId() {
  roomSequence += 1;
  return String(roomSequence);
}

function roleSet(count) {
  const roles = [];
  const wolves = count >= 8 ? 2 : 1;
  for (let i = 0; i < wolves; i++) roles.push('狼人');
  roles.push('預言家');
  if (count >= 7) roles.push('守衛');
  while (roles.length < count) roles.push('村民');
  return roles.sort(() => Math.random() - 0.5);
}

function roomPlayers(room) {
  return [...room.players.values()].map((p) => ({
    name: p.name,
    alive: p.alive,
    connected: Boolean(p.ws && p.ws.readyState === WebSocket.OPEN),
  }));
}

function publicRoomState(room, viewer) {
  const ended = room.phase === 'ended';
  const me = room.players.get(viewer);
  return {
    roomId: room.id,
    host: room.host,
    phase: room.phase,
    round: room.round,
    maxPlayers: room.maxPlayers,
    players: [...room.players.values()].map((p) => ({
      name: p.name,
      alive: p.alive,
      connected: Boolean(p.ws && p.ws.readyState === WebSocket.OPEN),
      role: (ended || p.name === viewer) ? p.role : null,
    })),
    myRole: me?.role || null,
    myAlive: Boolean(me?.alive),
    messages: room.messages.slice(-80),
    winner: room.winner || null,
  };
}

function roomListPayload() {
  return [...werewolfRooms.values()]
    .filter((r) => r.phase === 'lobby')
    .map((r) => ({
      roomId: r.id,
      host: r.host,
      players: r.players.size,
      maxPlayers: r.maxPlayers,
    }));
}

function broadcastRoom(room, type = 'werewolf.state', extra = {}) {
  for (const p of room.players.values()) {
    if (p.ws.readyState === WebSocket.OPEN) {
      p.ws.send(JSON.stringify({ type, ...publicRoomState(room, p.name), ...extra }));
    }
  }
  broadcast({ type: 'werewolf.rooms', rooms: roomListPayload() });
}

function leaveWerewolfRoom(user) {
  if (!user.roomId) return;
  leaveVoice(user);
  const room = werewolfRooms.get(user.roomId);
  if (!room) { user.roomId = null; return; }
  const player = room.players.get(user.username);
  if (player) player.ws = user.ws;
  // 遊戲進行中離線者視為死亡，避免卡住投票。
  if (room.phase !== 'lobby' && room.phase !== 'ended' && player) {
    player.alive = false;
  }
  room.players.delete(user.username);
  if (room.host === user.username) {
    room.host = [...room.players.keys()][0] || null;
  }
  user.roomId = null;
  if (room.players.size === 0) {
    werewolfRooms.delete(room.id);
    broadcast({ type: 'werewolf.rooms', rooms: roomListPayload() });
  } else {
    broadcastRoom(room);
  }
}

function resolveWinner(room) {
  const alive = [...room.players.values()].filter((p) => p.alive);
  const wolves = alive.filter((p) => p.role === '狼人').length;
  const villagers = alive.filter((p) => p.role !== '狼人').length;
  if (wolves === 0) return '村民';
  if (wolves >= villagers) return '狼人';
  return null;
}

function finishWerewolf(room, winner) {
  room.phase = 'ended';
  room.winner = winner;
  room.messages.push({ sender: '系統', text: `${winner}陣營獲勝。`, time: timeNow() });
  for (const p of room.players.values()) {
    if (p.ws.readyState !== WebSocket.OPEN) continue;
    try {
      const won = (winner === '狼人' && p.role === '狼人') || (winner === '村民' && p.role !== '狼人');
      let reward = won ? 500 : 100;
      const boost = activeBoosts.get(p.name);
      if (boost && boost.type === 'magnet') {
        if (boost.until > Date.now()) reward = Math.floor(reward * 1.3);
        else activeBoosts.delete(p.name);
      }
      const balance = storage.addCoins(p.name, reward, `game.werewolf.${won ? 'win' : 'participate'}`, { roomId: room.id, winner });
      storage.recordGame(p.name, 'werewolf', won ? 'win' : 'participate', reward, { roomId: room.id, winner });
      if (won) storage.run('UPDATE users SET wins = wins + 1 WHERE username = ?', [p.name]);
      p.ws.send(JSON.stringify({
        type: 'werewolf.ended',
        ...publicRoomState(room, p.name),
        reward,
        won,
        profile: storage.fullProfile(p.name),
        transactions: storage.transactions(p.name, 30),
        coins: balance,
      }));
    } catch (error) {
      p.ws.send(JSON.stringify({ type: 'action.error', action: 'werewolf', error: error.message }));
    }
  }
}

function assignRoles(room) {
  const roles = roleSet(room.players.size);
  const players = [...room.players.values()];
  players.forEach((p, i) => {
    p.role = roles[i];
    p.alive = true;
    p.vote = null;
    p.nightAction = null;
    p.inspectResult = null;
  });
}

function startWerewolf(room) {
  if (room.phase !== 'lobby') throw new Error('game_already_started');
  if (room.players.size < 4) throw new Error('至少需要 4 人');
  assignRoles(room);
  room.phase = 'night';
  room.round = 1;
  room.messages.push({ sender: '系統', text: '遊戲開始，現在是第 1 夜。', time: timeNow() });
}

function resolveNight(room) {
  const alive = [...room.players.values()].filter((p) => p.alive);
  const wolves = alive.filter((p) => p.role === '狼人');
  const wolfTargets = wolves.map((p) => p.nightAction?.target).filter(Boolean);
  const targetCounts = new Map();
  for (const target of wolfTargets) targetCounts.set(target, (targetCounts.get(target) || 0) + 1);
  const target = [...targetCounts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] || null;
  const guard = alive.find((p) => p.role === '守衛')?.nightAction?.target || null;
  const killed = target && target !== guard ? room.players.get(target) : null;
  if (killed) killed.alive = false;

  const seer = alive.find((p) => p.role === '預言家');
  if (seer?.nightAction?.target) {
    const seen = room.players.get(seer.nightAction.target);
    if (seen) seer.inspectResult = { target: seen.name, isWolf: seen.role === '狼人' };
  }

  room.messages.push({
    sender: '系統',
    text: killed ? `昨夜 ${killed.name} 出局。` : '昨夜平安無事。',
    time: timeNow(),
  });

  const winner = resolveWinner(room);
  if (winner) return finishWerewolf(room, winner);
  room.phase = 'day';
  for (const p of room.players.values()) {
    p.vote = null;
    p.nightAction = null;
  }
}

function resolveVotes(room) {
  const alive = [...room.players.values()].filter((p) => p.alive);
  const counts = new Map();
  for (const p of alive) if (p.vote) counts.set(p.vote, (counts.get(p.vote) || 0) + 1);
  const ranked = [...counts.entries()].sort((a, b) => b[1] - a[1]);
  const top = ranked[0];
  const tie = top && ranked[1] && ranked[1][1] === top[1];
  let eliminated = null;
  if (top && !tie) {
    eliminated = room.players.get(top[0]);
    if (eliminated) eliminated.alive = false;
  }
  room.messages.push({
    sender: '系統',
    text: eliminated ? `${eliminated.name} 被投票出局。` : '票數平手，這輪沒有人出局。',
    time: timeNow(),
  });
  const winner = resolveWinner(room);
  if (winner) return finishWerewolf(room, winner);
  room.round += 1;
  room.phase = 'night';
  for (const p of room.players.values()) {
    p.vote = null;
    p.nightAction = null;
  }
  room.messages.push({ sender: '系統', text: `進入第 ${room.round} 夜。`, time: timeNow() });
}

function allAliveVoted(room) {
  const alive = [...room.players.values()].filter((p) => p.alive);
  return alive.length > 0 && alive.every((p) => p.vote);
}


// ─────────────────────────────────────────────────────────────
// 真心話大冒險：隨機抽人 → 選真心話／大冒險 → 全房間文字／語音互動。
// 題目刻意維持輕鬆、安全、適合同學聚會的內容。
const TRUTH_PROMPTS = [
  '最近最常循環播放的一首歌是什麼？',
  '畢業後最想再回去的一個校園地方是哪裡？',
  '你最喜歡班上的哪個活動？',
  '最近讓你笑最久的一件小事是什麼？',
  '如果明天可以多放一天假，你最想做什麼？',
  '你現在最想學會的一項技能是什麼？',
];
const DARE_PROMPTS = [
  '用三個詞形容你今天的心情。',
  '用超正式的語氣說一句「我想吃東西」。',
  '在聊天室發一個你最常用的表情。',
  '用一句話替自己的今天下個標題。',
  '用播報員的語氣說「大家晚上好」。',
  '講一句你最近覺得很有梗的話。',
];

function truthRoomPlayers(room) {
  return [...room.players.values()].map((p) => ({
    name: p.name,
    connected: Boolean(p.ws && p.ws.readyState === WebSocket.OPEN),
    selected: room.selected === p.name,
  }));
}

function publicTruthRoomState(room, viewer) {
  return {
    roomId: room.id,
    host: room.host,
    phase: room.phase,
    maxPlayers: room.maxPlayers,
    players: truthRoomPlayers(room),
    selected: room.selected,
    choice: room.choice,
    prompt: room.prompt,
    messages: room.messages.slice(-80),
  };
}

function truthRoomListPayload() {
  return [...truthRooms.values()]
    .filter((r) => r.phase === 'lobby')
    .map((r) => ({
      roomId: r.id,
      host: r.host,
      players: r.players.size,
      maxPlayers: r.maxPlayers,
    }));
}

function broadcastTruthRoom(room, type = 'truth.state', extra = {}) {
  for (const p of room.players.values()) {
    if (p.ws.readyState === WebSocket.OPEN) {
      p.ws.send(JSON.stringify({ type, ...publicTruthRoomState(room, p.name), ...extra }));
    }
  }
  broadcast({ type: 'truth.rooms', rooms: truthRoomListPayload() });
}

function leaveTruthRoom(user) {
  leaveVoice(user);
  const roomId = user.truthRoomId;
  if (!roomId) return;
  const room = truthRooms.get(roomId);
  user.truthRoomId = null;
  if (!room) return;
  room.players.delete(user.username);
  if (room.host === user.username) room.host = [...room.players.keys()][0] || null;
  if (room.selected === user.username) {
    room.selected = null;
    room.choice = null;
    room.prompt = null;
  }
  if (room.players.size === 0) {
    truthRooms.delete(room.id);
    broadcast({ type: 'truth.rooms', rooms: truthRoomListPayload() });
    return;
  }
  if (room.selected && !room.players.has(room.selected)) {
    room.selected = null;
    room.choice = null;
    room.prompt = null;
    room.phase = 'waiting';
  }
  broadcastTruthRoom(room);
}

function drawTruthPlayer(room) {
  if (room.phase === 'ended') return;
  const candidates = [...room.players.keys()];
  if (candidates.length < 2) throw new Error('至少需要 2 人');
  const selected = candidates[Math.floor(Math.random() * candidates.length)];
  room.selected = selected;
  room.choice = null;
  room.prompt = null;
  room.phase = 'choose';
  room.messages.push({ sender: '系統', text: `抽到 ${selected}，請選真心話或大冒險。`, time: timeNow() });
}

function chooseTruth(room, username, choice) {
  if (room.phase !== 'choose' || room.selected !== username) throw new Error('現在不是你的選擇');
  if (!['truth', 'dare'].includes(choice)) throw new Error('選項無效');
  room.choice = choice;
  room.prompt = choice === 'truth'
    ? TRUTH_PROMPTS[Math.floor(Math.random() * TRUTH_PROMPTS.length)]
    : DARE_PROMPTS[Math.floor(Math.random() * DARE_PROMPTS.length)];
  room.phase = 'active';
  room.messages.push({ sender: '系統', text: `${username} 選了${choice === 'truth' ? '真心話' : '大冒險'}：${room.prompt}`, time: timeNow() });
}

function finishTruthRound(room) {
  const selected = room.selected;
  if (selected) {
    try {
      const reward = 100;
      storage.addCoins(selected, reward, 'game.truth', { roomId: room.id });
      const target = room.players.get(selected);
      if (target?.ws?.readyState === WebSocket.OPEN) {
        target.ws.send(JSON.stringify({
          type: 'truth.round.reward',
          reward,
          profile: storage.fullProfile(selected),
          transactions: storage.transactions(selected, 30),
        }));
      }
    } catch {}
  }
  room.phase = 'waiting';
  room.selected = null;
  room.choice = null;
  room.prompt = null;
}

function voiceKey(type, roomId) {
  return `${type}:${roomId}`;
}

function voiceUsersPayload(key) {
  const group = voiceRooms.get(key);
  if (!group) return [];
  return [...group.entries()].map(([name, value]) => {
    const profile = storage.user(name) || {};
    return {
      name,
      avatarUrl: profile.avatar_url || '',
      muted: Boolean(value.muted),
      connected: Boolean(value.ws && value.ws.readyState === WebSocket.OPEN),
      level: Number(value.level || 0),
    };
  });
}

function broadcastVoiceState(key) {
  const group = voiceRooms.get(key);
  if (!group) return;
  const payload = JSON.stringify({ type: 'voice.state', key, users: voiceUsersPayload(key) });
  for (const value of group.values()) {
    if (value.ws.readyState === WebSocket.OPEN) value.ws.send(payload);
  }
}

function broadcastVoiceRooms() {
  const rooms = storage.voiceRoomDefs().map((room) => ({
    ...room,
    users: voiceRooms.get(voiceKey('global', room.id))?.size || 0,
  }));
  broadcast({ type: 'voice.rooms', rooms });
}

function leaveVoice(user) {
  const key = user.voiceKey;
  if (!key) return;
  const group = voiceRooms.get(key);
  user.voiceKey = null;
  if (!group) return;
  group.delete(user.username);
  const isChannel = key.startsWith('channel:');
  const channelId = isChannel ? key.slice('channel:'.length) : '';
  if (group.size === 0) {
    voiceRooms.delete(key);
    if (isChannel) broadcastChannelVoiceState(channelId);
    broadcastVoiceRooms();
    return;
  }
  broadcastVoiceState(key);
  if (isChannel) broadcastChannelVoiceState(channelId);
  broadcastVoiceRooms();
}

function joinVoice(user, type, roomId) {
  const key = voiceKey(type, roomId);
  if (type === 'werewolf') {
    const room = werewolfRooms.get(roomId);
    if (!room || !room.players.has(user.username)) throw new Error('你不在這個狼人殺房間');
  } else if (type === 'truth') {
    const room = truthRooms.get(roomId);
    if (!room || !room.players.has(user.username)) throw new Error('你不在這個真心話房間');
  } else if (type === 'global') {
    const def = storage.voiceRoomDefs().find((room) => room.id === roomId);
    if (!def) throw new Error('不存在的公共語音房');
    if (def.locked && !storage.isAdmin(user.username)) throw new Error('這個語音房目前鎖定中');
  } else if (type === 'channel') {
    if (roomId !== 'lobby') {
      if (!storage.isChatRoomMember(roomId, user.username)) throw new Error('請先加入聊天室');
      if (!storage.chatRooms(user.username).some((room) => room.id === roomId)) throw new Error('聊天室不存在');
    }
  } else {
    throw new Error('語音房間類型無效');
  }

  leaveVoice(user);
  const group = voiceRooms.get(key) || new Map();
  group.set(user.username, { ws: user.ws, muted: false, level: 0 });
  voiceRooms.set(key, group);
  user.voiceKey = key;
  broadcastVoiceState(key);
  if (type === 'channel') broadcastChannelVoiceState(roomId);
  broadcastVoiceRooms();
}

function setVoiceMuted(user, muted) {
  const group = user.voiceKey ? voiceRooms.get(user.voiceKey) : null;
  const item = group?.get(user.username);
  if (!item) return;
  item.muted = Boolean(muted);
  broadcastVoiceState(user.voiceKey);
  if (String(user.voiceKey || '').startsWith('channel:')) broadcastChannelVoiceState(String(user.voiceKey).slice('channel:'.length));
}

function sendVoiceBinary(user, audio) {
  if (!user.voiceKey || !Buffer.isBuffer(audio) || audio.length === 0 || audio.length > 128 * 1024) return;
  const group = voiceRooms.get(user.voiceKey);
  if (!group) return;
  const header = Buffer.from(JSON.stringify({ sender: user.username }), 'utf8');
  const packet = Buffer.allocUnsafe(4 + header.length + audio.length);
  packet.writeUInt32BE(header.length, 0);
  header.copy(packet, 4);
  audio.copy(packet, 4 + header.length);
  for (const [name, value] of group.entries()) {
    if (name === user.username || value.muted || value.ws.readyState !== WebSocket.OPEN) continue;
    value.ws.send(packet, { binary: true });
  }
}

function sendChatRooms(username) {
  sendToUsername(username, { type: 'chat.rooms', rooms: storage.chatRooms(username) });
}

function broadcastChatRooms() {
  for (const u of online.values()) sendChatRooms(u.username);
}

function channelMembers(roomId) {
  return [...online.values()].filter((u) => storage.isChatRoomMember(roomId, u.username));
}

function sendToChannel(roomId, payload) {
  for (const u of channelMembers(roomId)) {
    if (u.ws.readyState === WebSocket.OPEN) u.ws.send(JSON.stringify(payload));
  }
}

function broadcastChannelVoiceState(roomId) {
  const key = voiceKey('channel', roomId);
  const group = voiceRooms.get(key);
  const payload = JSON.stringify({ type: 'voice.channel.state', roomId, users: voiceUsersPayload(key) });
  for (const u of online.values()) {
    if (u.ws.readyState === WebSocket.OPEN) u.ws.send(payload);
  }
}

wss.on('connection', (ws) => {
  let user = null;

  ws.on('message', (raw, isBinary) => {
    if (isBinary) {
      if (user) sendVoiceBinary(user, Buffer.isBuffer(raw) ? raw : Buffer.from(raw));
      return;
    }

    let event;
    try { event = JSON.parse(raw.toString()); } catch { return; }

    const type = event.type;

    if (type === 'presence.join') {
      const token = String(event.token || '');
      const username = usernameFromToken(token);
      if (!username) {
        ws.send(JSON.stringify({ type: 'auth.error', error: '登入已失效' }));
        ws.close();
        return;
      }

      const profile = storage.fullProfile(username);
      storage.setLastSeen(username);
      user = { username, coins: profile.coins, wins: profile.wins, role: profile.role || 'member', isAdmin: profile.role === 'admin', status: '在線', token, ws, roomId: null, truthRoomId: null, voiceKey: null };
      online.set(ws, user);

      ws.send(JSON.stringify({
        type: 'sync.bootstrap',
        username,
        profile,
        transactions: storage.transactions(username, 30),
    gameHistory: storage.gameHistory(username, 20),
        chat: storage.lobbyHistory(100),
        chatRooms: storage.chatRooms(username),
        members: snapshot(),
        memories: storage.memories(100),
        announcements: storage.announcements(30),
        leaderboard: storage.leaderboard(50),
        voiceRooms: storage.voiceRoomDefs(),
        ...socialSnapshot(username),
      }));
      broadcast({ type: 'presence.snapshot', members: snapshot() });
      return;
    }

    if (!user) return;

    if (type === 'chat.rooms') {
      ws.send(JSON.stringify({ type: 'chat.rooms', rooms: storage.chatRooms(user.username) }));
      return;
    }

    if (type === 'chat.room.create') {
      try {
        const room = storage.createChatRoom(String(event.name || ''), user.username);
        broadcastChatRooms();
        ws.send(JSON.stringify({ type: 'chat.room.created', room, requestId: event.requestId || null }));
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'chat.room.create', error: error.message, requestId: event.requestId || null }));
      }
      return;
    }

    if (type === 'chat.room.join') {
      try {
        const roomId = String(event.roomId || '').trim();
        storage.joinChatRoom(roomId, user.username);
        ws.send(JSON.stringify({ type: 'chat.room.joined', roomId, messages: storage.chatRoomHistory(roomId, 100) }));
        broadcastChatRooms();
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'chat.room.join', error: error.message, requestId: event.requestId || null }));
      }
      return;
    }

    if (type === 'chat.room.leave') {
      try {
        const roomId = String(event.roomId || '').trim();
        if (user.voiceKey === voiceKey('channel', roomId)) leaveVoice(user);
        storage.leaveChatRoom(roomId, user.username);
        ws.send(JSON.stringify({ type: 'chat.room.left', roomId }));
        broadcastChatRooms();
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'chat.room.leave', error: error.message }));
      }
      return;
    }

    if (type === 'chat.room.history') {
      try {
        const roomId = String(event.roomId || '').trim();
        if (!storage.isChatRoomMember(roomId, user.username)) throw new Error('請先加入聊天室');
        ws.send(JSON.stringify({ type: 'chat.room.history', roomId, messages: storage.chatRoomHistory(roomId, 100) }));
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'chat.room.history', error: error.message }));
      }
      return;
    }

    if (type === 'chat.room.send') {
      try {
        const roomId = String(event.roomId || '').trim();
        if (!storage.isChatRoomMember(roomId, user.username)) throw new Error('請先加入聊天室');
        const kind = String(event.kind || 'text');
        const text = String(event.text || '').trim();
        if (kind === 'text' && !text) return;
        if (!['text', 'image', 'video', 'sticker', 'gif'].includes(kind)) throw new Error('不支援的訊息類型');
        let payload = {};
        if (kind === 'image' || kind === 'video') {
          const url = String(event.url || '').trim();
          if (!url) throw new Error('媒體尚未上傳完成');
          payload = { url };
        } else if (kind === 'sticker') {
          payload = { sticker: String(event.sticker || '😂').slice(0, 20) };
        } else if (kind === 'gif') {
          const url = String(event.url || '').trim();
          if (!/^https?:\/\/(?:media(?:\d+)?|i)?\.?giphy\.com\//i.test(url)) throw new Error('GIF 網址不合法');
          payload = { url: url.slice(0, 1000) };
        }
        if (text.length > 500) throw new Error('訊息太長');
        const message = storage.insertChatRoomMessage(roomId, user.username, text, timeNow(), String(event.clientId || ''), kind, payload);
        sendToChannel(roomId, { type: 'chat.room.message', ...message });
        try {
          user.coins = storage.addCoins(user.username, 2, 'chat.room', { roomId, kind });
          balanceBroadcast(user.username, user.coins);
        } catch {}
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'chat.room.send', error: error.message }));
      }
      return;
    }

    if (type === 'chat.edit') {
      try {
        const message = storage.editLobbyMessage(Number(event.messageId), user.username, String(event.text || ''), user.isAdmin);
        broadcast({ type: 'chat.message.updated', ...message });
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'chat.edit', error: error.message }));
      }
      return;
    }

    if (type === 'chat.delete') {
      try {
        const result = storage.deleteLobbyMessage(Number(event.messageId), user.username, user.isAdmin);
        broadcast({ type: 'chat.message.deleted', ...result });
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'chat.delete', error: error.message }));
      }
      return;
    }

    if (type === 'chat.room.edit') {
      try {
        const roomId = String(event.roomId || '').trim();
        const message = storage.editChatRoomMessage(roomId, Number(event.messageId), user.username, String(event.text || ''), user.isAdmin);
        sendToChannel(roomId, { type: 'chat.room.message.updated', ...message });
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'chat.room.edit', error: error.message }));
      }
      return;
    }

    if (type === 'chat.room.delete') {
      try {
        const roomId = String(event.roomId || '').trim();
        const result = storage.deleteChatRoomMessage(roomId, Number(event.messageId), user.username, user.isAdmin);
        sendToChannel(roomId, { type: 'chat.room.message.deleted', ...result });
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'chat.room.delete', error: error.message }));
      }
      return;
    }

    if (type === 'chat.send') {
      const kind = String(event.kind || 'text');
      const text = String(event.text || '').trim();
      if (kind === 'text' && !text) return;
      if (!['text', 'image', 'video', 'sticker', 'gif', 'poll'].includes(kind)) return;
      let payload = {};
      if (kind === 'image' || kind === 'video') {
        const url = String(event.url || '').trim();
        if (!url) throw new Error('媒體尚未上傳完成');
        payload = { url };
      } else if (kind === 'sticker') {
        payload = { sticker: String(event.sticker || '😂').slice(0, 20) };
      } else if (kind === 'poll') {
        const options = Array.isArray(event.options) ? event.options.map((x) => String(x).trim()).filter(Boolean).slice(0, 8) : [];
        if (options.length < 2) { ws.send(JSON.stringify({ type: 'action.error', action: 'chat', error: '投票至少需要 2 個選項' })); return; }
        payload = { question: text.slice(0, 120), options, votes: {} };
      }
      if (text.length > 500) return;
      const createdAt = timeNow();
      const message = storage.insertLobbyMessage(user.username, text, createdAt, String(event.clientId || ''), kind, payload);
      broadcast({ type: 'chat.message', ...message });
      try {
        user.coins = storage.addCoins(user.username, 2, 'chat', { clientId: event.clientId || null, kind });
        balanceBroadcast(user.username, user.coins);
      } catch {}
      return;
    }

    if (type === 'poll.vote') {
      try {
        const messageId = Number(event.messageId);
        const option = Number(event.option);
        const updated = storage.votePoll(messageId, user.username, option);
        broadcast({ type: 'chat.poll.updated', messageId, payload: updated });
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'poll', error: error.message }));
      }
      return;
    }

    if (type === 'private.send') {
      try {
        const target = String(event.target || '').trim();
        const kind = String(event.kind || 'text');
        const text = String(event.text || '').trim();
        if (!target || !storage.user(target)) throw new Error('找不到這位成員');
        if (!['text', 'image', 'video', 'sticker', 'gif'].includes(kind)) throw new Error('不支援的私訊類型');

        let payload = {};
        if (kind === 'image' || kind === 'video') {
          const url = String(event.url || '').trim();
          if (!url) throw new Error('媒體尚未上傳完成');
          payload = { url };
        } else if (kind === 'sticker') {
          payload = { sticker: String(event.sticker || '😂').slice(0, 20) };
        } else if (kind === 'gif') {
          const url = String(event.url || '').trim();
          if (!/^https?:\/\/(?:media(?:\d+)?|i)?\.?giphy\.com\//i.test(url)) throw new Error('GIF 網址不合法');
          payload = { url: url.slice(0, 1000) };
        }

        if (text.length > 500) throw new Error('訊息太長');
        if (kind === 'text' && !text) return;

        const message = storage.insertPrivateMessage(
          user.username,
          target,
          text,
          timeNow(),
          String(event.clientId || ''),
          kind,
          payload,
        );

        sendToUsername(target, { type: 'private.message', ...message });
        ws.send(JSON.stringify({ type: 'private.message', ...message }));

        try {
          user.coins = storage.addCoins(user.username, 1, 'private.chat', { target, kind });
          balanceBroadcast(user.username, user.coins);
        } catch {}
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'private', error: error.message }));
      }
      return;
    }

    if (type === 'private.edit') {
      try {
        const message = storage.editPrivateMessage(Number(event.messageId), user.username, String(event.text || ''));
        sendToUsername(message.target, { type: 'private.message.updated', ...message });
        ws.send(JSON.stringify({ type: 'private.message.updated', ...message }));
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'private.edit', error: error.message }));
      }
      return;
    }

    if (type === 'private.delete') {
      try {
        const result = storage.deletePrivateMessage(Number(event.messageId), user.username);
        sendToUsername(result.target, { type: 'private.message.deleted', ...result });
        ws.send(JSON.stringify({ type: 'private.message.deleted', ...result }));
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'private.delete', error: error.message }));
      }
      return;
    }

    if (type === 'private.history') {
      const other = String(event.target || '').trim();
      if (!other) return;
      ws.send(JSON.stringify({
        type: 'private.history',
        target: other,
        messages: storage.privateHistory(user.username, other, 100),
      }));
      return;
    }

    if (type === 'presence.status') {
      user.status = String(event.status || '在線').slice(0, 20) || '在線';
      storage.setLastSeen(user.username);
      broadcast({ type: 'presence.snapshot', members: snapshot() });
      return;
    }


    if (type === 'social.refresh') {
      sendSocialSnapshot(user.username);
      return;
    }

    if (type === 'friend.request') {
      try {
        const target = String(event.target || '').trim();
        storage.requestFriend(user.username, target);
        sendSocialSnapshot(target);
        ws.send(JSON.stringify({ type: 'friend.result', action: 'request', ok: true, target }));
        sendSocialSnapshot(user.username);
        sendToUsername(target, { type: 'notification', notification: { type: 'friend.request', sender: user.username } });
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'friend', error: error.message }));
      }
      return;
    }

    if (type === 'friend.respond') {
      try {
        const requestId = Number(event.requestId);
        const accept = event.accept === true;
        const result = storage.respondFriendRequest(user.username, requestId, accept);
        sendSocialSnapshot(user.username);
        sendSocialSnapshot(result.sender);
        ws.send(JSON.stringify({ type: 'friend.result', action: accept ? 'accepted' : 'declined', ok: true, friend: result.sender }));
        sendToUsername(result.sender, { type: 'notification', notification: { type: accept ? 'friend.accepted' : 'friend.declined', friend: user.username } });
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'friend', error: error.message }));
      }
      return;
    }

    if (type === 'friend.remove') {
      try {
        const target = String(event.target || '').trim();
        storage.removeFriend(user.username, target);
        sendSocialSnapshot(user.username);
        sendSocialSnapshot(target);
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'friend', error: error.message }));
      }
      return;
    }

    if (type === 'werewolf.invite') {
      const target = String(event.target || '').trim();
      const roomId = String(event.roomId || user.roomId || '').trim();
      const room = werewolfRooms.get(roomId);
      if (!room || room.host !== user.username || room.phase !== 'lobby') {
        ws.send(JSON.stringify({ type: 'action.error', action: 'invite', error: '只有房主可以邀請，且房間必須等待中' }));
        return;
      }
      if (!storage.user(target)) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'invite', error: '找不到這位成員' }));
        return;
      }
      storage.addNotification(target, 'werewolf.invite', { roomId, host: user.username });
      sendToUsername(target, { type: 'notification', notification: { type: 'werewolf.invite', roomId, host: user.username } });
      ws.send(JSON.stringify({ type: 'invite.sent', target, roomId }));
      return;
    }

    if (type === 'truth.list') {
      ws.send(JSON.stringify({ type: 'truth.rooms', rooms: truthRoomListPayload() }));
      return;
    }

    if (type === 'truth.create') {
      try {
        leaveTruthRoom(user);
        const requested = Number(event.maxPlayers || 8);
        if (!Number.isFinite(requested)) throw new Error('房間人數設定無效');
        const maxPlayers = Math.min(10, Math.max(2, Math.trunc(requested)));
        const room = {
          id: randomRoomId(),
          host: user.username,
          maxPlayers,
          phase: 'lobby',
          players: new Map(),
          selected: null,
          choice: null,
          prompt: null,
          messages: [],
        };
        room.players.set(user.username, { name: user.username, ws });
        truthRooms.set(room.id, room);
        user.truthRoomId = room.id;
        ws.send(JSON.stringify({
          type: 'truth.created',
          ...publicTruthRoomState(room, user.username),
          requestId: event.requestId || null,
        }));
        broadcast({ type: 'truth.rooms', rooms: truthRoomListPayload() });
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'truth', error: error.message, requestId: event.requestId || null }));
      }
      return;
    }

    if (type === 'truth.join') {
      try {
        const roomId = String(event.roomId || '').trim();
        const room = truthRooms.get(roomId);
        if (!room) throw new Error('找不到房間');
        if (room.phase !== 'lobby' && room.phase !== 'waiting') throw new Error('房間目前不能加入');
        if (room.players.size >= room.maxPlayers) throw new Error('房間已滿');
        leaveTruthRoom(user);
        room.players.set(user.username, { name: user.username, ws });
        user.truthRoomId = room.id;
        broadcastTruthRoom(room, 'truth.joined', { requestId: event.requestId || null });
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'truth', error: error.message, requestId: event.requestId || null }));
      }
      return;
    }

    if (type === 'truth.leave') {
      leaveTruthRoom(user);
      ws.send(JSON.stringify({ type: 'truth.left' }));
      return;
    }

    if (type === 'truth.draw') {
      try {
        const room = truthRooms.get(user.truthRoomId);
        if (!room || room.host !== user.username) throw new Error('只有房主可以抽人');
        if (!['lobby', 'waiting'].includes(room.phase)) throw new Error('這輪還沒結束');
        drawTruthPlayer(room);
        broadcastTruthRoom(room);
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'truth', error: error.message }));
      }
      return;
    }

    if (type === 'truth.choose') {
      try {
        const room = truthRooms.get(user.truthRoomId);
        const choice = String(event.choice || '');
        if (!room) throw new Error('找不到房間');
        chooseTruth(room, user.username, choice);
        broadcastTruthRoom(room);
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'truth', error: error.message }));
      }
      return;
    }

    if (type === 'truth.finish') {
      try {
        const room = truthRooms.get(user.truthRoomId);
        if (!room || room.host !== user.username || room.phase !== 'active') throw new Error('無法結束這輪');
        finishTruthRound(room);
        broadcastTruthRoom(room);
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'truth', error: error.message }));
      }
      return;
    }

    if (type === 'truth.speak') {
      const room = truthRooms.get(user.truthRoomId);
      const player = room?.players.get(user.username);
      const text = String(event.text || '').trim();
      if (!room || !player || !text || text.length > 300) return;
      room.messages.push({ sender: user.username, text, time: timeNow() });
      broadcastTruthRoom(room);
      return;
    }

    if (type === 'truth.invite') {
      const target = String(event.target || '').trim();
      const roomId = String(event.roomId || user.truthRoomId || '').trim();
      const room = truthRooms.get(roomId);
      if (!room || room.host !== user.username || !['lobby', 'waiting'].includes(room.phase)) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'invite', error: '只有房主可以邀請，且房間必須等待中' }));
        return;
      }
      if (!storage.user(target)) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'invite', error: '找不到這位成員' }));
        return;
      }
      storage.addNotification(target, 'truth.invite', { roomId, host: user.username });
      sendToUsername(target, { type: 'notification', notification: { type: 'truth.invite', roomId, host: user.username } });
      ws.send(JSON.stringify({ type: 'invite.sent', target, roomId }));
      return;
    }

    if (type === 'voice.join') {
      try {
        joinVoice(user, String(event.roomType || ''), String(event.roomId || ''));
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'voice', error: error.message }));
      }
      return;
    }

    if (type === 'voice.leave') {
      leaveVoice(user);
      return;
    }

    if (type === 'voice.mute') {
      setVoiceMuted(user, event.muted === true);
      return;
    }

    if (type === 'voice.level') {
      const group = user.voiceKey ? voiceRooms.get(user.voiceKey) : null;
      const item = group?.get(user.username);
      if (!item) return;
      const level = Math.max(0, Math.min(1, Number(event.level || 0)));
      item.level = Number.isFinite(level) ? level : 0;
      broadcastVoiceState(user.voiceKey);
      if (String(user.voiceKey || '').startsWith('channel:')) broadcastChannelVoiceState(String(user.voiceKey).slice('channel:'.length));
      return;
    }

    if (type === 'leaderboard.list') {
      ws.send(JSON.stringify({ type: 'leaderboard', members: storage.leaderboard(20) }));
      return;
    }

    if (type === 'announcements.list') {
      ws.send(JSON.stringify({ type: 'announcements', announcements: storage.announcements(20) }));
      return;
    }

    if (type === 'game.history') {
      ws.send(JSON.stringify({ type: 'game.history', games: storage.gameHistory(user.username, 50) }));
      return;
    }

    if (type === 'voice.rooms') {
      const rooms = ['lobby', 'chill', 'game'].map((id) => {
        const group = voiceRooms.get(voiceKey('global', id));
        return { id, name: id === 'lobby' ? '大廳' : id === 'chill' ? '聊天房' : '遊戲房', users: group ? group.size : 0 };
      });
      ws.send(JSON.stringify({ type: 'voice.rooms', rooms }));
      return;
    }

    if (type === 'notifications.read') {
      storage.markNotificationsRead(user.username);
      sendSocialSnapshot(user.username);
      return;
    }

    if (type === 'wallet.transfer') {
      try {
        const target = String(event.target || '').trim();
        const amount = Number(event.amount || 0);
        const result = storage.transferCoins(user.username, target, amount);
        user.coins = result.fromBalance;
        ws.send(JSON.stringify({ type: 'wallet.transfer.result', target, amount, coins: result.fromBalance, profile: storage.fullProfile(user.username), transactions: storage.transactions(user.username, 30) }));
        storage.addNotification(target, 'wallet.received', { sender: user.username, amount });
        sendSocialSnapshot(target);
        sendToUsername(target, { type: 'wallet.received', sender: user.username, amount, coins: result.toBalance, profile: storage.fullProfile(target), transactions: storage.transactions(target, 30) });
        balanceBroadcast(user.username, result.fromBalance);
        balanceBroadcast(target, result.toBalance);
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'transfer', error: error.message }));
      }
      return;
    }

    if (type === 'wallet.steal') {
      try {
        const target = String(event.target || '').trim();
        const result = storage.stealCoins(user.username, target);
        user.coins = result.attackerBalance;
        ws.send(JSON.stringify({ type: 'wallet.steal.result', target, stolen: result.stolen, blocked: result.blocked, profile: storage.fullProfile(user.username), transactions: storage.transactions(user.username, 30) }));
        storage.addNotification(target, result.blocked ? 'wallet.steal_blocked' : 'wallet.stolen', { attacker: user.username, stolen: result.stolen });
        sendSocialSnapshot(target);
        sendToUsername(target, { type: 'wallet.stolen', attacker: user.username, stolen: result.stolen, blocked: result.blocked, coins: result.targetBalance, profile: storage.fullProfile(target), transactions: storage.transactions(target, 30) });
        balanceBroadcast(user.username, result.attackerBalance);
        balanceBroadcast(target, result.targetBalance);
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'steal', error: error.message }));
      }
      return;
    }

    if (type === 'wallet.use_item') {
      try {
        const itemId = String(event.itemId || '').trim();
        if (itemId === 'dice') {
          const result = storage.rollDice(user.username);
          user.coins = result.balance;
          ws.send(JSON.stringify({ type: 'item.result', itemId, reward: result.reward, profile: storage.fullProfile(user.username), transactions: storage.transactions(user.username, 30) }));
          balanceBroadcast(user.username, user.coins);
          return;
        }
        if (itemId === 'box') {
          const result = storage.useBox(user.username);
          ws.send(JSON.stringify({ type: 'item.result', itemId, itemGained: result, profile: storage.fullProfile(user.username), transactions: storage.transactions(user.username, 30) }));
          return;
        }
        if (itemId === 'magnet') {
          storage.consumeItem(user.username, itemId);
          activeBoosts.set(user.username, { type: 'magnet', until: Date.now() + 10 * 60 * 1000 });
          ws.send(JSON.stringify({ type: 'item.result', itemId, message: '金幣磁鐵已啟用 10 分鐘', profile: storage.fullProfile(user.username) }));
          return;
        }
        if (itemId === 'shield') {
          throw new Error('防盜護盾會在被偷時自動消耗');
        }
        if (itemId === 'scan') {
          const room = werewolfRooms.get(user.roomId);
          const target = String(event.target || '').trim();
          const player = room?.players.get(target);
          if (!room || room.phase === 'ended' || !player || !player.alive || target === user.username) throw new Error('身份探測器只能偵測狼人殺房間中的其他存活玩家');
          const own = room.players.get(user.username);
          if (!own || !own.alive) throw new Error('你已出局');
          storage.consumeItem(user.username, itemId);
          ws.send(JSON.stringify({ type: 'item.result', itemId, target, isWolf: player.role === '狼人', profile: storage.fullProfile(user.username) }));
          return;
        }
        throw new Error('未知道具');
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'item', error: error.message }));
      }
      return;
    }

    if (type === 'werewolf.list') {
      ws.send(JSON.stringify({ type: 'werewolf.rooms', rooms: roomListPayload() }));
      return;
    }

    if (type === 'werewolf.create') {
      try {
        if (!user?.username || user.ws !== ws) throw new Error('登入連線已失效');
        leaveWerewolfRoom(user);
        const requested = Number(event.maxPlayers || 8);
        if (!Number.isFinite(requested)) throw new Error('房間人數設定無效');
        const maxPlayers = Math.min(10, Math.max(4, Math.trunc(requested)));
        const room = {
          id: randomRoomId(),
          host: user.username,
          maxPlayers,
          phase: 'lobby',
          round: 0,
          players: new Map(),
          messages: [],
          winner: null,
        };
        room.players.set(user.username, {
          name: user.username,
          ws,
          role: null,
          alive: true,
          vote: null,
          nightAction: null,
          inspectResult: null,
        });
        werewolfRooms.set(room.id, room);
        user.roomId = room.id;
        ws.send(JSON.stringify({
          type: 'werewolf.created',
          ...publicRoomState(room, user.username),
          requestId: event.requestId || null,
        }));
        broadcast({ type: 'werewolf.rooms', rooms: roomListPayload() });
      } catch (error) {
        console.error('[werewolf.create]', error);
        ws.send(JSON.stringify({
          type: 'action.error',
          action: 'werewolf',
          error: error?.message || '開房失敗',
          requestId: event.requestId || null,
        }));
      }
      return;
    }

    if (type === 'werewolf.join') {
      try {
        const roomId = String(event.roomId || '').trim();
        if (!roomId) throw new Error('房間代碼不能為空');
        const room = werewolfRooms.get(roomId);
        if (!room) throw new Error('找不到房間');
        if (room.phase !== 'lobby') throw new Error('遊戲已開始');
        if (room.players.size >= room.maxPlayers) throw new Error('房間已滿');
        leaveWerewolfRoom(user);
        room.players.set(user.username, {
          name: user.username,
          ws,
          role: null,
          alive: true,
          vote: null,
          nightAction: null,
          inspectResult: null,
        });
        user.roomId = room.id;
        broadcastRoom(room, 'werewolf.joined', { requestId: event.requestId || null });
      } catch (error) {
        console.error('[werewolf.join]', error);
        ws.send(JSON.stringify({
          type: 'action.error',
          action: 'werewolf',
          error: error?.message || '加入失敗',
          requestId: event.requestId || null,
        }));
      }
      return;
    }

    if (type === 'werewolf.leave') {
      leaveWerewolfRoom(user);
      ws.send(JSON.stringify({ type: 'werewolf.left' }));
      return;
    }

    if (type === 'werewolf.start') {
      try {
        const room = werewolfRooms.get(user.roomId);
        if (!room || room.host !== user.username) throw new Error('只有房主可以開始');
        startWerewolf(room);
        broadcastRoom(room);
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'werewolf', error: error.message }));
      }
      return;
    }

    if (type === 'werewolf.speak') {
      const room = werewolfRooms.get(user.roomId);
      const player = room?.players.get(user.username);
      const text = String(event.text || '').trim();
      if (!room || !player || !player.alive || !['day', 'voting'].includes(room.phase) || !text || text.length > 300) return;
      room.messages.push({ sender: user.username, text, time: timeNow() });
      broadcastRoom(room);
      return;
    }

    if (type === 'werewolf.night') {
      const room = werewolfRooms.get(user.roomId);
      const player = room?.players.get(user.username);
      const target = String(event.target || '').trim();
      if (!room || !player || !player.alive || room.phase !== 'night') return;
      const targetPlayer = room.players.get(target);
      if (!targetPlayer || !targetPlayer.alive) return;
      if (player.role === '狼人' && targetPlayer.role === '狼人') {
        ws.send(JSON.stringify({ type: 'action.error', action: 'werewolf', error: '狼人不能選自己陣營' }));
        return;
      }
      if (!['狼人', '預言家', '守衛'].includes(player.role)) return;
      player.nightAction = { target };
      if (player.role === '預言家') {
        const isWolf = targetPlayer.role === '狼人';
        player.inspectResult = { target, isWolf };
        ws.send(JSON.stringify({ type: 'werewolf.inspect', target, isWolf }));
      }
      const required = [...room.players.values()].filter((p) => p.alive && ['狼人', '預言家', '守衛'].includes(p.role)).length;
      const done = [...room.players.values()].filter((p) => p.alive && ['狼人', '預言家', '守衛'].includes(p.role) && p.nightAction).length;
      if (done >= required) resolveNight(room);
      broadcastRoom(room);
      return;
    }

    if (type === 'werewolf.day_next') {
      const room = werewolfRooms.get(user.roomId);
      if (!room || room.host !== user.username) return;
      if (room.phase === 'night') resolveNight(room);
      else if (room.phase === 'day') room.phase = 'voting';
      else if (room.phase === 'voting' && allAliveVoted(room)) resolveVotes(room);
      broadcastRoom(room);
      return;
    }

    if (type === 'werewolf.vote') {
      const room = werewolfRooms.get(user.roomId);
      const player = room?.players.get(user.username);
      const target = String(event.target || '').trim();
      if (!room || !player || !player.alive || room.phase !== 'voting') return;
      const targetPlayer = room.players.get(target);
      if (!targetPlayer || !targetPlayer.alive || target === user.username) return;
      player.vote = target;
      if (allAliveVoted(room)) resolveVotes(room);
      broadcastRoom(room);
      return;
    }

    if (type === 'admin.users') {
      if (!user.isAdmin) return ws.send(JSON.stringify({ type: 'action.error', action: 'admin', error: '需要管理員權限' }));
      ws.send(JSON.stringify({ type: 'admin.users', users: storage.listUsers(200) }));
      return;
    }
    if (type === 'admin.ban') {
      try {
        if (!user.isAdmin) throw new Error('需要管理員權限');
        const target = String(event.target || '').trim();
        if (!target || target === user.username) throw new Error('無法封禁自己');
        storage.setBanned(target, true);
        sendToUsername(target, { type: 'banned', reason: String(event.reason || '管理員封禁') });
        const bannedSocket = [...online.entries()].find(([, u]) => u.username === target)?.[0];
        if (bannedSocket && bannedSocket.readyState === WebSocket.OPEN) bannedSocket.close(4003, 'banned');
        ws.send(JSON.stringify({ type: 'admin.result', action: 'ban', ok: true, target }));
      } catch (error) { ws.send(JSON.stringify({ type: 'action.error', action: 'admin', error: error.message })); }
      return;
    }
    if (type === 'admin.unban') {
      try { if (!user.isAdmin) throw new Error('需要管理員權限'); const target = String(event.target || '').trim(); storage.setBanned(target, false); ws.send(JSON.stringify({ type: 'admin.result', action: 'unban', ok: true, target })); } catch (error) { ws.send(JSON.stringify({ type: 'action.error', action: 'admin', error: error.message })); }
      return;
    }
    if (type === 'admin.announcement.create') {
      try { if (!user.isAdmin) throw new Error('需要管理員權限'); const title = String(event.title || '').trim(); const body = String(event.body || '').trim(); if (!title || !body) throw new Error('公告內容不能空白'); const announcement = storage.createAnnouncement(title, body); broadcast({ type: 'announcements', announcements: storage.announcements(30) }); ws.send(JSON.stringify({ type: 'admin.result', action: 'announcement.create', announcement })); } catch (error) { ws.send(JSON.stringify({ type: 'action.error', action: 'admin', error: error.message })); }
      return;
    }
    if (type === 'admin.announcement.delete') {
      try { if (!user.isAdmin) throw new Error('需要管理員權限'); storage.deleteAnnouncement(Number(event.id)); broadcast({ type: 'announcements', announcements: storage.announcements(30) }); } catch (error) { ws.send(JSON.stringify({ type: 'action.error', action: 'admin', error: error.message })); }
      return;
    }
    if (type === 'memory.list') {
      ws.send(JSON.stringify({ type: 'memories', memories: storage.memories(100) }));
      return;
    }

    if (type === 'memory.add') {
      try {
        const kind = String(event.kind || 'image');
        if (!['image', 'video'].includes(kind)) throw new Error('回憶類型無效');
        const url = String(event.url || '').trim();
        if (!url) throw new Error('回憶媒體尚未上傳完成');
        const memory = storage.saveMemory(user.username, kind, url, String(event.caption || ''));
        broadcast({ type: 'memory.added', memory });
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'memory', error: error.message }));
      }
      return;
    }

    if (type === 'admin.memory.delete') {
      try { if (!user.isAdmin) throw new Error('需要管理員權限'); storage.deleteMemory(Number(event.id)); broadcast({ type: 'memories', memories: storage.memories(100) }); } catch (error) { ws.send(JSON.stringify({ type: 'action.error', action: 'admin', error: error.message })); }
      return;
    }
    if (type === 'admin.voice.upsert') {
      try { if (!user.isAdmin) throw new Error('需要管理員權限'); const id = String(event.id || '').trim(); const name = String(event.name || '').trim(); if (!id || !name) throw new Error('語音房名稱不能空白'); storage.upsertVoiceRoom(id, name, event.locked === true); ws.send(JSON.stringify({ type: 'voice.rooms', rooms: storage.voiceRoomDefs().map((room) => ({ ...room, users: voiceRooms.get(voiceKey('global', room.id))?.size || 0 })) })); } catch (error) { ws.send(JSON.stringify({ type: 'action.error', action: 'admin', error: error.message })); }
      return;
    }
    if (type === 'admin.voice.delete') {
      try { if (!user.isAdmin) throw new Error('需要管理員權限'); const id = String(event.id || '').trim(); storage.deleteVoiceRoom(id); const group = voiceRooms.get(voiceKey('global', id)); if (group) { for (const entry of group.values()) entry.ws.send(JSON.stringify({ type: 'voice.kicked', roomId: id })); voiceRooms.delete(voiceKey('global', id)); } ws.send(JSON.stringify({ type: 'voice.rooms', rooms: storage.voiceRoomDefs().map((room) => ({ ...room, users: voiceRooms.get(voiceKey('global', room.id))?.size || 0 })) })); } catch (error) { ws.send(JSON.stringify({ type: 'action.error', action: 'admin', error: error.message })); }
      return;
    }
    if (type === 'admin.voice.lock') {
      try { if (!user.isAdmin) throw new Error('需要管理員權限'); const id = String(event.id || '').trim(); storage.setVoiceRoomLocked(id, event.locked === true); ws.send(JSON.stringify({ type: 'voice.rooms', rooms: storage.voiceRoomDefs().map((room) => ({ ...room, users: voiceRooms.get(voiceKey('global', room.id))?.size || 0 })) })); } catch (error) { ws.send(JSON.stringify({ type: 'action.error', action: 'admin', error: error.message })); }
      return;
    }
    if (type === 'profile.avatar.upload') {
      try {
        const url = String(event.url || '').trim();
        if (!url) throw new Error('頭像尚未上傳完成');
        storage.setAvatar(user.username, url);
        ws.send(JSON.stringify({ type: 'profile.avatar.result', avatarUrl: url, profile: storage.fullProfile(user.username) }));
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'avatar', error: error.message }));
      }
      return;
    }

    if (type === 'wallet.claim_daily') {
      try {
        const result = storage.claimDaily(user.username);
        user.coins = result.profile.coins;
        ws.send(JSON.stringify({ type: 'daily.result', ...result }));
        balanceBroadcast(user.username, user.coins);
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'daily', error: error.message }));
      }
      return;
    }

    if (type === 'wallet.shop_buy') {
      const itemId = String(event.itemId || '').trim();
      const cost = ITEM_PRICES[itemId];
      if (!itemId || !Number.isInteger(cost)) return;
      try {
        const result = storage.buyItem(user.username, itemId, cost);
        user.coins = result.coins;
        ws.send(JSON.stringify({
          type: 'shop.result',
          itemId,
          profile: result,
        }));
        balanceBroadcast(user.username, user.coins);
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'shop', error: error.message }));
      }
      return;
    }

    if (type === 'game.reward') {
      const gameId = String(event.gameId || '');
      const fixedRewards = { truth: 100, daily: 50 };
      if (!Object.prototype.hasOwnProperty.call(fixedRewards, gameId)) return;
      const reward = fixedRewards[gameId];
      try {
        let actualReward = reward;
        const boost = activeBoosts.get(user.username);
        if (boost && boost.type === 'magnet') {
          if (boost.until > Date.now()) actualReward = Math.floor(actualReward * 1.3);
          else activeBoosts.delete(user.username);
        }
        const balance = storage.addCoins(user.username, actualReward, `game.${gameId}`, { roomId: event.roomId || null });
        storage.recordGame(user.username, gameId, 'completed', actualReward, { roomId: event.roomId || null });
        user.coins = balance;
        ws.send(JSON.stringify({
          type: 'game.reward.result',
          gameId,
          reward: actualReward,
          profile: storage.fullProfile(user.username),
          transactions: storage.transactions(user.username, 30),
        }));
        balanceBroadcast(user.username, user.coins);
      } catch (error) {
        ws.send(JSON.stringify({ type: 'action.error', action: 'game', error: error.message }));
      }
      return;
    }
  });

  ws.on('close', () => {
    if (user) {
      leaveWerewolfRoom(user);
      leaveTruthRoom(user);
      leaveVoice(user);
      online.delete(ws);
      storage.setLastSeen(user.username);
      broadcast({ type: 'presence.snapshot', members: snapshot() });
    }
  });
});

storage.initStorage(DATA_DIR).then(() => {
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`雷霆611 V1.0 Server listening on http://0.0.0.0:${PORT}`);
    console.log('Database: server/data/thunder611.sqlite');
  });
}).catch((error) => {
  console.error('Database init failed:', error);
  process.exit(1);
});
