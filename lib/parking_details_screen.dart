import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ParkingDetailsScreen extends StatelessWidget {
  final String estacionamentoId;
  final Map<String, dynamic> dadosEstacionamento;

  const ParkingDetailsScreen({
    super.key,
    required this.estacionamentoId,
    required this.dadosEstacionamento,
  });

  // Função para abrir o GPS externo
  Future<void> _abrirMapa(BuildContext context) async {
    GeoPoint? ponto = dadosEstacionamento['localizacao'];

    if (ponto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Localização não disponível.")),
      );
      return;
    }

    final double lat = ponto.latitude;
    final double lng = ponto.longitude;

    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");

    if (!await launchUrl(googleMapsUrl)) {
      final Uri webUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
      if (!await launchUrl(webUrl, mode: LaunchMode.externalApplication)) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Não foi possível abrir o mapa.")),
           );
         }
      }
    }
  }

  // Função para realizar a reserva INTELIGENTE
  Future<void> _confirmarReserva(BuildContext context, String vagaId, String nomeVaga, String statusAtual) async {
    DateTime agora = DateTime.now();
    
    // 1. SELETORES DE DATA/HORA
    DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: agora,
      firstDate: agora,
      lastDate: agora.add(const Duration(days: 30)),
      helpText: "DATA DA RESERVA",
    );
    if (dataSelecionada == null || !context.mounted) return;

    TimeOfDay? horaEntrada = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: "HORÁRIO DE CHEGADA",
    );
    if (horaEntrada == null || !context.mounted) return;

    TimeOfDay? horaSaida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: horaEntrada.hour + 1, minute: horaEntrada.minute),
      helpText: "HORÁRIO DE SAÍDA",
    );
    if (horaSaida == null || !context.mounted) return;

    // 2. MONTAR OS OBJETOS DE DATA
    final DateTime inicioDesejado = DateTime(
      dataSelecionada.year, dataSelecionada.month, dataSelecionada.day,
      horaEntrada.hour, horaEntrada.minute
    );
    final DateTime fimDesejado = DateTime(
      dataSelecionada.year, dataSelecionada.month, dataSelecionada.day,
      horaSaida.hour, horaSaida.minute
    );

    if (fimDesejado.isBefore(inicioDesejado)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A saída deve ser depois da entrada!"), backgroundColor: Colors.red));
      return;
    }

    // 3. VERIFICAR CONFLITOS NO BANCO
    try {
      QuerySnapshot reservasExistentes = await FirebaseFirestore.instance
          .collection('reservas')
          .where('estacionamentoId', isEqualTo: estacionamentoId)
          .where('vagaId', isEqualTo: vagaId)
          .where('status', isEqualTo: 'ativa')
          .get();

      bool temConflito = false;
      for (var doc in reservasExistentes.docs) {
        Map<String, dynamic> dados = doc.data() as Map<String, dynamic>;
        Timestamp? inicioExistenteTs = dados['timestampInicio'];
        Timestamp? fimExistenteTs = dados['timestampFim'];

        if (inicioExistenteTs != null && fimExistenteTs != null) {
          if (inicioDesejado.isBefore(fimExistenteTs.toDate()) && fimDesejado.isAfter(inicioExistenteTs.toDate())) {
            temConflito = true;
            break;
          }
        }
      }

      if (temConflito) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Horário indisponível!"), backgroundColor: Colors.orange));
        }
        return;
      }

      // 4. CONFIRMAÇÃO
      String dataTexto = "${dataSelecionada.day}/${dataSelecionada.month}";
      String horaTexto = "${horaEntrada.format(context)} - ${horaSaida.format(context)}";

      bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Reservar $nomeVaga?"),
          content: Text("Agendamento para:\n$dataTexto\n$horaTexto"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirmar")),
          ],
        ),
      );

      if (confirmar != true) return;

      // 5. SALVAR NO FIREBASE
      String userId = FirebaseAuth.instance.currentUser!.uid;
      bool ehParaAgora = inicioDesejado.difference(DateTime.now()).inMinutes.abs() < 15;

      // Só muda o status físico da vaga se for PARA AGORA e ela estiver LIVRE
      if (ehParaAgora && statusAtual == 'livre') {
        await FirebaseFirestore.instance
            .collection('estacionamentos')
            .doc(estacionamentoId)
            .collection('vagas')
            .doc(vagaId)
            .update({
          'status': 'reservada',
          'reservadaPor': userId,
        });
      } else if (ehParaAgora && statusAtual != 'livre') {
         if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Atenção: A vaga está ocupada agora, mas sua reserva foi salva."), backgroundColor: Colors.orange));
        }
      }

      await FirebaseFirestore.instance.collection('reservas').add({
        'usuarioId': userId,
        'estacionamentoId': estacionamentoId,
        'vagaId': vagaId,
        'nomeEstacionamento': dadosEstacionamento['nome'],
        'nomeVaga': nomeVaga,
        'dataHoraInicio': FieldValue.serverTimestamp(),
        'status': 'ativa',
        'timestampInicio': Timestamp.fromDate(inicioDesejado),
        'timestampFim': Timestamp.fromDate(fimDesejado),
        'agendamentoData': "${dataSelecionada.day}/${dataSelecionada.month}/${dataSelecionada.year}",
        'agendamentoEntrada': "${horaEntrada.hour}:${horaEntrada.minute.toString().padLeft(2, '0')}",
        'agendamentoSaida': "${horaSaida.hour}:${horaSaida.minute.toString().padLeft(2, '0')}",
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agendamento realizado!"), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
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
          // --- CABEÇALHO ---
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

                const SizedBox(height: 15),

                // Botão de Navegar (Agora dentro da lista children corretamente)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _abrirMapa(context),
                    icon: const Icon(Icons.directions, color: Colors.white),
                    label: const Text("Traçar Rota até Aqui"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Toque em qualquer vaga para agendar:",
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

                    Color corStatus = Colors.grey;
                    IconData icone = tipo == 'moto' ? Icons.motorcycle : Icons.directions_car;
                    
                    if (status == 'livre') {
                      corStatus = Colors.green;
                    } else if (status == 'ocupada') {
                      corStatus = Colors.red;
                    } else if (status == 'reservada') {
                      corStatus = Colors.orange;
                    }

                    String? reservadaPor = dadosVaga['reservadaPor'];
                    String meuId = FirebaseAuth.instance.currentUser?.uid ?? '';
                    bool isMinhaReserva = (status == 'reservada' && reservadaPor == meuId);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(icone, color: corStatus, size: 30),
                        title: Text(nomeVaga, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(isMinhaReserva ? "RESERVADA POR VOCÊ" : "Status: ${status.toUpperCase()}"),
                        trailing: Icon(
                          status == 'livre' ? Icons.touch_app : Icons.edit_calendar,
                          color: Colors.blue
                        ),
                        onTap: () {
                          if (isMinhaReserva) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text("Você já tem essa vaga reservada agora!"))
                             );
                          } else {
                            // Passamos o status atual
                            _confirmarReserva(context, vaga.id, nomeVaga, status);
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