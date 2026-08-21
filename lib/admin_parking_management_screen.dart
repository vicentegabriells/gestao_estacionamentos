import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestao_estacionamentos/constants/app_colors.dart'; 
import 'admin_financial_screen.dart';

class AdminParkingManagementScreen extends StatelessWidget {
  final String estacionamentoId;
  final String nomeEstacionamento;

  const AdminParkingManagementScreen({
    super.key,
    required this.estacionamentoId,
    required this.nomeEstacionamento,
  });

  void _adicionarVaga(BuildContext context) {
    final TextEditingController idVagaController = TextEditingController();
    String tipoSelecionado = 'carro'; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.adminCard, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Adicionar Nova Vaga", style: TextStyle(color: AppColors.adminText, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idVagaController,
                    style: const TextStyle(color: AppColors.adminText),
                    decoration: InputDecoration(
                      labelText: "Identificador (Ex: A-01)",
                      labelStyle: const TextStyle(color: AppColors.adminAccent),
                      filled: true,
                      fillColor: AppColors.adminBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.adminAccent)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Tipo de Veículo:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.adminAccent)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.adminBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tipoSelecionado,
                        isExpanded: true,
                        dropdownColor: AppColors.adminCard,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.adminAccent),
                        style: const TextStyle(color: AppColors.adminText, fontSize: 16),
                        items: const [
                          DropdownMenuItem(
                            value: 'carro',
                            child: Row(children: [Icon(Icons.directions_car_rounded, color: AppColors.adminAccent), SizedBox(width: 10), Text('Carro')]),
                          ),
                          DropdownMenuItem(
                            value: 'moto',
                            child: Row(children: [Icon(Icons.two_wheeler_rounded, color: AppColors.adminAccent), SizedBox(width: 10), Text('Moto')]),
                          ),
                        ],
                        onChanged: (valor) {
                          setState(() {
                            tipoSelecionado = valor!;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("Cancelar", style: TextStyle(color: Colors.redAccent))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.adminPrimary,
                    foregroundColor: AppColors.adminText,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (idVagaController.text.trim().isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('estacionamentos')
                          .doc(estacionamentoId)
                          .collection('vagas')
                          .add({
                        'identificador': idVagaController.text.trim(),
                        'status': 'livre',
                        'tipo': tipoSelecionado, 
                        'criadoEm': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text("Adicionar", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirDialogoMulta(BuildContext context, String vagaId, String nomeVaga, String? usuarioId) {
    final TextEditingController justificativaController = TextEditingController();
    final TextEditingController valorController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.adminCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Registrar Multa: $nomeVaga", style: const TextStyle(color: AppColors.adminText, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valorController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.adminText),
                decoration: InputDecoration(
                  labelText: "Valor (R\$)", 
                  labelStyle: const TextStyle(color: AppColors.adminAccent),
                  filled: true,
                  fillColor: AppColors.adminBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: justificativaController,
                maxLines: 2,
                style: const TextStyle(color: AppColors.adminText),
                decoration: InputDecoration(
                  labelText: "Motivo", 
                  labelStyle: const TextStyle(color: AppColors.adminAccent),
                  filled: true,
                  fillColor: AppColors.adminBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancelar", style: TextStyle(color: AppColors.adminAccent))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
               double? valor = double.tryParse(valorController.text.replaceAll(',', '.'));
               if (valor != null && justificativaController.text.isNotEmpty) {
                 await FirebaseFirestore.instance.collection('multas').add({
                   'estacionamentoId': estacionamentoId,
                   'vagaId': vagaId,
                   'nomeVaga': nomeVaga,
                   'justificativa': justificativaController.text,
                   'valor': valor,
                   'status': 'pendente',
                   'usuarioId': usuarioId,
                   'dataRegistro': FieldValue.serverTimestamp(),
                 });
                 if (context.mounted) Navigator.pop(context);
                 
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Multa registrada com sucesso!", style: TextStyle(color: AppColors.adminText)), backgroundColor: Colors.redAccent),
                 );
               }
            },
            child: const Text("Multar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _alternarStatusVaga(String vagaId, String statusAtual) async {
    String novoStatus = statusAtual == 'livre' ? 'ocupada' : 'livre';
    await FirebaseFirestore.instance
        .collection('estacionamentos')
        .doc(estacionamentoId)
        .collection('vagas')
        .doc(vagaId)
        .update({
      'status': novoStatus,
      if (novoStatus == 'ocupada') 'reservadaPor': FieldValue.delete(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminBackground, 
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "Gerenciar: $nomeEstacionamento", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
          ),
        ),
        backgroundColor: AppColors.adminHeader,
        foregroundColor: AppColors.adminText,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Ver Faturamento',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AdminFinancialScreen(
                    estacionamentoId: estacionamentoId,
                    nomeEstacionamento: nomeEstacionamento,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('estacionamentos')
            .doc(estacionamentoId)
            .collection('vagas')
            .orderBy('identificador')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.adminAccent));
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return const Center(
               child: Text("Nenhuma vaga criada. Clique em + para adicionar.", 
               style: TextStyle(color: AppColors.adminAccent, fontWeight: FontWeight.w500))
             );
          }

          var vagas = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.95, 
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: vagas.length,
            itemBuilder: (context, index) {
              var vaga = vagas[index];
              var dados = vaga.data() as Map<String, dynamic>;
              
              String status = dados['status'] ?? 'livre';
              String idVaga = dados['identificador'] ?? 'Vaga';
              String tipo = dados['tipo'] ?? 'carro'; 
              String? usuarioId = dados['reservadaPor'];

              Color corVaga = status == 'livre' ? Colors.greenAccent : (status == 'reservada' ? Colors.orangeAccent : Colors.redAccent);
              IconData iconeVaga = tipo == 'moto' ? Icons.two_wheeler_rounded : Icons.directions_car_rounded;

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.adminCard,
                  border: Border.all(color: corVaga.withOpacity(0.5), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: corVaga.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconeVaga, color: corVaga, size: 28),
                          ), 
                          const SizedBox(height: 8),
                          Text(idVaga, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.adminText)),
                          Text(tipo.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.adminAccent, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.adminBackground.withOpacity(0.5),
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.adminAccent, size: 22),
                            tooltip: "Alternar Status",
                            onPressed: () => _alternarStatusVaga(vaga.id, status),
                          ),
                          if (status != 'livre')
                            IconButton(
                              icon: const Icon(Icons.gavel_rounded, color: Colors.redAccent, size: 22),
                              tooltip: "Aplicar Multa",
                              onPressed: () => _abrirDialogoMulta(context, vaga.id, idVaga, usuarioId),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.adminPrimary,
        elevation: 4,
        onPressed: () => _adicionarVaga(context),
        child: const Icon(Icons.add_rounded, color: AppColors.adminText),
      ),
    );
  }
}