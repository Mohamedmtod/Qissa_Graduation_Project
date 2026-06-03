import test from 'node:test';
import assert from 'node:assert/strict';
import {
  isValidEmail,
  isValidOtpShape,
  normalizeEmail,
  normalizeOtp,
  validatePassword,
} from '../src/password-rules.js';

test('normalizes email and OTP input safely', () => {
  assert.equal(normalizeEmail(' USER@Example.COM '), 'user@example.com');
  assert.equal(normalizeEmail(null), '');
  assert.equal(normalizeOtp(' 123456 '), '123456');
  assert.equal(normalizeOtp(123456), '');
});

test('validates email and six-digit OTP shape', () => {
  assert.equal(isValidEmail('user@example.com'), true);
  assert.equal(isValidEmail('bad-email'), false);
  assert.equal(isValidOtpShape('123456'), true);
  assert.equal(isValidOtpShape('12345'), false);
  assert.equal(isValidOtpShape('1234567'), false);
  assert.equal(isValidOtpShape('abcdef'), false);
});

test('rejects weak password before Firebase update', () => {
  assert.equal(validatePassword(''), 'Password is required.');
  assert.equal(
    validatePassword('Password1!ع'),
    'Only English letters, numbers, and symbols are allowed.',
  );
  assert.equal(
    validatePassword('PASSWORD1!'),
    'Password must contain at least one lowercase letter.',
  );
  assert.equal(
    validatePassword('password1!'),
    'Password must contain at least one uppercase letter.',
  );
  assert.equal(
    validatePassword('Password!'),
    'Password must contain at least one digit.',
  );
  assert.equal(
    validatePassword('Password1'),
    'Password must contain at least one special character.',
  );
  assert.equal(
    validatePassword('Pass1!'),
    'Password must be at least 8 characters long.',
  );
  assert.equal(validatePassword('StrongPass1!'), null);
});
