import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingDetailsScreen extends StatelessWidget {
  final String estacionamentoId;
  final Map<String, dynamic> dadosEstacionamento;

  const ParkingDetailsScreen({
    super.key,
    required this.estacionamentoId,
    required this.dadosEstacionamento,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(dadosEstacionamento['nome'] ?? 'Detalhes'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- CABEÇALHO COM INFORMAÇÕES ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Endereço:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(dadosEstacionamento['endereco'] ?? 'Sem endereço'),
                const SizedBox(height: 10),
                const Text(
                  "Regras:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(dadosEstacionamento['regras'] ?? 'Sem regras cadastradas'),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Vagas em Tempo Real:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          // --- LISTA DE VAGAS (EM TEMPO REAL) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Aqui conectamos na subcoleção 'vagas' deste estacionamento específico
              stream: FirebaseFirestore.instance
                  .collection('estacionamentos')
                  .doc(estacionamentoId)
                  .collection('vagas')
                  .snapshots(), // snapshots() mantém a conexão aberta
              builder: (context, snapshot) {
                // Tratamento de estados (carregando, erro, vazio)
                if (snapshot.hasError) {
                  return const Center(child: Text('Erro ao carregar vagas.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma vaga cadastrada neste local.'),
                  );
                }

                // Lista de Vagas
                var vagas = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: vagas.length,
                  itemBuilder: (context, index) {
                    var vaga = vagas[index];
                    var dadosVaga = vaga.data() as Map<String, dynamic>;
                    String status = dadosVaga['status'] ?? 'desconhecido';
                    String nomeVaga = dadosVaga['identificador'] ?? 'Vaga ${index + 1}';
                    String tipo = dadosVaga['tipo'] ?? 'carro';

                    // Define cor baseada no status
                    Color corStatus;
                    if (status == 'livre') {
                      corStatus = Colors.green;
                    } else if (status == 'ocupada') {
                      corStatus = Colors.red;
                    } else {
                      corStatus = Colors.orange; // Reservada
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          tipo == 'moto' ? Icons.motorcycle : Icons.directions_car,
                          color: Colors.black54,
                        ),
                        title: Text(
                          nomeVaga,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Tipo: $tipo"),
                        trailing: Chip(
                          label: Text(
                            status.toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: corStatus,
                        ),
                        onTap: status == 'livre' 
                            ? () {
                                // AQUI: Futuramente abriremos a tela de CONFIRMAR RESERVA
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Você selecionou a $nomeVaga")),
                                );
                              }
                            : null, // Se não estiver livre, não faz nada
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}