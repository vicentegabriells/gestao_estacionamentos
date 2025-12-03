import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Administrador'),
        backgroundColor: Colors.orange[800], // Cor diferente para diferenciar do app de motorista
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Em um app real, filtraríamos por adminId: .where('adminId', isEqualTo: user.uid)
        // Para o trabalho acadêmico, vamos listar todos para facilitar o teste
        stream: FirebaseFirestore.instance.collection('estacionamentos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar dados.'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum estacionamento cadastrado.'));
          }

          var listaEstacionamentos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listaEstacionamentos.length,
            itemBuilder: (context, index) {
              var doc = listaEstacionamentos[index];
              var dados = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[100],
                    child: const Icon(Icons.business, color: Colors.orange),
                  ),
                  title: Text(
                    dados['nome'] ?? 'Sem Nome',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(dados['endereco'] ?? 'Sem Endereço'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // AQUI: Futuramente vamos para a tela de "Gerenciar Vagas"
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Gerenciar: ${dados['nome']}")),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange[800],
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Funcionalidade futura: Cadastrar Novo Estacionamento")),
          );
        },
      ),
    );
  }
}