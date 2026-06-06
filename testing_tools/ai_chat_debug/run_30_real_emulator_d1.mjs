#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = fileURLToPath(new URL('.', import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const mobileApp = join(repoRoot, 'mobile_app');
const timestamp = new Date()
  .toISOString()
  .replace(/[-:]/g, '')
  .replace(/\..+/, '')
  .replace('T', '_');
const suite = process.env.AI_CHAT_RUN_SUITE || 'ai_chat_real_emulator_30';
const artifactRoot = suite === 'ai_chat_real_emulator_150'
  ? 'ai_chat_real_emulator_150'
  : suite === 'ai_chat_real_emulator_120'
  ? 'ai_chat_real_emulator_120'
  : suite === 'ai_chat_real_emulator_90'
  ? 'ai_chat_real_emulator_90'
  : suite === 'ai_chat_real_emulator_60'
  ? 'ai_chat_real_emulator_60'
  : suite === 'ai_chat_supplemental_91_120'
  ? 'ai_chat_supplemental_91_120'
  : suite === 'ai_chat_supplemental_121_150'
  ? 'ai_chat_supplemental_121_150'
  : suite === 'ai_chat_supplemental_61_90'
  ? 'ai_chat_supplemental_61_90'
  : suite === 'ai_chat_supplemental_31_60'
  ? 'ai_chat_supplemental_31_60'
  : 'ai_chat_real_emulator_30';
const runId = `${artifactRoot}_${timestamp}`;
const artifactDir = join(
  repoRoot,
  'test_artifacts',
  artifactRoot,
  timestamp,
);
mkdirSync(artifactDir, { recursive: true });

const device = process.env.AI_CHAT_30_DEVICE || 'emulator-5554';
const testTimeout = process.env.AI_CHAT_30_TEST_TIMEOUT || '45m';
const allScenarioIds = Array.from({ length: 60 }, (_, index) => `S${String(index + 1).padStart(2, '0')}`).join(',');
const all90ScenarioIds = Array.from({ length: 90 }, (_, index) => `S${String(index + 1).padStart(2, '0')}`).join(',');
const all120ScenarioIds = Array.from({ length: 120 }, (_, index) => `S${String(index + 1).padStart(2, '0')}`).join(',');
const all150ScenarioIds = Array.from({ length: 150 }, (_, index) => `S${String(index + 1).padStart(2, '0')}`).join(',');
const supplementalScenarioIds = Array.from({ length: 30 }, (_, index) => `S${index + 31}`).join(',');
const supplemental6190ScenarioIds = Array.from({ length: 30 }, (_, index) => `S${index + 61}`).join(',');
const supplemental91120ScenarioIds = Array.from({ length: 30 }, (_, index) => `S${index + 91}`).join(',');
const supplemental121150ScenarioIds = Array.from({ length: 30 }, (_, index) => `S${index + 121}`).join(',');
const scenarioIds = (
  process.env.AI_CHAT_30_SCENARIO_IDS?.trim() ||
  (suite === 'ai_chat_real_emulator_150'
    ? all150ScenarioIds
    : suite === 'ai_chat_real_emulator_120'
    ? all120ScenarioIds
    : suite === 'ai_chat_real_emulator_90'
    ? all90ScenarioIds
    : suite === 'ai_chat_real_emulator_60'
      ? allScenarioIds
      : suite === 'ai_chat_supplemental_91_120'
        ? supplemental91120ScenarioIds
      : suite === 'ai_chat_supplemental_121_150'
        ? supplemental121150ScenarioIds
      : suite === 'ai_chat_supplemental_61_90'
        ? supplemental6190ScenarioIds
        : suite === 'ai_chat_supplemental_31_60'
          ? supplementalScenarioIds
          : '')
);
const flags = [
  '--dart-define=AI_CHAT_DETERMINISTIC_GATE_V1=true',
  '--dart-define=AI_CHAT_LLM_LED_ROUTER_V2=true',
  '--dart-define=AI_CHAT_ANALYTICS_EVENTS_ENABLED=true',
  '--dart-define=AI_CHAT_TURN_DEBUG_REMOTE_ENABLED=true',
  '--dart-define=AI_CHAT_DEBUG_CAPTURE_MODE=all',
  '--dart-define=AI_CHAT_ANALYTICS_REMOTE_SINK_ENABLED=false',
  `--dart-define=AI_CHAT_SCENARIO_SUITE=${suite}`,
];
const args = [
  'test',
  'integration_test/ai_chat_30_real_emulator_d1_test.dart',
  '-d',
  device,
  `--timeout=${testTimeout}`,
  ...flags,
];
if (scenarioIds) {
  args.push(`--dart-define=AI_CHAT_30_SCENARIO_IDS=${scenarioIds}`);
}

