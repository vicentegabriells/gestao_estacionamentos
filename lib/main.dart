import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_screen.dart'; // Sua tela de login
import 'home_screen.dart'; // Sua tela home (caso já esteja logado)
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io'; // Para detectar Platform.isWindows, etc.

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
      // --- AQUI ESTÁ A MÁGICA PARA LIMITAR A TELA ---
      builder: (context, child) {
        // Verifica se é Web ou Desktop (Telas grandes)
        bool isLargeScreen = false;
        
        if (kIsWeb) {
          isLargeScreen = true;
        } else {
          try {
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
              isLargeScreen = true;
            }
          } catch (e) {
            // Em web o dart:io pode falhar, então tratamos
            isLargeScreen = true;
          }
        }

        // Se for tela grande, força o modo celular
        if (isLargeScreen) {
          return Center(
            child: Container(
              // Tamanho aproximado de um iPhone 12/13/14 Pro (Logical Pixels)
              // 1170px / 3 = 390
              // 2532px / 3 = 844
              width: 390,
              height: 844,
              decoration: BoxDecoration(
                color: Colors.white,
                // Borda grossa imitando o chassi do celular
                border: Border.all(color: Colors.black, width: 12),
                borderRadius: BorderRadius.circular(32),
                // Sombra para dar destaque no fundo branco
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  )
                ],
              ),
              // ClipRRect garante que o conteúdo não vaze pelas bordas arredondadas
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: child, // O app original é renderizado aqui dentro
              ),
            ),
          );
        }

        // Se estiver num celular de verdade, exibe normal
        return child!;
      },
      // ------------------------------------------------
      
      home: const AuthWrapper(),
    );
  }
}

// Controla se vai para Login ou Home automaticamente
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
          return const HomeScreen(); // Usuário logado
        }
        return const LoginScreen(); // Usuário não logado
      },
    );
  }
}