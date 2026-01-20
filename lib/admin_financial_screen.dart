import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminFinancialScreen extends StatelessWidget {
  final String estacionamentoId;
  final String nomeEstacionamento;

  const AdminFinancialScreen({
    super.key,
    required this.estacionamentoId,
    required this.nomeEstacionamento,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Relatório Financeiro"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.green[50],
            width: double.infinity,
            child: Text(
              "Faturamento: $nomeEstacionamento",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[900],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservas')
                  .where('estacionamentoId', isEqualTo: estacionamentoId)
                  .where('status', isEqualTo: 'concluida') // Lista apenas reservas pagas
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Nenhum pagamento registrado ainda."));
                }

                var reservas = snapshot.data!.docs;
                double faturamentoTotal = 0;

                // Calcula o total somando o campo 'valorTotal' de cada reserva
                for (var doc in reservas) {
                  var dados = doc.data() as Map<String, dynamic>;
                  faturamentoTotal += (dados['valorTotal'] ?? 0.0).toDouble();
                }

                return Column(
                  children: [
                    // Card do Valor Total
                    Card(
                      margin: const EdgeInsets.all(16),
                      elevation: 8,
                      color: Colors.green,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Text("TOTAL ARRECADADO", style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 5),
                            Text(
                              NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(faturamentoTotal),
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 8),
                      child: Align(alignment: Alignment.centerLeft, child: Text("Histórico de Pagamentos:", style: TextStyle(fontWeight: FontWeight.bold))),
                    ),

                    // Lista detalhada
                    Expanded(
                      child: ListView.builder(
                        itemCount: reservas.length,
                        itemBuilder: (context, index) {
                          var doc = reservas[index];
                          var dados = doc.data() as Map<String, dynamic>;
                          double valor = (dados['valorTotal'] ?? 0.0).toDouble();
                          DateTime data = (dados['timestampFim'] as Timestamp).toDate();

                          return ListTile(
                            leading: const Icon(Icons.attach_money, color: Colors.green),
                            title: Text(dados['nomeVaga'] ?? 'Vaga'),
                            subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(data)),
                            trailing: Text(
                              NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}