'use strict';
// Run only from a trusted administrator workstation with Application Default Credentials.
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

async function main() {
  const [uid, operation] = process.argv.slice(2);
  const projectId = process.env.GOOGLE_CLOUD_PROJECT;
  if (!projectId || !uid || !/^[A-Za-z0-9_-]{1,128}$/.test(uid) ||
      !['grant', 'revoke'].includes(operation)) {
    throw new Error('Set GOOGLE_CLOUD_PROJECT and run: node grant_admin.js <uid> grant|revoke');
  }
  initializeApp({ credential: applicationDefault(), projectId });
  const auth = getAuth();
  const user = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, { ...user.customClaims, admin: operation === 'grant' });
  console.log(`Admin claim ${operation} completed for ${uid}. User must refresh their ID token.`);
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
