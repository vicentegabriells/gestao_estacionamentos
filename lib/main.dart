import 'package:flutter/material.dart'; // Importa o Flutter Material
import 'package:firebase_core/firebase_core.dart'; // Importa o Firebase Core
import 'firebase_options.dart'; // Importa as opções do Firebase geradas

// Importante: Importar o arquivo da tela de cadastro que você criou
import 'login_screen.dart';

Future<void> main() async { // Função principal assíncrona
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
      debugShowCheckedModeBanner: false,
      title: 'Gestão de Estacionamentos',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // AQUI ESTÁ A MUDANÇA PRINCIPAL:
      // O app vai iniciar direto na tela de cadastro
      home: const LoginScreen(),
    );
  }
}