let stdout = '';
let stderr = '';
const startedAt = new Date();

const child = spawn('flutter', args, {
  cwd: mobileApp,
  shell: true,
  env: process.env,
});

child.stdout.on('data', (chunk) => {
  const text = chunk.toString();
  stdout += text;
  process.stdout.write(text);
});

child.stderr.on('data', (chunk) => {
  const text = chunk.toString();
  stderr += text;
  process.stderr.write(text);
});

child.on('close', (exitCode) => {
  const finishedAt = new Date();
  const output = `${stdout}\n${stderr}`.trim();
  const report = parseLastJsonLine(
    output,
    'AI_CHAT_30_REAL_EMULATOR_D1_REPORT ',
  );
  const preflight = parseJsonLines(output, 'AI_CHAT_30_PREFLIGHT ');
  const turnEvents = parseTurnEvents(output);
  const results = attachTurnLatency(
    report?.results ?? parseScenarioResults(output),
    turnEvents,
  );
  const summary = report?.summary ?? buildSummary(results);
  const enhancedSummary = {
    ...summary,
    ...buildTurnLatencySummary(results),
  };

  writeFileSync(join(artifactDir, 'artifact_path.txt'), `${artifactDir}\n`);
  writeFileSync(
    join(artifactDir, 'run_status.txt'),
    [
      `exit=${exitCode}`,
      `runId=${runId}`,
      `suite=${suite}`,
      `startedAt=${startedAt.toISOString()}`,
      `finishedAt=${finishedAt.toISOString()}`,
      `device=${device}`,
      `scenarioIds=${scenarioIds || 'all'}`,
      `flags=${flags.join(' ')}`,
      `command=flutter ${args.join(' ')}`,
      '',
    ].join('\n'),
  );
  writeFileSync(
    join(artifactDir, 'raw_sanitized_flutter_output.txt'),
    output,
    'utf8',
  );
  writeFileSync(
    join(artifactDir, 'results.json'),
    JSON.stringify({
      run: {
        runId,
        suite,
        startedAt: startedAt.toISOString(),
        finishedAt: finishedAt.toISOString(),
        exitCode,
        device,
        scenarioIds: scenarioIds || 'all',
        flags,
        source: 'generated from current run',
        command: `flutter ${args.join(' ')}`,
      },
      preflight,
      summary: enhancedSummary,
      results,
      turnEvents,
    }, null, 2),
    'utf8',
  );
  writeFileSync(
    join(artifactDir, 'chat_debug_ids.txt'),
    results
      .map((item) => item.chatDebugId)
      .filter(Boolean)
      .join('\n') + '\n',
    'utf8',
  );
  writeFileSync(
    join(artifactDir, 'summary.md'),
    renderSummaryMarkdown({
      artifactDir,
      runId,
      suite,
      startedAt,
      finishedAt,
      exitCode,
      device,
      scenarioIds: scenarioIds || 'all',
      flags,
      summary: enhancedSummary,
      results,
      preflight,
    }),
    'utf8',
  );
  writeFileSync(join(artifactDir, 'failures.md'), renderFailures(results), 'utf8');
  writeFileSync(join(artifactDir, 'ux_notes.md'), renderUxNotes(results), 'utf8');
  writeFileSync(join(artifactDir, 'd1_sessions.md'), renderD1Sessions(results), 'utf8');

  console.log(`\nAI_CHAT_30_ARTIFACT_DIR ${artifactDir}`);
  process.exit(exitCode ?? 1);
});

function parseLastJsonLine(output, prefix) {
  const values = parseJsonLines(output, prefix);
  return values.length === 0 ? null : values.at(-1);
}

function parseJsonLines(output, prefix) {
  const values = [];
  for (const line of output.split(/\r?\n/)) {
    if (!line.includes(prefix)) continue;
    const jsonText = line.slice(line.indexOf(prefix) + prefix.length).trim();
    try {
      values.push(JSON.parse(jsonText));
    } catch {
      // Keep parsing later lines.
    }
  }
  return values;
}

function parseScenarioResults(output) {
  const results = [];
  for (const line of output.split(/\r?\n/)) {
    const prefix = 'AI_CHAT_30_SCENARIO_RESULT ';
    if (!line.includes(prefix)) continue;
    const jsonText = line.slice(line.indexOf(prefix) + prefix.length).trim();
  try {
      results.push(JSON.parse(jsonText));
  } catch {
      // Keep parsing later lines.
    }
  }
  return results;
}

