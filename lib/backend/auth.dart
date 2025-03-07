import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Auth{
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  //Signs in the user using an email and password
  Future<void> signInWithEmailAndPassword({//Returns a Future as it must await the firebase request
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

  //Signs in through using an Google access token
  Future<void> signInWithGoogle() async {
    GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    GoogleSignInAuthentication? googleAuth = await googleUser?.authentication; //Grabs the users authentication data

    AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    UserCredential userCredential  = await _firebaseAuth.signInWithCredential(credential); //Attempts to sign the user in, ensuring the same gmail isn't used
    FirebaseFirestore.instance.collection('users').add({ //Adds the user if the user does not exist
        'first_name': userCredential.user?.displayName?.split(' ').first, 
        'last_name': userCredential.user?.displayName?.split(' ').last,   
        'email': userCredential.user?.email,
      });

  }
}