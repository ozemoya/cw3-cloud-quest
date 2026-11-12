import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { createQuestCoach } from './questCoach.js';

initializeApp();
const db = getFirestore();
const challenge = db.doc('challenges/today');
const progress = uid => db.doc(`users/${uid}/progress/today`);

function learner(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  return request.auth.uid;
}

export const completeToday = onCall(async request => {
  const uid = learner(request);
  if (request.data?.challengeId !== 'today') {
    throw new HttpsError('invalid-argument', 'Unknown challenge.');
  }
  return db.runTransaction(async transaction => {
    const saved = await transaction.get(progress(uid));
    if (saved.exists) return { points: saved.get('points'), badgeId: saved.get('badgeId'), alreadyCompleted: true };
    if (!(await transaction.get(challenge)).exists) {
      throw new HttpsError('failed-precondition', 'No challenge is available.');
    }
    const reward = { points: 10, badgeId: 'first-quest' };
    transaction.set(progress(uid), { ...reward, completed: true, completedAt: FieldValue.serverTimestamp() });
    return { ...reward, alreadyCompleted: false };
  });
});


const questCoach = createQuestCoach(db);
export const askQuestCoach = onCall(async request => {
  const uid = learner(request);
  const question = request.data?.question;
  if (typeof question !== 'string' || !question.trim() || question.length > 300) {
    throw new HttpsError('invalid-argument', 'Enter a question up to 300 characters.');
  }
  return questCoach({ question }, { context: { auth: { uid } } });
});