function buildSummary(results) {
  const latencies = results.map((item) => item.latencyMs ?? 0).sort((a, b) => a - b);
  const p95Index = latencies.length === 0
    ? 0
    : Math.round((latencies.length - 1) * 0.95);
  return {
    scenarioCount: results.length,
    d1StoredSessions: results.filter((item) => item.remoteSyncStatus?.remoteDebugSynced === true).length,
    missingDebugSessionCount: results.filter((item) => !item.chatDebugId).length,
    missingTurnsCount: results.filter((item) => (item.remoteSyncStatus?.remoteDebugTurnSuccessCount ?? 0) === 0).length,
    externalCardViolationCount: countIssue(results, 'external_card_violation'),
    fakeProductIdCount: results.filter((item) => (item.issues ?? []).some((issue) => issue.startsWith('invalid_product_ids'))).length,
    fakePriceStockClaimCount: countIssue(results, 'fake_external_price_or_stock_claim'),
    mojibakeCount: countIssue(results, 'mojibake'),
    genericCopyCount: countIssue(results, 'generic_copy'),
    over10sCount: results.filter((item) => (item.latencyMs ?? 0) > 10000).length,
    over15sCount: results.filter((item) => (item.latencyMs ?? 0) > 15000).length,
    avgLatencyMs: latencies.length === 0
      ? 0
      : latencies.reduce((sum, value) => sum + value, 0) / latencies.length,
    p95LatencyMs: latencies.length === 0 ? 0 : latencies[p95Index],
    issueScenarioCount: results.filter((item) => (item.issues ?? []).length > 0).length,
    caveatScenarioCount: results.filter((item) => (item.caveats ?? []).length > 0).length,
  };
}

function buildTurnLatencySummary(results) {
  const turnLatencies = results
    .flatMap((item) => item.turnLatenciesMs ?? [])
    .filter((value) => Number.isFinite(value))
    .sort((a, b) => a - b);
  const p95Index = turnLatencies.length === 0
    ? 0
    : Math.round((turnLatencies.length - 1) * 0.95);
  return {
    turnCountWithLatency: turnLatencies.length,
    over10sTurnCount: turnLatencies.filter((value) => value > 10000).length,
    over15sTurnCount: turnLatencies.filter((value) => value > 15000).length,
    maxTurnLatencyMs: turnLatencies.length === 0
      ? 0
      : turnLatencies[turnLatencies.length - 1],
    p95TurnLatencyMs: turnLatencies.length === 0
      ? 0
      : turnLatencies[p95Index],
  };
}

function countIssue(results, issue) {
  return results.filter((item) => (item.issues ?? []).includes(issue)).length;
}

function parseTurnEvents(output) {
  const events = [];
  const marker = 'AIChatAnalyticsEvent';
  for (const line of output.split(/\r?\n/)) {
    if (!line.includes(marker) || !line.includes('turnDurationMs:')) continue;
    const chatDebugId = extractEventField(line, 'chatDebugId');
    const turnId = extractEventField(line, 'turnId');
    const route = extractEventField(line, 'route');
    const source = extractEventField(line, 'source');
    const latencyText = extractEventField(line, 'turnDurationMs');
    const latencyMs = Number.parseInt(latencyText ?? '', 10);
    if (!chatDebugId || !Number.isFinite(latencyMs)) continue;
    events.push({ chatDebugId, turnId, route, source, latencyMs });
  }
  return events;
}

function extractEventField(line, field) {
  const match = line.match(new RegExp(`${field}:\\s*([^,}]+)`));
  return match?.[1]?.trim() ?? null;
}

function attachTurnLatency(results, turnEvents) {
  const byChat = new Map();
  for (const event of turnEvents) {
    if (!byChat.has(event.chatDebugId)) byChat.set(event.chatDebugId, []);
    byChat.get(event.chatDebugId).push(event);
  }
  return results.map((item) => {
    const turns = byChat.get(item.chatDebugId) ?? [];
    const analyticsTurnLatenciesMs = turns.map((turn) => turn.latencyMs);
    const existingTurnLatencies = Array.isArray(item.turnLatenciesMs)
      ? item.turnLatenciesMs.filter((value) => Number.isFinite(value))
      : [];
    const turnLatenciesMs = existingTurnLatencies.length > 0
      ? existingTurnLatencies
      : analyticsTurnLatenciesMs;
    return {
      ...item,
      turnLatenciesMs,
      maxTurnLatencyMs: turnLatenciesMs.length === 0
        ? null
        : Math.max(...turnLatenciesMs),
      analyticsTurnLatenciesMs,
      turnSources: turns.map((turn) => turn.source),
    };
  });
}

