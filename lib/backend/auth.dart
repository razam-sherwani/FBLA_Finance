import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Auth{
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async{
    await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async{
    await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async{
    await _firebaseAuth.signOut();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }
  Future<void> signInWithGoogle() async {
    GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

    AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    UserCredential userCredential  = await _firebaseAuth.signInWithCredential(credential);
    FirebaseFirestore.instance.collection('users').add({
        'first_name': userCredential.user?.displayName?.split(' ').first, // Changed to snake_case for consistency
        'last_name': userCredential.user?.displayName?.split(' ').last,   // Changed to snake_case for consistency
        'email': userCredential.user?.email,
      });

  }
}