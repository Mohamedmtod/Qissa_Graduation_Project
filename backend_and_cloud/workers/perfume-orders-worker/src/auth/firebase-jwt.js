import { createRemoteJWKSet, jwtVerify } from "jose";
import { FIREBASE_TOKEN_ISSUER } from "../constants/index.js";

const firebaseJwks = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

/**
 * @param {string} idToken
 * @param {{ FIREBASE_PROJECT_ID?: string }} env
 */
export async function verifyFirebaseIdToken(idToken, env) {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw new Error("Missing FIREBASE_PROJECT_ID");
  }

  const verified = await jwtVerify(idToken, firebaseJwks, {
    issuer: `${FIREBASE_TOKEN_ISSUER}/${projectId}`,
    audience: projectId,
  });

  return verified.payload;
}
