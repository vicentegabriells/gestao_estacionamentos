import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_screen.dart'; 
import 'home_screen.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestão de Estacionamentos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      
      builder: (context, child) {
        
        bool isLargeScreen = false;
        
        if (kIsWeb) {
          isLargeScreen = true;
        } else {
          try {
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
              isLargeScreen = true;
            }
          } catch (e) {
            
            isLargeScreen = true;
          }
        }

        if (isLargeScreen) {
          return Center(
            child: Container(
              
              width: 390,
              height: 844,
              decoration: BoxDecoration(
                color: Colors.white,
                
                border: Border.all(color: Colors.black, width: 12),
                borderRadius: BorderRadius.circular(32),
               
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  )
                ],
              ),

              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: child, 
              ),
            ),
          );
        }

        return child!;
      },
      
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const HomeScreen(); 
        }
        return const LoginScreen(); 
      },
    );
  }
}