#!/usr/bin/env node
import { spawnSync } from 'node:child_process';

function arg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  return index === -1 ? fallback : process.argv[index + 1] || fallback;
}

const limit = Number.parseInt(arg('--limit', '20'), 10) || 20;
const sql = `SELECT feedback_id, reason, chat_debug_id, turn_id, created_at FROM ai_chat_feedback_debug ORDER BY inserted_at DESC LIMIT ${Math.min(Math.max(limit, 1), 100)};`;

const command = process.platform === 'win32' ? 'cmd.exe' : 'npx';
const args = process.platform === 'win32'
  ? ['/c', 'npx', 'wrangler', 'd1', 'execute', 'qissa_ai_chat_debug', '--remote', '--json', '--command', sql]
  : ['wrangler', 'd1', 'execute', 'qissa_ai_chat_debug', '--remote', '--json', '--command', sql];
const result = spawnSync(command, args, {
  encoding: 'utf8',
});

if (result.status !== 0) {
  console.error(result.error?.message || result.stderr || result.stdout || 'wrangler d1 execute failed');
  process.exit(1);
}

const parsed = JSON.parse(result.stdout);
const rows = parsed.at(-1)?.results || [];
console.log('# Recent AI Chat Bad Feedback\n');
for (const row of rows) {
  console.log(`- ${row.feedback_id} | ${row.reason} | ${row.chat_debug_id || 'no-chat-id'} | ${row.turn_id} | ${row.created_at}`);
}
