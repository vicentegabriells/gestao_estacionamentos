import 'package:flutter/material.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:gestao_estacionamentos/constants/app_colors.dart'; 
import 'checkout_screen.dart'; 

class MyReservationsScreen extends StatelessWidget {
  const MyReservationsScreen({super.key});

  Future<void> _cancelarReserva(BuildContext context, String reservaId, String estacionamentoId, String vagaId) async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Cancelar Reserva", style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold)),
        content: const Text("Tem certeza? A vaga será liberada imediatamente.", style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Não manter", style: TextStyle(color: AppColors.textMuted))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Sim, Cancelar", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance.collection('reservas').doc(reservaId).update({'status': 'cancelada'});
      await FirebaseFirestore.instance.collection('estacionamentos').doc(estacionamentoId).collection('vagas').doc(vagaId).update({
        'status': 'livre',
        'reservadaPor': FieldValue.delete(),
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reserva cancelada.", style: TextStyle(color: AppColors.background)), backgroundColor: AppColors.primary));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _editarReserva(BuildContext context, DocumentSnapshot docReserva) async {
    var dados = docReserva.data() as Map<String, dynamic>;
    
    Timestamp inicioAtualTs = dados['timestampInicio'] ?? Timestamp.now();
    DateTime dataAtual = inicioAtualTs.toDate();
    TimeOfDay entradaAtual = TimeOfDay.fromDateTime(dataAtual);
    
    Timestamp fimAtualTs = dados['timestampFim'] ?? Timestamp.now();
    TimeOfDay saidaAtual = TimeOfDay.fromDateTime(fimAtualTs.toDate());

    DateTime agora = DateTime.now();

    DateTime? novaData = await showDatePicker(
      context: context,
      initialDate: dataAtual.isBefore(agora) ? agora : dataAtual,
      firstDate: agora,
      lastDate: agora.add(const Duration(days: 30)),
      helpText: "EDITAR DATA",
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.grey[400]!,
              onPrimary: Colors.black,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
          ),
          child: child!,
        );
      },
    );
    if (novaData == null || !context.mounted) return; 