function renderSummaryMarkdown(context) {
  const {
    artifactDir,
    runId,
    suite,
    startedAt,
    finishedAt,
    exitCode,
    device,
    scenarioIds,
    flags,
    summary,
    results,
    preflight,
  } = context;
  return [
    '# AI Chat 30 Real Emulator + D1 UX Report',
    '',
    `Artifact: \`${artifactDir}\``,
    `Run ID: \`${runId}\``,
    `Suite: \`${suite}\``,
    'Source: `generated from current run`',
    `Started: \`${startedAt.toISOString()}\``,
    `Finished: \`${finishedAt.toISOString()}\``,
    `Exit: \`${exitCode}\``,
    `Device: \`${device}\``,
    `Scenario IDs: \`${scenarioIds}\``,
    `Flags: \`${flags.join(' ')}\``,
    '',
    '## Executive Summary',
    '',
    '| Metric | Value |',
    '|---|---:|',
    ...Object.entries(summary).map(([key, value]) => `| ${key} | ${value} |`),
    '',
    '## Preflight',
    '',
    '| ID | Status | D1 Synced | Chat Debug ID |',
    '|---|---|---|---|',
    ...(preflight ?? []).map((item) => `| ${item.id} | ${item.status} | ${item.remoteSyncStatus?.remoteDebugSynced === true} | ${item.chatDebugId ?? ''} |`),
    '',
    '## Scenario Table',
    '',
    '| ID | Title | Expected Intent | Status | Source | Products | Scenario Latency | Max Turn | Issues | Caveats | Chat Debug ID |',
    '|---|---|---|---|---|---|---:|---:|---|---|---|',
    ...results.map((item) => `| ${item.id} | ${item.title} | ${item.expectedIntent ?? ''} | ${item.status} | ${item.source} | ${(item.productIds ?? []).join(', ')} | ${item.latencyMs ?? ''} | ${item.maxTurnLatencyMs ?? ''} | ${(item.issues ?? []).join(', ')} | ${(item.caveats ?? []).join(', ')} | ${item.chatDebugId ?? ''} |`),
    '',
  ].join('\n');
}

function renderFailures(results) {
  const p0 = [];
  const p1 = [];
  const p2 = [];
  for (const item of results) {
    for (const issue of item.issues ?? []) {
      if (issue.includes('external_card') || issue.includes('fake') || issue.includes('mojibake')) {
        p0.push(`${item.id} \`${item.chatDebugId}\`: ${issue}`);
      } else {
        p1.push(`${item.id} \`${item.chatDebugId}\`: ${issue}`);
      }
    }
    for (const caveat of item.caveats ?? []) {
      p2.push(`${item.id} \`${item.chatDebugId}\`: ${caveat}`);
    }
  }
  return [
    '# Failures / Severity',
    '',
    '## P0',
    ...(p0.length ? p0.map((line) => `- ${line}`) : ['- None']),
    '',
    '## P1',
    ...(p1.length ? p1.map((line) => `- ${line}`) : ['- None']),
    '',
    '## P2',
    ...(p2.length ? p2.map((line) => `- ${line}`) : ['- None']),
    '',
  ].join('\n');
}

function renderUxNotes(results) {
  return [
    '# UX Notes',
    '',
    ...results.map((item) => [
      `## ${item.id} ${item.title}`,
      `- chatDebugId: \`${item.chatDebugId ?? ''}\``,
      `- status/source: \`${item.status}\` / \`${item.source}\``,
      `- products: \`${(item.productIds ?? []).join(', ')}\``,
      `- latency: \`${item.latencyMs ?? ''}ms\``,
      `- maxTurnLatency: \`${item.maxTurnLatencyMs ?? ''}ms\``,
      `- turnSources: \`${(item.turnSources ?? []).join(', ')}\``,
      `- preview: ${item.contentPreview ?? ''}`,
      `- issues: \`${(item.issues ?? []).join(', ')}\``,
      `- caveats: \`${(item.caveats ?? []).join(', ')}\``,
      '',
    ].join('\n')),
  ].join('\n');
}

function renderD1Sessions(results) {
  return [
    '# D1 Sessions',
    '',
    '| Scenario | Chat Debug ID | Synced | Turn Success Count |',
    '|---|---|---:|---:|',
    ...results.map((item) => `| ${item.id} | ${item.chatDebugId ?? ''} | ${item.remoteSyncStatus?.remoteDebugSynced === true} | ${item.remoteSyncStatus?.remoteDebugTurnSuccessCount ?? 0} |`),
    '',
  ].join('\n');
}
