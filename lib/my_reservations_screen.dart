import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyReservationsScreen extends StatelessWidget {
  const MyReservationsScreen({super.key});

  // Função para cancelar a reserva
  Future<void> _cancelarReserva(BuildContext context, String reservaId, String estacionamentoId, String vagaId) async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancelar Reserva"),
        content: const Text("Tem certeza que deseja cancelar? A vaga será liberada."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Não")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sim, Cancelar")),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // 1. Atualiza o status da RESERVA para 'cancelada'
      await FirebaseFirestore.instance.collection('reservas').doc(reservaId).update({
        'status': 'cancelada',
      });

      // 2. Libera a VAGA no estacionamento (volta para 'livre')
      await FirebaseFirestore.instance
          .collection('estacionamentos')
          .doc(estacionamentoId)
          .collection('vagas')
          .doc(vagaId)
          .update({
        'status': 'livre',
        'reservadaPor': FieldValue.delete(), // Remove o campo de dono
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reserva cancelada com sucesso.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao cancelar: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Reservas'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Busca apenas as reservas DESTE usuário
        stream: FirebaseFirestore.instance
            .collection('reservas')
            .where('usuarioId', isEqualTo: userId)
            .orderBy('dataHoraInicio', descending: true) // Mais recentes primeiro
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar reservas.'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Você ainda não fez nenhuma reserva.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          var listaReservas = snapshot.data!.docs;

          return ListView.builder(
            itemCount: listaReservas.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              var reserva = listaReservas[index];
              var dados = reserva.data() as Map<String, dynamic>;
              
              String status = dados['status'] ?? 'ativa';
              String nomeEstacionamento = dados['nomeEstacionamento'] ?? 'Estacionamento';
              String nomeVaga = dados['nomeVaga'] ?? 'Vaga';
              
              // Formata a data (simples)
              Timestamp? dataTs = dados['dataHoraInicio'];
              String dataFormatada = dataTs != null 
                  ? "${dataTs.toDate().day}/${dataTs.toDate().month} às ${dataTs.toDate().hour}:${dataTs.toDate().minute}"
                  : "-";

              // Define cor do status
              Color corStatus = Colors.green;
              if (status == 'cancelada') corStatus = Colors.red;
              if (status == 'concluida') corStatus = Colors.grey;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: corStatus.withOpacity(0.2),
                    child: Icon(Icons.history, color: corStatus),
                  ),
                  title: Text(nomeEstacionamento, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$nomeVaga - $dataFormatada"),
                      Text("Status: ${status.toUpperCase()}", style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  trailing: status == 'ativa' 
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        onPressed: () => _cancelarReserva(
                          context, 
                          reserva.id, 
                          dados['estacionamentoId'], 
                          dados['vagaId']
                        ),
                        tooltip: "Cancelar Reserva",
                      )
                    : null, // Se não for ativa, não mostra botão
                ),
              );
            },
          );
        },
      ),
    );
  }
}