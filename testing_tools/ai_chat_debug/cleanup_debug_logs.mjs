#!/usr/bin/env node
import { spawnSync } from 'node:child_process';

const DEFAULT_DATABASE = 'qissa_ai_chat_debug';

function arg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  return index === -1 ? fallback : process.argv[index + 1] || fallback;
}

function hasFlag(name) {
  return process.argv.includes(name);
}

function parseDays(name, fallback) {
  const raw = arg(name, String(fallback));
  const value = Number.parseInt(raw, 10);
  if (!Number.isFinite(value) || value < 1 || value > 3650) {
    throw new Error(`${name} must be an integer between 1 and 3650`);
  }
  return value;
}

function printUsage() {
  console.log(`Usage:
  node testing_tools/ai_chat_debug/cleanup_debug_logs.mjs [options]

Options:
  --turn-days N       Delete debug turns older than N days. Default: 30
  --feedback-days N   Delete feedback debug rows older than N days. Default: 90
  --session-days N    Delete orphan sessions older than N days. Default: 90
  --database NAME     D1 database name. Default: ${DEFAULT_DATABASE}
  --local             Use local D1 instead of --remote.
  --write             Actually delete rows. Default is dry-run only.
  --help              Show this help.

Examples:
  node testing_tools/ai_chat_debug/cleanup_debug_logs.mjs --turn-days 30 --feedback-days 90
  node testing_tools/ai_chat_debug/cleanup_debug_logs.mjs --turn-days 30 --feedback-days 90 --write
`);
}

function retentionSql(days) {
  return `datetime('now', '-${days} days')`;
}

function countTurnsSql(days) {
  return `SELECT COUNT(*) AS count FROM ai_chat_debug_turns WHERE inserted_at < ${retentionSql(days)};`;
}

function countFeedbackSql(days) {
  return `SELECT COUNT(*) AS count FROM ai_chat_feedback_debug WHERE inserted_at < ${retentionSql(days)};`;
}

function countOrphanSessionsSql(days) {
  return `
SELECT COUNT(*) AS count
FROM ai_chat_debug_sessions s
WHERE s.inserted_at < ${retentionSql(days)}
  AND NOT EXISTS (
    SELECT 1 FROM ai_chat_debug_turns t WHERE t.chat_debug_id = s.chat_debug_id
  )
  AND NOT EXISTS (
    SELECT 1 FROM ai_chat_feedback_debug f WHERE f.chat_debug_id = s.chat_debug_id
  );`;
}

function deleteTurnsSql(days) {
  return `DELETE FROM ai_chat_debug_turns WHERE inserted_at < ${retentionSql(days)};`;
}

function deleteFeedbackSql(days) {
  return `DELETE FROM ai_chat_feedback_debug WHERE inserted_at < ${retentionSql(days)};`;
}

function deleteOrphanSessionsSql(days) {
  return `
DELETE FROM ai_chat_debug_sessions
WHERE inserted_at < ${retentionSql(days)}
  AND NOT EXISTS (
    SELECT 1 FROM ai_chat_debug_turns t
    WHERE t.chat_debug_id = ai_chat_debug_sessions.chat_debug_id
  )
  AND NOT EXISTS (
    SELECT 1 FROM ai_chat_feedback_debug f
    WHERE f.chat_debug_id = ai_chat_debug_sessions.chat_debug_id
  );`;
}

function wranglerArgs(database, sql, useRemote) {
  const args = ['wrangler', 'd1', 'execute', database, '--json', '--command', normalizeSql(sql)];
  if (useRemote) args.splice(4, 0, '--remote');
  return process.platform === 'win32' ? ['/c', 'npx', ...args] : args;
}

function normalizeSql(sql) {
  return String(sql || '').replace(/\s+/g, ' ').trim();
}

