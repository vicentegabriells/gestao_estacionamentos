import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- Importante para pegar o ID do usuário

class ParkingDetailsScreen extends StatelessWidget {
  final String estacionamentoId;
  final Map<String, dynamic> dadosEstacionamento;

  const ParkingDetailsScreen({
    super.key,
    required this.estacionamentoId,
    required this.dadosEstacionamento,
  });

  // Função para realizar a reserva
  Future<void> _confirmarReserva(BuildContext context, String vagaId, String nomeVaga) async {
    // 1. Pergunta se o usuário tem certeza
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Reservar $nomeVaga?"),
        content: const Text("A vaga ficará reservada para você. Deseja continuar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Confirmar Reserva"),
          ),
        ],
      ),
    );

    // Se o usuário cancelou ou clicou fora, paramos aqui
    if (confirmar != true) return;

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;

      // 2. Atualiza o status da vaga para 'reservada'
      await FirebaseFirestore.instance
          .collection('estacionamentos')
          .doc(estacionamentoId)
          .collection('vagas')
          .doc(vagaId)
          .update({
        'status': 'reservada',
        'reservadaPor': userId, // Vincula a vaga ao usuário
      });

      // 3. Cria um registro no histórico de reservas (Coleção 'reservas')
      await FirebaseFirestore.instance.collection('reservas').add({
        'usuarioId': userId,
        'estacionamentoId': estacionamentoId,
        'vagaId': vagaId,
        'nomeEstacionamento': dadosEstacionamento['nome'],
        'nomeVaga': nomeVaga,
        'dataHoraInicio': FieldValue.serverTimestamp(),
        'status': 'ativa',
        'valorTotal': 0,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sucesso! A vaga $nomeVaga agora é sua."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao reservar: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

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
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Endereço:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(dadosEstacionamento['endereco'] ?? 'Sem endereço'),
                const SizedBox(height: 10),
                const Text("Regras:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(dadosEstacionamento['regras'] ?? 'Sem regras cadastradas'),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Toque em uma vaga LIVRE para reservar:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('estacionamentos')
                  .doc(estacionamentoId)
                  .collection('vagas')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Erro ao carregar.'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhuma vaga cadastrada.'));
                }

                var vagas = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: vagas.length,
                  itemBuilder: (context, index) {
                    var vaga = vagas[index];
                    var dadosVaga = vaga.data() as Map<String, dynamic>;
                    String status = dadosVaga['status'] ?? 'desconhecido';
                    String nomeVaga = dadosVaga['identificador'] ?? 'Vaga ${index + 1}';
                    String tipo = dadosVaga['tipo'] ?? 'carro';

                    // Cores e ícones
                    Color corStatus = Colors.grey;
                    IconData icone = tipo == 'moto' ? Icons.motorcycle : Icons.directions_car;
                    
                    if (status == 'livre') {
                      corStatus = Colors.green;
                    } else if (status == 'ocupada') {
                      corStatus = Colors.red;
                    } else if (status == 'reservada') {
                      corStatus = Colors.orange;
                    }

                    // Verifica se a vaga reservada é DO PRÓPRIO usuário atual
                    String? reservadaPor = dadosVaga['reservadaPor'];
                    String meuId = FirebaseAuth.instance.currentUser?.uid ?? '';
                    bool isMinhaReserva = (status == 'reservada' && reservadaPor == meuId);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(icone, color: corStatus, size: 30),
                        title: Text(nomeVaga, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(isMinhaReserva ? "RESERVADA POR VOCÊ" : "Status: ${status.toUpperCase()}"),
                        trailing: Icon(Icons.touch_app, color: status == 'livre' ? Colors.blue : Colors.grey),
                        
                        // Só permite clicar se estiver LIVRE
                        onTap: status == 'livre'
                            ? () => _confirmarReserva(context, vaga.id, nomeVaga)
                            : () {
                                if (isMinhaReserva) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Você já reservou esta vaga!")),
                                  );
                                }
                              },
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