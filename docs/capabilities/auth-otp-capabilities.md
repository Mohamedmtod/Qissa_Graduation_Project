# Auth And OTP Capabilities

The authentication layer covers customer sign-in, account recovery, and access control across the app ecosystem. It is split between Firebase Auth, the Flutter UI, and the dedicated auth worker for OTP reset flows.

## What The Auth System Can Do

- Sign users in and out through Firebase Auth.
- Support customer registration and account recovery flows.
- Keep authenticated sessions available to the mobile app and admin dashboard.
- Resolve user identity for protected Firestore and worker operations.
- Separate customer access from admin access.
- Support a dedicated OTP password reset flow through the auth worker.
- Handle OTP request, verification, and password confirmation steps.
- Apply rate limits and cooldown logic to reduce abuse.
- Enforce password policy checks during reset flows.
- Return safe error states for invalid email, wrong OTP, expired OTP, or weak password cases.
- Keep auth-related logic out of the UI where server-side control is needed.

## What OTP Specifically Does

- Starts a reset request for a registered account.
- Sends an OTP through the configured delivery channel.
- Verifies the OTP before password update.
- Blocks reuse or repeated abuse through lockout/rate-limiting logic.
- Completes the reset only after the OTP and new password are valid.

## Why This Is Better Than A Simple Login Screen

- Authentication is not only a UI form.
- The project uses separate layers for identity, session state, and reset security.
- OTP is treated as a controlled recovery flow, not a loose client-side shortcut.
- Admin and customer access remain separated through explicit authorization checks.

## Main Touchpoints

- Customer app auth pages and repositories
- Admin dashboard auth repository and guarded routes
- Auth worker endpoints for OTP request and verification
- Firestore rules and backend authorization checks
