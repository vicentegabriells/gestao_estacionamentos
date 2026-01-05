//ainda em construção
import 'admin_parking_management_screen.dart';
import 'package:flutter/material.dart'; // Importa o Flutter Material
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa o Firestore

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Administrador'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Lista todos os estacionamentos (Para este trabalho, assumimos que o admin vê tudo)
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
                    // Agora o import lá em cima permite que essa navegação funcione
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AdminParkingManagementScreen(
                          estacionamentoId: doc.id,
                          nomeEstacionamento: dados['nome'] ?? 'Estacionamento',
                        ),
                      ),
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