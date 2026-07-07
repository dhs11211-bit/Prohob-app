import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyBUTPDFUvI6VI4gFmn4DE8sr_Pkvni_nuU",
            authDomain: "service-pro-hob.firebaseapp.com",
            projectId: "service-pro-hob",
            storageBucket: "service-pro-hob.firebasestorage.app",
            messagingSenderId: "489522647960",
            appId: "1:489522647960:web:3061a33a95010dea07d1ed",
            measurementId: "G-CYG7PSB4WR"));
  } else {
    await Firebase.initializeApp();
  }
}