function runD1(database, sql, useRemote) {
  const command = process.platform === 'win32' ? 'cmd.exe' : 'npx';
  const result = spawnSync(command, wranglerArgs(database, sql, useRemote), {
    encoding: 'utf8',
  });
  if (result.status !== 0) {
    throw new Error(result.error?.message || result.stderr || result.stdout || 'wrangler d1 execute failed');
  }
  try {
    return parseWranglerJson(result.stdout);
  } catch (error) {
    throw new Error(`wrangler returned non-JSON output: ${error.message}`);
  }
}

function parseWranglerJson(output) {
  const trimmed = String(output || '').trim();
  if (!trimmed) {
    throw new Error('empty output');
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

function firstCount(parsed) {
  const row = findCountRow(parsed);
  const value = Number.parseInt(String(row?.count ?? '0'), 10);
  return Number.isFinite(value) ? value : 0;
}

function findCountRow(value) {
  if (!value) return null;
  if (Array.isArray(value)) {
    for (const item of value) {
      const row = findCountRow(item);
      if (row) return row;
    }
    return null;
  }
  if (typeof value === 'object') {
    if (Object.prototype.hasOwnProperty.call(value, 'count')) {
      return value;
    }
    if (Array.isArray(value.results)) {
      const row = findCountRow(value.results);
      if (row) return row;
    }
    if (Array.isArray(value.result)) {
      const row = findCountRow(value.result);
      if (row) return row;
    }
  }
  return null;
}

function count(database, sql, useRemote) {
  return firstCount(runD1(database, sql, useRemote));
}

function deleteRows(database, sql, useRemote) {
  runD1(database, sql, useRemote);
}

function printLine(label, before, after = null) {
  if (after === null) {
    console.log(`${label}: ${before}`);
    return;
  }
  console.log(`${label}: before=${before} after=${after} deleted=${Math.max(before - after, 0)}`);
}

if (hasFlag('--help')) {
  printUsage();
  process.exit(0);
}

try {
  const turnDays = parseDays('--turn-days', 30);
  const feedbackDays = parseDays('--feedback-days', 90);
  const sessionDays = parseDays('--session-days', 90);
  const database = arg('--database', DEFAULT_DATABASE);
  const write = hasFlag('--write');
  const useRemote = !hasFlag('--local');

  console.log('# AI Chat Debug Retention Cleanup');
  console.log(`mode: ${write ? 'write' : 'dry-run'}`);
  console.log(`database: ${database}`);
  console.log(`target: ${useRemote ? 'remote' : 'local'}`);
  console.log(`turnDays: ${turnDays}`);
  console.log(`feedbackDays: ${feedbackDays}`);
  console.log(`sessionDays: ${sessionDays}`);
  console.log('');

  const beforeTurns = count(database, countTurnsSql(turnDays), useRemote);
  const beforeFeedback = count(database, countFeedbackSql(feedbackDays), useRemote);
  const beforeSessions = count(database, countOrphanSessionsSql(sessionDays), useRemote);

  if (!write) {
    printLine('debugTurnsEligible', beforeTurns);
    printLine('feedbackRowsEligible', beforeFeedback);
    printLine('orphanSessionsEligible', beforeSessions);
    console.log('');
    console.log('dry-run only: pass --write to delete eligible rows.');
    process.exit(0);
  }

  deleteRows(database, deleteTurnsSql(turnDays), useRemote);
  deleteRows(database, deleteFeedbackSql(feedbackDays), useRemote);
  deleteRows(database, deleteOrphanSessionsSql(sessionDays), useRemote);

  const afterTurns = count(database, countTurnsSql(turnDays), useRemote);
  const afterFeedback = count(database, countFeedbackSql(feedbackDays), useRemote);
  const afterSessions = count(database, countOrphanSessionsSql(sessionDays), useRemote);

  printLine('debugTurnsEligible', beforeTurns, afterTurns);
  printLine('feedbackRowsEligible', beforeFeedback, afterFeedback);
  printLine('orphanSessionsEligible', beforeSessions, afterSessions);
} catch (error) {
  console.error(`cleanup failed: ${error.message}`);
  process.exit(1);
}
