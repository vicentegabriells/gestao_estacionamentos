import 'package:flutter/material.dart';
import 'registration_screen.dart';

// 1. Importe o Firebase Core (o pacote principal)
import 'package:firebase_core/firebase_core.dart';

// 2. Importe o arquivo de opções que o FlutterFire criou
import 'firebase_options.dart'; 

// 3. Modifique a função main para ser 'async'
Future<void> main() async {
  
  // 4. Garanta que o Flutter está pronto antes de rodar o Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // 5. Inicialize o Firebase usando o arquivo de opções
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 6. Rode o seu aplicativo
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestão de Estacionamentos',
      
      // AQUI ESTÁ A MUDANÇA:
      // O home agora é a sua nova tela de cadastro
      home: const RegistrationScreen(),
      
    );
  }
}