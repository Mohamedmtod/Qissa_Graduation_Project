import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';
import {
  corsPreflight,
  publicErrorResponse,
  resolveCorsOrigin,
} from '../src/http.js';

test('CORS preflight returns security headers', () => {
  const response = corsPreflight('http://localhost:8080');

  assert.equal(response.status, 204);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), 'http://localhost:8080');
  assert.equal(response.headers.get('X-Content-Type-Options'), 'nosniff');
  assert.equal(response.headers.get('Referrer-Policy'), 'no-referrer');
  assert.match(response.headers.get('Content-Security-Policy'), /default-src 'none'/);
});

test('resolveCorsOrigin reflects configured allowed origin only', () => {
  const allowedRequest = new Request('https://worker.test', {
    headers: { Origin: 'https://admin.example.com' },
  });
  const deniedRequest = new Request('https://worker.test', {
    headers: { Origin: 'https://evil.example.com' },
  });
  const env = { ALLOWED_ORIGINS: 'https://admin.example.com' };

  assert.equal(resolveCorsOrigin(allowedRequest, env), 'https://admin.example.com');
  assert.equal(resolveCorsOrigin(deniedRequest, env), 'https://admin.example.com');
});

test('public error response hides internal errors', async () => {
  const response = publicErrorResponse(new Error('secret backend failure'), 'http://localhost:8080');
  const body = await response.json();

  assert.equal(response.status, 500);
  assert.equal(body.error, 'An unexpected error occurred. Please try again.');
});

test('password-reset request with invalid email returns generic response', async () => {
  const response = await worker.fetch(
    new Request('https://worker.test/password-reset/request', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'not-an-email' }),
    }),
    {},
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.ok, true);
  assert.match(body.message, /If this email exists/);
});

test('health endpoint identifies auth worker', async () => {
  const response = await worker.fetch(new Request('https://worker.test/health'), {});
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.ok, true);
  assert.equal(body.service, 'perfume-auth-worker');
});
