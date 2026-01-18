import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Variável para armazenar o tipo de perfil selecionado
  String _tipoPerfilSelecionado = 'usuario'; 
  bool _isLoading = false;

  Future<void> _registerUser() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não coincidem!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String userId = userCredential.user!.uid; 
      
      // Salva o perfil escolhido no momento do cadastro
      await FirebaseFirestore.instance.collection('usuarios').doc(userId).set({
        'nome': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'telefone': _phoneController.text.trim(),
        'tipoPerfil': _tipoPerfilSelecionado, // 'usuario' ou 'admin'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadastro realizado com sucesso!'), backgroundColor: Colors.green),
        );
<<<<<<< HEAD
        // Redireciona para a tela de login
        Navigator.pushReplacementNamed(context, '/login');
=======
        Navigator.of(context).pop();
>>>>>>> upstream/main
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Novo Usuário')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Celular', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            
            // NOVO: Seleção de Tipo de Perfil
            DropdownButtonFormField<String>(
              value: _tipoPerfilSelecionado,
              decoration: const InputDecoration(labelText: 'Tipo de Conta', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'usuario', child: Text('Motorista (Padrão)')),
                DropdownMenuItem(value: 'admin', child: Text('Administrador de Estacionamento')),
              ],
              onChanged: (value) => setState(() => _tipoPerfilSelecionado = value!),
            ),
            
            const SizedBox(height: 16),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 16),
            TextField(controller: _confirmPasswordController, decoration: const InputDecoration(labelText: 'Confirmar Senha', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 24),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _registerUser, child: const Text('Cadastrar')),
          ],
        ),
      ),
    );
  }
}