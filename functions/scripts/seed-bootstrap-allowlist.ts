// One-shot seed script for system_config/bootstrap_superadmins.
//
// Run locally with admin SDK credentials:
//   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
//   npx ts-node scripts/seed-bootstrap-allowlist.ts email1@example.com email2@example.com
//
// Each email is single-use: bootstrapSuperadminRole removes it on success.

import { initializeApp, getApps, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

async function main() {
  const emails = process.argv.slice(2);
  if (emails.length === 0) {
    console.error('Usage: ts-node seed-bootstrap-allowlist.ts <email> [email ...]');
    process.exit(1);
  }

  if (getApps().length === 0) {
    initializeApp({ credential: applicationDefault() });
  }
  const db = getFirestore();

  const ref = db.doc('system_config/bootstrap_superadmins');
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const existing = snap.exists
      ? ((snap.data()?.emails as string[] | undefined) ?? [])
      : [];
    const merged = Array.from(new Set([...existing, ...emails.map((e) => e.toLowerCase())]));
    tx.set(
      ref,
      {
        emails: merged,
        seededAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  console.log(`Seeded ${emails.length} email(s) into bootstrap allowlist.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
