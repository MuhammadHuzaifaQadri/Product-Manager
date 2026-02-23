const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// 🔥 HTTP function - GitHub se trigger hoga
exports.deleteUserCompletely = functions.https.onRequest(async (req, res) => {
  // Secret key for security
  const secretKey = req.query.secret;
  if (secretKey !== 'your-secret-key-here') {
    res.status(403).send('Unauthorized');
    return;
  }

  const uid = req.query.uid;
  const email = req.query.email;

  try {
    // Step 1: Delete from Firebase Auth
    await admin.auth().deleteUser(uid);
    console.log(`✅ Deleted user ${uid} from Auth`);

    // Step 2: Delete from Firestore users collection
    await admin.firestore().collection('users').doc(uid).delete();

    // Step 3: Delete user's other data
    const collections = ['favorites', 'reviews', 'wishlists', 'recently_viewed', 'notifications'];
    
    for (const collection of collections) {
      const snapshot = await admin.firestore()
          .collection(collection)
          .where('userId', '==', uid)
          .get();
      
      const batch = admin.firestore().batch();
      snapshot.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
    }

    res.status(200).send('User completely deleted');
    
  } catch (error) {
    console.error('Error:', error);
    res.status(500).send(error.message);
  }
});