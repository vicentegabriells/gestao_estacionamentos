import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
              title: const Text("Adicionar Nova Vaga"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idVagaController,
                    decoration: const InputDecoration(
                      labelText: "Identificador (Ex: A-01)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Tipo de Veículo:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DropdownButton<String>(
                    value: tipoSelecionado,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'carro',
                        child: Row(children: [Icon(Icons.directions_car), SizedBox(width: 10), Text('Carro')]),
                      ),
                      DropdownMenuItem(
                        value: 'moto',
                        child: Row(children: [Icon(Icons.two_wheeler), SizedBox(width: 10), Text('Moto')]),
                      ),
                    ],
                    onChanged: (valor) {
                      setState(() {
                        tipoSelecionado = valor!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(
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
                  child: const Text("Adicionar"),
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
        title: Text("Registrar Multa: $nomeVaga"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valorController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Valor (R\$)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: justificativaController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Motivo", border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                    const SnackBar(content: Text("Multa registrada com sucesso!"), backgroundColor: Colors.red),
                 );
               }
            },
            child: const Text("Multar", style: TextStyle(color: Colors.white)),
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
      appBar: AppBar(
        title: Text("Gerenciar: $nomeEstacionamento"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
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
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return const Center(child: Text("Nenhuma vaga criada. Clique em + para adicionar."));
          }

          var vagas = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: vagas.length,
            itemBuilder: (context, index) {
              var vaga = vagas[index];
              var dados = vaga.data() as Map<String, dynamic>;
              
              String status = dados['status'] ?? 'livre';
              String idVaga = dados['identificador'] ?? 'Vaga';
              String tipo = dados['tipo'] ?? 'carro'; 
              String? usuarioId = dados['reservadaPor'];

              Color corVaga = status == 'livre' ? Colors.green : (status == 'reservada' ? Colors.orange : Colors.red);
             
              IconData iconeVaga = tipo == 'moto' ? Icons.two_wheeler : Icons.directions_car;

              return Container(
                decoration: BoxDecoration(
                  color: corVaga.withOpacity(0.1),
                  border: Border.all(color: corVaga, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconeVaga, color: corVaga, size: 30), 
                    Text(idVaga, style: const TextStyle(fontWeight: FontWeight.bold)),
                    
                    Text(tipo.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    
                    const SizedBox(height: 5),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.swap_horiz, color: Colors.blue),
                          onPressed: () => _alternarStatusVaga(vaga.id, status),
                        ),
                        if (status != 'livre')
                          IconButton(
                            icon: const Icon(Icons.gavel, color: Colors.red),
                            onPressed: () => _abrirDialogoMulta(context, vaga.id, idVaga, usuarioId),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange[800],
        onPressed: () => _adicionarVaga(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}