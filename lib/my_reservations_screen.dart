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
        content: const Text("Tem certeza? A vaga será liberada imediatamente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Não")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sim, Cancelar")),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance.collection('reservas').doc(reservaId).update({
        'status': 'cancelada',
      });

      await FirebaseFirestore.instance
          .collection('estacionamentos')
          .doc(estacionamentoId)
          .collection('vagas')
          .doc(vagaId)
          .update({
        'status': 'livre',
        'reservadaPor': FieldValue.delete(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reserva cancelada.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Minhas Reservas'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.event_available), text: "Pendentes"),
              Tab(icon: Icon(Icons.history), text: "Histórico"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reservas')
              .where('usuarioId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var todasReservas = snapshot.data!.docs;

            List<DocumentSnapshot> listaAtivas = [];
            List<DocumentSnapshot> listaHistorico = [];
            DateTime agora = DateTime.now();

            // 1. SEPARAÇÃO
            for (var doc in todasReservas) {
              var dados = doc.data() as Map<String, dynamic>;
              String status = dados['status'] ?? 'ativa';
              
              // Tenta pegar a data de fim. Se for nula, assume futuro para não quebrar.
              Timestamp? fimTs = dados['timestampFim'];
              bool jaPassou = false;
              
              if (fimTs != null) {
                jaPassou = fimTs.toDate().isBefore(agora);
              } else {
                 // Se não tem data de fim (reserva antiga), usa data de criação + 24h
                 Timestamp? criacao = dados['dataHoraInicio'];
                 if (criacao != null) {
                   jaPassou = criacao.toDate().add(const Duration(hours: 24)).isBefore(agora);
                 }
              }

              if (status == 'cancelada' || status == 'concluida' || jaPassou) {
                listaHistorico.add(doc);
              } else {
                listaAtivas.add(doc);
              }
            }

            // 2. ORDENAÇÃO SEGURA (SORT)
            
            // Lista PENDENTES: Crescente
            listaAtivas.sort((a, b) {
              var dadosA = a.data() as Map<String, dynamic>;
              var dadosB = b.data() as Map<String, dynamic>;
              
              // Pega a data ou usa 'agora' como fallback se for nulo
              Timestamp tA = dadosA['timestampInicio'] ?? dadosA['dataHoraInicio'] ?? Timestamp.now();
              Timestamp tB = dadosB['timestampInicio'] ?? dadosB['dataHoraInicio'] ?? Timestamp.now();
              
              return tA.compareTo(tB);
            });

            // Lista HISTÓRICO: Decrescente
            listaHistorico.sort((a, b) {
              var dadosA = a.data() as Map<String, dynamic>;
              var dadosB = b.data() as Map<String, dynamic>;
              
              Timestamp tA = dadosA['timestampInicio'] ?? dadosA['dataHoraInicio'] ?? Timestamp.now();
              Timestamp tB = dadosB['timestampInicio'] ?? dadosB['dataHoraInicio'] ?? Timestamp.now();
              
              return tB.compareTo(tA);
            });

            return TabBarView(
              children: [
                _buildList(context, listaAtivas, true),     // Aba 1
                _buildList(context, listaHistorico, false), // Aba 2
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<DocumentSnapshot> lista, bool permiteCancelar) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(permiteCancelar ? Icons.event_busy : Icons.history_toggle_off, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              permiteCancelar ? "Nenhuma reserva ativa." : "Histórico vazio.",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: lista.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        var reserva = lista[index];
        var dados = reserva.data() as Map<String, dynamic>;
        
        String status = dados['status'] ?? 'ativa';
        String nomeEstacionamento = dados['nomeEstacionamento'] ?? 'Estacionamento';
        String nomeVaga = dados['nomeVaga'] ?? 'Vaga';
        String? dataTexto = dados['agendamentoData'];
        String? horaEntrada = dados['agendamentoEntrada'];
        String? horaSaida = dados['agendamentoSaida'];

        Color corIcone = Colors.green;
        IconData icone = Icons.check_circle_outline;

        if (status == 'cancelada') {
          corIcone = Colors.red;
          icone = Icons.cancel_outlined;
        } else if (status == 'ativa' && !permiteCancelar) {
          corIcone = Colors.grey;
          icone = Icons.access_time;
          status = "EXPIRADA";
        } else if (status == 'concluida') {
          corIcone = Colors.grey;
          icone = Icons.task_alt;
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: corIcone.withOpacity(0.1),
                child: Icon(icone, color: corIcone),
              ),
              title: Text(nomeEstacionamento, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (dataTexto != null)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          "$dataTexto • $horaEntrada até $horaSaida",
                          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                        ),
                      ],
                    )
                  else
                    const Text("Reserva Imediata"),
                  
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: corIcone.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: corIcone, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              trailing: permiteCancelar
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.redAccent),
                      onPressed: () => _cancelarReserva(
                        context, 
                        reserva.id, 
                        dados['estacionamentoId'], 
                        dados['vagaId']
                      ),
                      tooltip: "Cancelar",
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}