    TimeOfDay? novaEntrada = await showTimePicker(
      context: context,
      initialTime: entradaAtual,
      helpText: "NOVA CHEGADA",
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.grey[400]!,
              onPrimary: Colors.black,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (novaEntrada == null || !context.mounted) return;

    TimeOfDay? novaSaida = await showTimePicker(
      context: context,
      initialTime: saidaAtual,
      helpText: "NOVA SAÍDA",
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.grey[400]!,
              onPrimary: Colors.black,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (novaSaida == null || !context.mounted) return;

    final DateTime novoInicio = DateTime(novaData.year, novaData.month, novaData.day, novaEntrada.hour, novaEntrada.minute);
    final DateTime novoFim = DateTime(novaData.year, novaData.month, novaData.day, novaSaida.hour, novaSaida.minute);

    if (novoFim.isBefore(novoInicio)) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A saída deve ser depois da entrada!"), backgroundColor: Colors.redAccent));
      return;
    }

    try {
      String estacionamentoId = dados['estacionamentoId'];
      String vagaId = dados['vagaId'];

      QuerySnapshot conflitos = await FirebaseFirestore.instance
          .collection('reservas')
          .where('estacionamentoId', isEqualTo: estacionamentoId)
          .where('vagaId', isEqualTo: vagaId)
          .where('status', isEqualTo: 'ativa')
          .get();

      bool temConflito = false;
      for (var doc in conflitos.docs) {

        if (doc.id == docReserva.id) continue; 

        var d = doc.data() as Map<String, dynamic>;
        Timestamp? i = d['timestampInicio'];
        Timestamp? f = d['timestampFim'];

        if (i != null && f != null) { 
          if (novoInicio.isBefore(f.toDate()) && novoFim.isAfter(i.toDate())) {
            temConflito = true;
            break;
          }
        }
      }

      if (temConflito) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Horário indisponível!"), backgroundColor: Colors.orangeAccent));
        return;
      }

      await FirebaseFirestore.instance.collection('reservas').doc(docReserva.id).update({
        'timestampInicio': Timestamp.fromDate(novoInicio),
        'timestampFim': Timestamp.fromDate(novoFim),
        'agendamentoData': "${novaData.day.toString().padLeft(2, '0')}/${novaData.month.toString().padLeft(2, '0')}/${novaData.year}",
        'agendamentoEntrada': "${novaEntrada.hour.toString().padLeft(2, '0')}:${novaEntrada.minute.toString().padLeft(2, '0')}",
        'agendamentoSaida': "${novaSaida.hour.toString().padLeft(2, '0')}:${novaSaida.minute.toString().padLeft(2, '0')}",
      });

      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reserva atualizada!", style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)), backgroundColor: AppColors.primary));

    } catch (e) { 
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) { 
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Minhas Reservas', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textLight,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(icon: Icon(Icons.event_available_rounded), text: "Pendentes"),
              Tab(icon: Icon(Icons.history_rounded), text: "Histórico"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reservas')
              .where('usuarioId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

            var todasReservas = snapshot.data!.docs;
            List<DocumentSnapshot> listaAtivas = [];
            List<DocumentSnapshot> listaHistorico = [];
            DateTime agora = DateTime.now();

            for (var doc in todasReservas) {
              var dados = doc.data() as Map<String, dynamic>;
              String status = dados['status'] ?? 'ativa';
              Timestamp? fimTs = dados['timestampFim'];
              bool jaPassou = false;
              
              if (fimTs != null) {
                jaPassou = fimTs.toDate().isBefore(agora);
              } else {
                 Timestamp? criacao = dados['dataHoraInicio'];
                 if (criacao != null) jaPassou = criacao.toDate().add(const Duration(hours: 24)).isBefore(agora);
              }

              if (status == 'cancelada' || status == 'concluida' || jaPassou) {
                listaHistorico.add(doc);
              } else {
                listaAtivas.add(doc);
              }
            }

            listaAtivas.sort((a, b) {
              var dA = a.data() as Map<String, dynamic>;
              var dB = b.data() as Map<String, dynamic>;
              Timestamp tA = dA['timestampInicio'] ?? dA['dataHoraInicio'] ?? Timestamp.now();
              Timestamp tB = dB['timestampInicio'] ?? dB['dataHoraInicio'] ?? Timestamp.now();
              return tA.compareTo(tB);
            });

            listaHistorico.sort((a, b) {
              var dA = a.data() as Map<String, dynamic>;
              var dB = b.data() as Map<String, dynamic>;
              Timestamp tA = dA['timestampInicio'] ?? dA['dataHoraInicio'] ?? Timestamp.now();
              Timestamp tB = dB['timestampInicio'] ?? dB['dataHoraInicio'] ?? Timestamp.now();
              return tB.compareTo(tA);
            });

            return TabBarView(
              children: [
                _buildList(context, listaAtivas, true),
                _buildList(context, listaHistorico, false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<DocumentSnapshot> lista, bool permiteEdicao) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              permiteEdicao ? Icons.event_busy_rounded : Icons.history_toggle_off_rounded, 
              size: 70, 
              color: AppColors.textMuted.withOpacity(0.3)
            ),
            const SizedBox(height: 16),
            Text(
              permiteEdicao ? "Nenhuma reserva ativa." : "Histórico vazio.",
              style: TextStyle(fontSize: 16, color: AppColors.textMuted.withOpacity(0.7), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: lista.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        var reserva = lista[index];
        var dados = reserva.data() as Map<String, dynamic>;
        
        String status = dados['status'] ?? 'ativa';
        String nomeEstacionamento = dados['nomeEstacionamento'] ?? 'Estacionamento';
        String nomeVaga = dados['nomeVaga'] ?? 'Vaga';
        String? dataTexto = dados['agendamentoData'];
        String? horaEntrada = dados['agendamentoEntrada'];
        String? horaSaida = dados['agendamentoSaida'];

        Color corIcone = AppColors.primary;
        IconData icone = Icons.check_circle_outline_rounded;

        if (status == 'cancelada') {
          corIcone = Colors.redAccent;
          icone = Icons.cancel_outlined;
        } else if (status == 'ativa' && !permiteEdicao) {
          corIcone = AppColors.textMuted;
          icone = Icons.access_time_rounded;
          status = "EXPIRADA";
        } else if (status == 'concluida') {
          corIcone = AppColors.textMuted;
          icone = Icons.task_alt_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: corIcone.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: corIcone.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: corIcone, size: 28),
              ),
              title: Text(nomeEstacionamento, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight, fontSize: 16)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dataTexto != null)
                      Text("📅 $dataTexto • ⏰ $horaEntrada até $horaSaida", style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500))
                    else
                      const Text("⚡ Reserva Imediata", style: TextStyle(color: AppColors.textMuted)),
                    
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: corIcone.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(6)
                      ),
                      child: Text(
                        status.toUpperCase(), 
                        style: TextStyle(color: corIcone, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                      ),
                    ),
                  ],
                ),
              ),
             
              trailing: permiteEdicao
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.payments_rounded, color: AppColors.primary),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CheckoutScreen(reserva: reserva),
                              ),
                            );
                          },
                          tooltip: "Pagar agora",
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                          onPressed: () => _editarReserva(context, reserva),
                          tooltip: "Editar",
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                          onPressed: () => _cancelarReserva(context, reserva.id, dados['estacionamentoId'], dados['vagaId']),
                          tooltip: "Cancelar",
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}