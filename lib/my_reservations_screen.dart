import 'package:flutter/material.dart'; // Flutter Framework
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth
import 'checkout_screen.dart'; // Tela de Checkout

class MyReservationsScreen extends StatelessWidget {
  const MyReservationsScreen({super.key});

  // Função para CANCELAR (Mantida igual)
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

    try { // Atualiza o status da reserva para 'cancelada' e libera a vaga
      await FirebaseFirestore.instance.collection('reservas').doc(reservaId).update({'status': 'cancelada'});
      await FirebaseFirestore.instance.collection('estacionamentos').doc(estacionamentoId).collection('vagas').doc(vagaId).update({
        'status': 'livre',
        'reservadaPor': FieldValue.delete(),
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reserva cancelada.")));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  // --- NOVA FUNÇÃO: EDITAR RESERVA ---
  Future<void> _editarReserva(BuildContext context, DocumentSnapshot docReserva) async {
    var dados = docReserva.data() as Map<String, dynamic>;
    
    // Recupera os dados atuais para preencher o calendário
    Timestamp inicioAtualTs = dados['timestampInicio'] ?? Timestamp.now();
    DateTime dataAtual = inicioAtualTs.toDate();
    TimeOfDay entradaAtual = TimeOfDay.fromDateTime(dataAtual);
    
    Timestamp fimAtualTs = dados['timestampFim'] ?? Timestamp.now();
    TimeOfDay saidaAtual = TimeOfDay.fromDateTime(fimAtualTs.toDate());

    DateTime agora = DateTime.now();

    // 1. SELETORES (Já iniciam com a data da reserva)
    DateTime? novaData = await showDatePicker(
      context: context,
      initialDate: dataAtual.isBefore(agora) ? agora : dataAtual, // Se for antiga, põe hoje
      firstDate: agora,
      lastDate: agora.add(const Duration(days: 30)),
      helpText: "EDITAR DATA",
    );
    if (novaData == null || !context.mounted) return; // Usuário cancelou

    TimeOfDay? novaEntrada = await showTimePicker(
      context: context,
      initialTime: entradaAtual,
      helpText: "NOVA CHEGADA",
    );
    if (novaEntrada == null || !context.mounted) return; // Usuário cancelou

    TimeOfDay? novaSaida = await showTimePicker(
      context: context,
      initialTime: saidaAtual,
      helpText: "NOVA SAÍDA",
    );
    if (novaSaida == null || !context.mounted) return;

    // 2. MONTAR NOVOS DATETIMES
    final DateTime novoInicio = DateTime(novaData.year, novaData.month, novaData.day, novaEntrada.hour, novaEntrada.minute);
    final DateTime novoFim = DateTime(novaData.year, novaData.month, novaData.day, novaSaida.hour, novaSaida.minute);

    if (novoFim.isBefore(novoInicio)) { // Validação básica
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saída deve ser depois da entrada!"), backgroundColor: Colors.red));
      return;
    }

    // 3. VERIFICAR CONFLITOS (Ignorando a própria reserva!)
    try {
      String estacionamentoId = dados['estacionamentoId'];
      String vagaId = dados['vagaId'];

      QuerySnapshot conflitos = await FirebaseFirestore.instance // Verifica conflitos de horário
          .collection('reservas')
          .where('estacionamentoId', isEqualTo: estacionamentoId)
          .where('vagaId', isEqualTo: vagaId)
          .where('status', isEqualTo: 'ativa')
          .get();

      bool temConflito = false;
      for (var doc in conflitos.docs) {
        // PULO DO GATO: Se for a mesma reserva que estou editando, ignora!
        if (doc.id == docReserva.id) continue; 

        var d = doc.data() as Map<String, dynamic>;
        Timestamp? i = d['timestampInicio'];
        Timestamp? f = d['timestampFim'];

        if (i != null && f != null) { // Verifica sobreposição
          if (novoInicio.isBefore(f.toDate()) && novoFim.isAfter(i.toDate())) {
            temConflito = true;
            break;
          }
        }
      }

      if (temConflito) { // Avisar usuário e sair
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Horário indisponível!"), backgroundColor: Colors.orange));
        return;
      }

      // 4. ATUALIZAR NO FIREBASE
      await FirebaseFirestore.instance.collection('reservas').doc(docReserva.id).update({
        'timestampInicio': Timestamp.fromDate(novoInicio),
        'timestampFim': Timestamp.fromDate(novoFim),
        'agendamentoData': "${novaData.day}/${novaData.month}/${novaData.year}",
        'agendamentoEntrada': "${novaEntrada.hour}:${novaEntrada.minute.toString().padLeft(2, '0')}",
        'agendamentoSaida': "${novaSaida.hour}:${novaSaida.minute.toString().padLeft(2, '0')}",
      });

      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reserva atualizada!"), backgroundColor: Colors.green));
      // FIM DA FUNÇÃO
    } catch (e) { // Tratamento de erros
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  @override
  Widget build(BuildContext context) { // Construção da interface do usuário
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
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

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
            Icon(permiteEdicao ? Icons.event_busy : Icons.history_toggle_off, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              permiteEdicao ? "Nenhuma reserva ativa." : "Histórico vazio.",
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
        } else if (status == 'ativa' && !permiteEdicao) {
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
                    Text("$dataTexto • $horaEntrada até $horaSaida", style: const TextStyle(fontWeight: FontWeight.w500))
                  else
                    const Text("Reserva Imediata"),
                  
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: corIcone.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(status.toUpperCase(), style: TextStyle(color: corIcone, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              // AQUI ESTÃO OS BOTÕES DE AÇÃO
              trailing: permiteEdicao
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // BOTÃO PAGAR (NOVO!)
                        IconButton(
                          icon: const Icon(Icons.payments, color: Colors.green),
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
                        
                        // BOTÃO EDITAR
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () => _editarReserva(context, reserva),
                          tooltip: "Editar",
                        ),
                        
                        // BOTÃO CANCELAR
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.redAccent),
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