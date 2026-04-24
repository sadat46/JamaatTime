import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// Single admin-SDK init shared by every function handler.
if (getApps().length === 0) {
  initializeApp();
}

export const db = getFirestore();
