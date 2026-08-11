import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_parking_management_screen.dart';
import 'admin_add_parking_screen.dart'; 

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

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('estacionamentos')
                    .doc(doc.id)
                    .collection('vagas')
                    .snapshots(),
                builder: (context, vagaSnapshot) {
                  int totalVagas = 0;
                  int vagasOcupadas = 0;

                  if (vagaSnapshot.hasData) {
                    totalVagas = vagaSnapshot.data!.docs.length;
                    vagasOcupadas = vagaSnapshot.data!.docs
                        .where((v) => (v.data() as Map<String, dynamic>)['status'] != 'livre')
                        .length;
                  }

                  double percentual = totalVagas > 0 ? (vagasOcupadas / totalVagas) : 0;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange[100],
                        child: const Icon(Icons.business, color: Colors.orange),
                      ),
                      title: Text(
                        dados['nome'] ?? 'Sem Nome',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dados['endereco'] ?? 'Sem Endereço'),
                          const SizedBox(height: 8),
                        
                          LinearProgressIndicator(
                            value: percentual,
                            backgroundColor: Colors.grey[200],
                            color: percentual > 0.8 ? Colors.red : Colors.green,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Ocupação: $vagasOcupadas / $totalVagas vagas",
                            style: TextStyle(
                              fontSize: 12, 
                              color: percentual > 0.8 ? Colors.red : Colors.green[700],
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange[800],
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text("Novo Estacionamento", style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminAddParkingScreen()),
          );
        },
      ),
    );
  }
}