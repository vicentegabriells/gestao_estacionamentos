import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminParkingManagementScreen extends StatelessWidget {
  final String estacionamentoId;
  final String nomeEstacionamento;

  const AdminParkingManagementScreen({
    super.key,
    required this.estacionamentoId,
    required this.nomeEstacionamento,
  });

  // Função para alternar o status da vaga manualmente
  Future<void> _alternarStatusVaga(String vagaId, String statusAtual) async {
    String novoStatus = statusAtual == 'livre' ? 'ocupada' : 'livre';

    await FirebaseFirestore.instance
        .collection('estacionamentos')
        .doc(estacionamentoId)
        .collection('vagas')
        .doc(vagaId)
        .update({
      'status': novoStatus,
      // Se estiver ocupando manualmente, removemos qualquer reserva ativa vinculada
      if (novoStatus == 'ocupada') 'reservadaPor': FieldValue.delete(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gerenciar: $nomeEstacionamento"),
        backgroundColor: Colors.orange[800],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('estacionamentos')
            .doc(estacionamentoId)
            .collection('vagas')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhuma vaga cadastrada."));
          }

          var vagas = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 colunas de vagas
              childAspectRatio: 1.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: vagas.length,
            itemBuilder: (context, index) {
              var vaga = vagas[index];
              var dados = vaga.data() as Map<String, dynamic>;
              String status = dados['status'] ?? 'livre';
              String idVaga = dados['identificador'] ?? 'Vaga';

              Color corVaga = status == 'livre' ? Colors.green : (status == 'reservada' ? Colors.orange : Colors.red);

              return GestureDetector(
                onTap: () => _alternarStatusVaga(vaga.id, status),
                child: Container(
                  decoration: BoxDecoration(
                    color: corVaga.withOpacity(0.2),
                    border: Border.all(color: corVaga, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car, color: corVaga, size: 30),
                      Text(idVaga, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: corVaga)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}