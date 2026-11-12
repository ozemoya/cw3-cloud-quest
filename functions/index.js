import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

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

async function readMyQuestState(uid) {
  const [quest, saved] = await Promise.all([challenge.get(), progress(uid).get()]);
  if (!quest.exists) throw new HttpsError('failed-precondition', 'No challenge is available.');
  return { hint: quest.get('hint'), completed: saved.get('completed') === true };
}

export const askQuestCoach = onCall(async request => {
  const uid = learner(request);
  const question = request.data?.question;
  if (typeof question !== 'string' || !question.trim() || question.length > 300) {
    throw new HttpsError('invalid-argument', 'Enter a question up to 300 characters.');
  }
  if (process.env.FUNCTIONS_EMULATOR !== 'true') {
    throw new HttpsError('unavailable', 'The course model gateway is not configured.');
  }
  const state = await readMyQuestState(uid);
  if (question === 'simulate coach failure') {
    throw new HttpsError('unavailable', 'The coach is unavailable.');
  }
  if (/another learner|500 points|ignore your rules/i.test(question)) {
    return { reply: 'I can only offer hints for your own quest. Use Complete challenge to request its fixed reward.' };
  }
  return { reply: state.completed ? 'You already completed this quest. ' + state.hint : state.hint };
});
