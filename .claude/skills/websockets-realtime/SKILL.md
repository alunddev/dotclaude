---
name: websockets-realtime
description: WebSocket and real-time communication patterns — connection lifecycle, heartbeats, reconnection with backoff, message ordering, fan-out at scale, auth, scaling beyond single-node. Covers native WS, Socket.IO, SSE, WebTransport. Use when building chat, live cursors, notifications, dashboards, or any push-based UI.
---

# WebSockets + real-time patterns

Real-time looks simple until you have 50K concurrent connections, a node crash, or a flaky network.

## When to use this skill

- Building chat, live cursors, presence indicators
- Streaming server-pushed updates (dashboards, notifications, prices)
- Multi-user collaboration
- Scaling real-time beyond a single server
- Choosing between WebSocket, SSE, WebTransport, long-polling

## Picking the transport

| Need | Transport |
|---|---|
| Server-to-client one-way push (notifications, updates) | **SSE** (Server-Sent Events) |
| Bidirectional, low latency | **WebSocket** |
| Need fallback to long-polling, rooms, broadcast | **Socket.IO** |
| Modern, datagram + reliable streams, HTTP/3 | **WebTransport** (experimental) |
| Truly enterprise pub/sub with offline | **MQTT** (over WS often) |

**Default**: SSE if one-way, native WebSocket if bidirectional, Socket.IO if you need rooms + auto-reconnect out of the box.

## Connection lifecycle

```
[Client]                          [Server]
   │                                  │
   ├─── HTTP Upgrade: WebSocket ─────►│
   │◄────── 101 Switching Protocols ──┤
   │                                  │
   ├─── auth message ────────────────►│
   │◄─── auth ack ────────────────────┤
   │                                  │
   │◄═══ data frames (both ways) ════►│
   │                                  │
   ├─── close frame ────────────────►│  (or)  │◄── close frame ──────
   │                                  │
```

Always model:
- **Connecting** — not yet ready to send
- **Open** — ready
- **Closing** — graceful shutdown in progress
- **Closed** — terminal

## Heartbeats / keepalive

Networks silently drop idle connections. You won't know until you try to send.

```javascript
// Client
let pongTimer;
ws.addEventListener('open', () => {
  setInterval(() => ws.send(JSON.stringify({ type: 'ping' })), 30_000);
});
ws.addEventListener('message', (e) => {
  const msg = JSON.parse(e.data);
  if (msg.type === 'pong') {
    clearTimeout(pongTimer);
  }
});

// After sending ping:
pongTimer = setTimeout(() => ws.close(4000, 'no pong'), 10_000);
```

Server responds to `ping` with `pong`. Frame-level pings (`ws.ping()` in `ws` library) work too; app-level is more visible.

**Intervals**:
- Mobile networks: 15–30s (NATs are aggressive)
- WiFi/wired: 60s is usually fine
- Behind cloud load balancers: respect the LB's idle timeout (often 60s) and ping more frequently

## Reconnection with exponential backoff

```javascript
class ReconnectingWS {
  constructor(url) {
    this.url = url;
    this.attempts = 0;
    this.connect();
  }

  connect() {
    this.ws = new WebSocket(this.url);
    this.ws.addEventListener('open', () => {
      this.attempts = 0;
      // resubscribe to any prior subscriptions
      this.onopen?.();
    });
    this.ws.addEventListener('close', (e) => {
      if (e.code === 1000) return; // normal close, don't reconnect
      this.scheduleReconnect();
    });
  }

  scheduleReconnect() {
    const delay = Math.min(30_000, 500 * Math.pow(2, this.attempts));
    const jittered = delay * (0.5 + Math.random() * 0.5);
    this.attempts++;
    setTimeout(() => this.connect(), jittered);
  }
}
```

