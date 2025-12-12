import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Importe o firestore se quiser salvar os dados do usuário após o cadastro
// import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // Controladores para ler o texto dos campos
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(); // Para o REQ-001

  // Gerencia o estado de carregamento
  bool _isLoading = false;

  // Função para lidar com o cadastro
  Future<void> _registerUser() async {
    // 1. Inicia o carregamento
    setState(() {
      _isLoading = true;
    });

    try {
      // 2. Usa o Firebase Auth para criar o usuário
      UserCredential userCredential = 
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 3. (Passo Opcional, mas recomendado)
      //    Se o usuário foi criado com sucesso, pegue o UID dele
      //    e salve os dados extras (nome, tipoPerfil) no Firestore.
      
      // String userId = userCredential.user!.uid;
      // await FirebaseFirestore.instance.collection('usuarios').doc(userId).set({
      //   'nome': _nameController.text.trim(),
      //   'email': _emailController.text.trim(),
      //   'tipoPerfil': 'usuario', // Define o perfil padrão
      // });


      // 4. Mostra sucesso (se o contexto ainda for válido)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadastro realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        // Redireciona para a tela de login
        Navigator.pushReplacementNamed(context, '/login');
      }

    } on FirebaseAuthException catch (e) {
      // 5. Lida com erros do Firebase Auth
      String errorMessage = 'Ocorreu um erro.';
      if (e.code == 'weak-password') {
        errorMessage = 'A senha é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Este e-mail já está em uso.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'O e-mail informado é inválido.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 6. Lida com outros erros
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // 7. Para o carregamento
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Novo Usuário'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Campo de Nome (REQ-001)
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome Completo',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 16),

            // Campo de E-mail (REQ-001)
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Campo de Senha (REQ-001)
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Senha (mín. 6 caracteres)',
                border: OutlineInputBorder(),
              ),
              obscureText: true, // Esconde a senha
            ),
            const SizedBox(height: 24),

            // Botão de Cadastrar
            _isLoading
                ? const CircularProgressIndicator() // Mostra o "loading"
                : ElevatedButton(
                    onPressed: _registerUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    ),
                    child: const Text('Cadastrar'),
                  ),
          ],
        ),
      ),
    );
  }
}