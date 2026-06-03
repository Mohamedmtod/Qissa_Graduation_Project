#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';

function arg(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? null : process.argv[index + 1] || null;
}

function renderSession(session) {
  const turns = Array.isArray(session.turns) ? session.turns : [];
  const lines = [
    `# AI Chat Debug Session ${session.chatDebugId || 'unknown'}`,
    '',
    `turnCount: ${turns.length}`,
    '',
  ];
  for (const turn of turns) {
    lines.push(`## Turn ${turn.index || turns.indexOf(turn) + 1}`);
    if (turn.userMessageRedacted) lines.push(`User: ${turn.userMessageRedacted}`);
    if (turn.assistantReplyRedacted) lines.push(`Assistant: ${turn.assistantReplyRedacted}`);
    lines.push(`Route: ${turn.route || 'unknown'}`);
    lines.push(`Source: ${turn.source || 'unknown'}`);
    if (turn.toolName || turn.toolStatus) {
      lines.push(`Tool: ${turn.toolName || 'none'} / ${turn.toolStatus || 'unknown'}`);
    }
    if (turn.finalProductIds?.length) {
      lines.push(`Products: ${turn.finalProductIds.join(', ')}`);
    }
    if (turn.turnDurationMs || turn.workerLatencyMs) {
      lines.push(`Latency: ${turn.turnDurationMs || turn.workerLatencyMs}ms`);
    }
    if (turn.feedbackReason) lines.push(`Feedback: ${turn.feedbackReason}`);
    if (turn.noMatchReason) lines.push(`No match: ${turn.noMatchReason}`);
    if (turn.failureReason) lines.push(`Failure: ${turn.failureReason}`);
    lines.push('');
  }
  return lines.join('\n');
}

async function loadFromJsonFile(path) {
  return JSON.parse(await readFile(path, 'utf8'));
}

function loadFromD1(chatDebugId) {
  const turnsSql = `SELECT chat_debug_id AS chatDebugId, turn_id AS turnId, request_id AS requestId, session_id_hash AS sessionIdHash, user_message_redacted AS userMessageRedacted, assistant_reply_redacted AS assistantReplyRedacted, reply_type AS replyType, route, action, source, tool_name AS toolName, tool_status AS toolStatus, render_intent AS renderIntent, worker_latency_ms AS workerLatencyMs, turn_duration_ms AS turnDurationMs, product_count AS productCount, final_product_ids_json AS finalProductIdsJson, no_match_reason AS noMatchReason, failure_reason AS failureReason, feedback_reason AS feedbackReason FROM ai_chat_debug_turns WHERE chat_debug_id='${chatDebugId.replaceAll("'", "''")}' ORDER BY created_at, id;`;
  const query = turnsSql;
  const command = process.platform === 'win32' ? 'cmd.exe' : 'npx';
  const args = process.platform === 'win32'
    ? ['/c', 'npx', 'wrangler', 'd1', 'execute', 'qissa_ai_chat_debug', '--remote', '--json', '--command', query]
    : ['wrangler', 'd1', 'execute', 'qissa_ai_chat_debug', '--remote', '--json', '--command', query];
  const result = spawnSync(command, args, {
    encoding: 'utf8',
  });
  if (result.status !== 0) {
    throw new Error(result.error?.message || result.stderr || result.stdout || 'wrangler d1 execute failed');
  }
  const parsed = parseWranglerJson(result.stdout);
  const turnsResult = findRows(parsed);
  return {
    chatDebugId,
    turns: turnsResult.map((turn, index) => ({
      ...turn,
      index: index + 1,
      finalProductIds: JSON.parse(turn.finalProductIdsJson || '[]'),
    })),
  };
}

function parseWranglerJson(output) {
  const trimmed = String(output || '').trim();
  if (!trimmed) {
    throw new Error('empty wrangler output');
  }
  try {
    return JSON.parse(trimmed);
  } catch (_) {
    const arrayStart = trimmed.indexOf('[{');
    if (arrayStart !== -1) {
      return JSON.parse(extractJsonBlock(trimmed, arrayStart));
    }
    const objectStart = trimmed.indexOf('{');
    if (objectStart !== -1) {
      return JSON.parse(extractJsonBlock(trimmed, objectStart));
    }
    throw new Error(`Unexpected token ${trimmed[0] || 'EOF'}`);
  }
}

function extractJsonBlock(output, start) {
  const opener = output[start];
  const closer = opener === '[' ? ']' : '}';
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let index = start; index < output.length; index += 1) {
    const char = output[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === '\\') {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }
    if (char === '"') {
      inString = true;
      continue;
    }
    if (char === opener) {
      depth += 1;
      continue;
    }
    if (char === closer) {
      depth -= 1;
      if (depth === 0) {
        return output.slice(start, index + 1);
      }
    }
  }
  throw new Error('could not find complete JSON block');
}

function findRows(value) {
  if (!value) return [];
  if (Array.isArray(value)) {
    for (const item of value) {
      const rows = findRows(item);
      if (rows.length) return rows;
    }
    return [];
  }
  if (typeof value === 'object') {
    if (Array.isArray(value.results)) return value.results;
    if (Array.isArray(value.result)) return findRows(value.result);
  }
  return [];
}

const chatDebugId = arg('--chat-debug-id');
const jsonFile = arg('--json-file');

if (!chatDebugId && !jsonFile) {
  console.error('Usage: node get_chat_debug.mjs --chat-debug-id chat_dbg_xxx OR --json-file debug.json');
  process.exit(1);
}

try {
  const session = jsonFile ? await loadFromJsonFile(jsonFile) : loadFromD1(chatDebugId);
  console.log(renderSession(session));
} catch (error) {
  console.error(`Failed to load chat debug session: ${error.message}`);
  process.exit(1);
}
