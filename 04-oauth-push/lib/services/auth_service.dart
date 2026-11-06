import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'push_service.dart';

/// Autenticación con Google OAuth 2.0 a través de Firebase Authentication
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _google = GoogleSignIn(scopes: ['email', 'profile']);

  static User? get user => _auth.currentUser;
  static Stream<User?> get changes => _auth.authStateChanges();

  static Future<User?> signInWithGoogle() async {
    // 1) Flujo OAuth 2.0 de Google: el usuario elige su cuenta y otorga consentimiento
    final account = await _google.signIn();
    if (account == null) return null; // canceló
    // 2) Se obtienen los tokens (idToken / accessToken)
    final tokens = await account.authentication;
    // 3) Se intercambian por una sesión de Firebase
    final cred = GoogleAuthProvider.credential(idToken: tokens.idToken, accessToken: tokens.accessToken);
    final result = await _auth.signInWithCredential(cred);
    final u = result.user!;
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      'name': u.displayName,
      'email': u.email,
      'photoUrl': u.photoURL,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await PushService.registerToken();
    return u;
  }

  static Future<void> signOut() async {
    await PushService.unregisterToken();
    await _google.signOut();
    await _auth.signOut();
  }
}
