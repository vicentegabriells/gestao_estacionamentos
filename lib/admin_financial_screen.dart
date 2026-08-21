import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:gestao_estacionamentos/constants/app_colors.dart';

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
      backgroundColor: AppColors.adminBackground, 
      appBar: AppBar(
        title: const Text("Relatório Financeiro", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: AppColors.adminHeader,
        foregroundColor: AppColors.adminText,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              "Faturamento: $nomeEstacionamento",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.adminText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservas')
                  .where('estacionamentoId', isEqualTo: estacionamentoId)
                  .where('status', isEqualTo: 'concluida') 
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Nenhum pagamento registrado ainda.", 
                      style: TextStyle(color: AppColors.adminAccent, fontSize: 16)
                    )
                  );
                }

                var reservas = snapshot.data!.docs;
                double faturamentoTotal = 0;

                for (var doc in reservas) {
                  var dados = doc.data() as Map<String, dynamic>;
                  faturamentoTotal += (dados['valorTotal'] ?? 0.0).toDouble();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDarkest.withOpacity(0.6), 
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5), 
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDarkest.withOpacity(0.2), 
                            blurRadius: 15, 
                            offset: const Offset(0, 8)
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "TOTAL ARRECADADO", 
                            style: TextStyle(color: AppColors.textLight.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                          ),
                          const SizedBox(height: 12),
                          Text(
                            NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(faturamentoTotal),
                            style: const TextStyle(color: AppColors.primary, fontSize: 38, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.only(left: 24, bottom: 12),
                      child: Text("Histórico de Pagamentos", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.adminAccent, fontSize: 14, letterSpacing: 1.0)),
                    ),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: reservas.length,
                        itemBuilder: (context, index) {
                          var doc = reservas[index];
                          var dados = doc.data() as Map<String, dynamic>;
                          double valor = (dados['valorTotal'] ?? 0.0).toDouble();
                          DateTime data = (dados['timestampFim'] as Timestamp).toDate();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
                            decoration: BoxDecoration(
                              color: AppColors.adminCard, 
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.attach_money_rounded, color: AppColors.primary),
                              ),
                              title: Text(
                                dados['nomeVaga'] ?? 'Vaga', 
                                style: const TextStyle(color: AppColors.adminText, fontWeight: FontWeight.bold, fontSize: 16)
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(data), 
                                  style: const TextStyle(color: AppColors.adminAccent, fontSize: 13)
                                ),
                              ),
                              trailing: Text(
                                NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                              ),
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