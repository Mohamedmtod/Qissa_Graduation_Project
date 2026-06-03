#!/usr/bin/env node
import { spawnSync } from 'node:child_process';

function arg(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? null : process.argv[index + 1] || null;
}

const feedbackId = arg('--feedback-id');
if (!feedbackId) {
  console.error('Usage: node get_feedback_context.mjs --feedback-id fb_xxx');
  process.exit(1);
}

const escaped = feedbackId.replaceAll("'", "''");
const sql = `SELECT feedback_id, reason, chat_debug_id, turn_id, created_at FROM ai_chat_feedback_debug WHERE feedback_id='${escaped}' LIMIT 1;`;

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
const row = parsed.at(-1)?.results?.[0];
if (!row) {
  console.error(`Feedback not found: ${feedbackId}`);
  process.exit(1);
}

console.log(`# AI Chat Feedback Context ${row.feedback_id}\n`);
console.log(`reason: ${row.reason}`);
console.log(`chatDebugId: ${row.chat_debug_id || 'missing'}`);
console.log(`turnId: ${row.turn_id}`);
console.log(`createdAt: ${row.created_at}`);
console.log('\nRun:');
console.log(`node testing_tools/ai_chat_debug/get_chat_debug.mjs --chat-debug-id ${row.chat_debug_id}`);
