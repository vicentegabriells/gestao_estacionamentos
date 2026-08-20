import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestao_estacionamentos/constants/app_colors.dart';
import 'admin_parking_management_screen.dart';
import 'admin_add_parking_screen.dart'; 

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminBackground, 
      appBar: AppBar(
        title: const Text('Painel do Administrador', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: AppColors.adminHeader,
        foregroundColor: AppColors.adminText,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('estacionamentos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro ao carregar dados.', style: TextStyle(color: Colors.redAccent.withOpacity(0.8))));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.adminAccent));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum estacionamento cadastrado.', style: TextStyle(color: AppColors.adminText, fontWeight: FontWeight.w500)));
          }

          var listaEstacionamentos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemCount: listaEstacionamentos.length,
            itemBuilder: (context, index) {
              var doc = listaEstacionamentos[index];
              var dados = doc.data() as Map<String, dynamic>;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('estacionamentos')
                    .doc(doc.id)
                    .collection('vagas')
                    .snapshots(),
                builder: (context, vagaSnapshot) {
                  int totalVagas = 0;
                  int vagasOcupadas = 0;

                  if (vagaSnapshot.hasData) {
                    totalVagas = vagaSnapshot.data!.docs.length;
                    vagasOcupadas = vagaSnapshot.data!.docs
                        .where((v) => (v.data() as Map<String, dynamic>)['status'] != 'livre')
                        .length;
                  }

                  double percentual = totalVagas > 0 ? (vagasOcupadas / totalVagas) : 0;
                  
                  Color corOcupacao = percentual > 0.8 ? Colors.redAccent : AppColors.adminPrimary;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.adminCard,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AdminParkingManagementScreen(
                                estacionamentoId: doc.id,
                                nomeEstacionamento: dados['nome'] ?? 'Estacionamento',
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.adminAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.business_rounded, color: AppColors.adminAccent, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dados['nome'] ?? 'Sem Nome',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.adminText),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dados['endereco'] ?? 'Sem Endereço',
                                          style: TextStyle(color: AppColors.adminText.withOpacity(0.6), fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.adminPrimary, size: 18),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Ocupação",
                                    style: TextStyle(color: AppColors.adminText.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    "$vagasOcupadas / $totalVagas vagas",
                                    style: TextStyle(color: corOcupacao, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: percentual,
                                  minHeight: 10,
                                  backgroundColor: AppColors.adminBackground.withOpacity(0.5),
                                  valueColor: AlwaysStoppedAnimation<Color>(corOcupacao),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.adminPrimary,
        elevation: 4,
        icon: const Icon(Icons.add_business_rounded, color: AppColors.adminText), 
        label: const Text("Novo Estacionamento", style: TextStyle(color: AppColors.adminText, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminAddParkingScreen()),
          );
        },
      ),
    );
  }
}