Rules:
- Cap the delay (30s typical).
- Add jitter.
- Reset attempts on successful open.
- Don't reconnect on intentional close (code 1000).
- Resubscribe / reissue state on reconnect (don't assume server remembers).

## Message ordering and idempotency

WebSocket guarantees order within a single connection. Reconnection breaks that:

- Server kept sending; client missed messages while disconnected.
- Or client sent before realizing connection was dead; server got nothing.

**Solutions**:

### Server-assigned sequence IDs

```json
{"type": "msg", "seq": 1729, "data": {...}}
```

Client tracks last-seen seq; on reconnect, sends `{"type": "resume", "last_seen": 1729}`. Server replays from there if it has the history.

### Idempotency keys for client → server

Client assigns an ID per message it sends. Server dedupes:

```json
{"type": "send_message", "client_id": "msg_01H8...", "text": "hi"}
```

If the client retries due to no ack, server sees the same `client_id` and doesn't double-process.

## Authentication

WebSocket has no native auth header (the browser's `WebSocket` API doesn't let you set them). Options:

### Token in subprotocol header

```javascript
new WebSocket('wss://api/ws', ['bearer.' + accessToken]);
```

```python
# Server side (FastAPI):
@app.websocket("/ws")
async def ws(websocket: WebSocket):
    subprotocols = websocket.headers.get('sec-websocket-protocol', '').split(',')
    token = next((s.split('.')[1] for s in subprotocols if s.startswith('bearer.')), None)
    user = verify_token(token)
    if not user:
        await websocket.close(code=4401)
        return
    await websocket.accept(subprotocol=f'bearer.{token}')
```

### Cookie-based (server-rendered apps)

If the WS endpoint is same-origin, browser sends cookies on upgrade. Auth check is normal middleware.

### Auth message after connect

Open with no auth, server expects `{"type": "auth", "token": "..."}` within 5s or closes.

```javascript
ws.addEventListener('open', () => ws.send(JSON.stringify({type:'auth', token})));
```

Simpler but the connection is open before auth — keep `accept` short and DROP unauthenticated immediately.

**Never** put tokens in the URL: `wss://api/ws?token=...` leaks to logs.

## Scaling beyond one node

With multiple WS servers behind a load balancer, two clients connected to different nodes can't talk to each other unless you bridge:

### Pattern: pub/sub bridge

```
[Client A] ←→ [WS Node 1] ──┐
                            ├──→ [Redis pub/sub or NATS]
[Client B] ←→ [WS Node 2] ──┘
```

When Node 1 receives a message destined for room X, it `PUBLISH room:X message` to Redis. Node 2 (subscribed to `room:X`) receives and forwards to its connected clients in that room.

Socket.IO has this built-in (`socket.io-redis-adapter`). For raw WS:

```typescript
// Node listens for cluster-wide events
redis.subscribe('room:lobby');
redis.on('message', (channel, msg) => {
  const room = channel.split(':')[1];
  for (const client of localClientsByRoom.get(room) ?? []) {
    client.send(msg);
  }
});

// Publishing a broadcast
async function broadcast(room, message) {
  await redis.publish(`room:${room}`, JSON.stringify(message));
}
```

### Sticky sessions

For maintaining session-state per node, configure the LB for sticky sessions (cookie or IP hash). Otherwise reconnections can land on a node without your subscription state.

## Backpressure

If a slow client can't keep up, your server's send buffer grows unbounded → memory pressure → OOM.

```typescript
// Native ws library
ws.bufferedAmount  // bytes queued
if (ws.bufferedAmount > 1_000_000) {
  ws.close(1013, 'too slow');  // 1013 = try again later
}
```

Drop slow clients or stop sending non-critical events.

## SSE alternative (often the right answer)

If you only need server → client, SSE is simpler:

```javascript
// Client
const es = new EventSource('/events');
es.onmessage = (e) => console.log(JSON.parse(e.data));
es.addEventListener('order', (e) => handleOrder(e.data));
```

```python
# Server (FastAPI / Starlette)
from sse_starlette.sse import EventSourceResponse

async def event_stream():
    while True:
        msg = await queue.get()
        yield {"event": msg.type, "data": json.dumps(msg.data)}

@app.get('/events')
async def events():
    return EventSourceResponse(event_stream())
```

SSE auto-reconnects, supports event IDs / resume, works over HTTP/2 (multiplexed). Use for notifications, dashboards, anything one-way.

## Common bugs

- **Forgot to clean up event listeners** on the client → memory leak per reconnect.
- **No close handler** → app silently stops getting updates.
- **Resubscribing in reconnect doesn't wait for `open`** → message lost.
- **Sending JSON without `JSON.stringify`** → server sees `[object Object]`.
- **Different message schema for "first connect" vs "reconnect resume"** without a unifying type field.
- **No backpressure check** → server runs out of memory at 10K idle slow clients.
- **Auth check at connect but not on individual subscriptions** → privilege escalation by joining unauthorized rooms.

## Anti-patterns

- **WebSocket for things SSE would do.** Bidirectional has more failure modes; only use it when you actually need bidirectional.
- **Using WS for request-response.** That's what HTTP is for. WS shines when the server has events the client didn't ask for.
- **No idempotency on user-initiated messages.** Reconnect → resend → duplicate post.
- **Storing all message history in WS server memory.** Use Redis / DB; WS server should be stateless or near-stateless.
- **TCP keepalive instead of app-level pings.** TCP keepalive defaults are minutes; you want seconds for detection.
- **Trusting client claims** in messages without server-side validation, just because they're "authenticated".

## Observability

Track:
- Active connections (gauge)
- Connection lifetime distribution (histogram)
- Messages sent / received per second (counter, by type)
- Disconnections by reason / close code (counter)
- Buffer-overflow disconnects (counter — alert if non-zero)
- Reconnect rate (high = network issues or auth bugs)

Log connection open/close with: user_id, ip, user-agent, disconnect reason, duration.
