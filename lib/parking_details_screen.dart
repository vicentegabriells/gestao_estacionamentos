import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:gestao_estacionamentos/constants/app_colors.dart';

class ParkingDetailsScreen extends StatelessWidget {
  final String estacionamentoId; 
  final Map<String, dynamic> dadosEstacionamento; 

  const ParkingDetailsScreen({
    super.key,
    required this.estacionamentoId,
    required this.dadosEstacionamento,
  });

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

  Future<void> _confirmarReserva(BuildContext context, String vagaId, String nomeVaga, String statusAtual) async {
    DateTime agora = DateTime.now();
    
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

    final DateTime inicioDesejado = DateTime(
      dataSelecionada.year, dataSelecionada.month, dataSelecionada.day,
      horaEntrada.hour, horaEntrada.minute
    );
    final DateTime fimDesejado = DateTime(
      dataSelecionada.year, dataSelecionada.month, dataSelecionada.day,
      horaSaida.hour, horaSaida.minute
    );

    if (fimDesejado.isBefore(inicioDesejado)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A saída deve ser depois da entrada!"), backgroundColor: Colors.redAccent));
      return;
    }

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

      String dataTexto = "${dataSelecionada.day.toString().padLeft(2, '0')}/${dataSelecionada.month.toString().padLeft(2, '0')}";
      String horaTexto = "${horaEntrada.format(context)} - ${horaSaida.format(context)}";

      bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Reservar $nomeVaga?", style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold)),
          content: Text(
            "Agendamento para:\n📅 Dia: $dataTexto\n⏰ Horário: $horaTexto",
            style: TextStyle(color: AppColors.textMuted, fontSize: 16, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), 
              child: const Text("Cancelar", style: TextStyle(color: Colors.redAccent))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context, true), 
              child: const Text("Confirmar ✅", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      String userId = FirebaseAuth.instance.currentUser!.uid;
      bool ehParaAgora = inicioDesejado.difference(DateTime.now()).inMinutes.abs() < 15;

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
        'agendamentoData': "${dataSelecionada.day.toString().padLeft(2, '0')}/${dataSelecionada.month.toString().padLeft(2, '0')}/${dataSelecionada.year}",
        'agendamentoEntrada': "${horaEntrada.hour.toString().padLeft(2, '0')}:${horaEntrada.minute.toString().padLeft(2, '0')}",
        'agendamentoSaida': "${horaSaida.hour.toString().padLeft(2, '0')}:${horaSaida.minute.toString().padLeft(2, '0')}",
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Agendamento realizado!", style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)), backgroundColor: AppColors.primary));
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(dadosEstacionamento['nome'] ?? 'Detalhes', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background, 
        foregroundColor: AppColors.textLight,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface, 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surface, width: 1),
            ),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text("Endereço", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight.withOpacity(0.9), fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Text(dadosEstacionamento['endereco'] ?? 'Sem endereço', style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4)),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: AppColors.background, thickness: 2),
                ),

                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text("Regras", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight.withOpacity(0.9), fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Text(dadosEstacionamento['regras'] ?? 'Sem regras cadastradas', style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4)),
                ),

                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _abrirMapa(context),
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text("Traçar Rota até Aqui", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDarkest,
                      foregroundColor: AppColors.textLight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              "Selecione uma vaga para agendar:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textLight.withOpacity(0.9)),
            ),
          ),
          Expanded( //lista de vagas
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('estacionamentos')
                  .doc(estacionamentoId)
                  .collection('vagas')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erro ao carregar.', style: TextStyle(color: Colors.redAccent.withOpacity(0.8))));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Nenhuma vaga cadastrada.', style: TextStyle(color: AppColors.textMuted)));
                }

                var vagas = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: vagas.length,
                  itemBuilder: (context, index) {
                    var vaga = vagas[index];
                    var dadosVaga = vaga.data() as Map<String, dynamic>;
                    String status = dadosVaga['status'] ?? 'desconhecido';
                    String nomeVaga = dadosVaga['identificador'] ?? 'Vaga ${index + 1}';
                    String tipo = dadosVaga['tipo'] ?? 'carro';

                    Color corStatus = AppColors.textMuted;
                    IconData icone = tipo == 'moto' ? Icons.motorcycle_rounded : Icons.directions_car_rounded;
                    
                    if (status == 'livre') {
                      corStatus = AppColors.primary;
                    } else if (status == 'ocupada') {
                      corStatus = Colors.redAccent;
                    } else if (status == 'reservada') {
                      corStatus = Colors.orangeAccent;
                    }

                    String? reservadaPor = dadosVaga['reservadaPor'];
                    String meuId = FirebaseAuth.instance.currentUser?.uid ?? '';
                    bool isMinhaReserva = (status == 'reservada' && reservadaPor == meuId);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMinhaReserva ? AppColors.primary.withOpacity(0.5) : Colors.transparent, 
                          width: 1
                        )
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: corStatus.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icone, color: corStatus, size: 24),
                        ),
                        title: Text(nomeVaga, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            isMinhaReserva ? "RESERVADA POR VOCÊ" : "Status: ${status.toUpperCase()}",
                            style: TextStyle(color: corStatus.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        trailing: Icon(
                          status == 'livre' ? Icons.touch_app_rounded : Icons.edit_calendar_rounded,
                          color: AppColors.textMuted.withOpacity(0.5),
                        ),
                        onTap: () {
                          if (isMinhaReserva) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text("Você já tem essa vaga reservada agora!"), backgroundColor: AppColors.primaryDark)
                             );
                          } else {
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