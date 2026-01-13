import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminParkingManagementScreen extends StatelessWidget {
  final String estacionamentoId;
  final String nomeEstacionamento;

  const AdminParkingManagementScreen({
    super.key,
    required this.estacionamentoId,
    required this.nomeEstacionamento,
  });

  // Função para abrir o formulário de multa (Com Justificativa e Valor)
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
              const Text("Preencha os dados da infração:"),
              const SizedBox(height: 15),
              // Campo para o Valor da Multa
              TextField(
                controller: valorController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Valor da Multa (R\$)",
                  prefixText: "R\$ ",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              // Campo para a Justificativa
              TextField(
                controller: justificativaController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Justificativa / Observação",
                  hintText: "Ex: Estacionado sem reserva ativa.",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              String justificativa = justificativaController.text.trim();
              String valorTexto = valorController.text.trim().replaceAll(',', '.');
              double? valorMulta = double.tryParse(valorTexto);

              // Validações
              if (valorMulta == null || valorMulta <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Insira um valor válido!")),
                );
                return;
              }
              if (justificativa.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("A justificativa é obrigatória!")),
                );
                return;
              }

              // Salva no Firestore
              await FirebaseFirestore.instance.collection('multas').add({
                'estacionamentoId': estacionamentoId,
                'nomeEstacionamento': nomeEstacionamento,
                'vagaId': vagaId,
                'nomeVaga': nomeVaga,
                'usuarioId': usuarioId ?? "desconhecido",
                'justificativa': justificativa,
                'valor': valorMulta,
                'dataRegistro': FieldValue.serverTimestamp(),
                'status': 'pendente',
              });

              // Verificação de segurança do context
              if (!context.mounted) return;

              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Multa de R\$ $valorTexto registrada!"), 
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text("Confirmar Multa", style: TextStyle(color: Colors.white)),
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('estacionamentos')
            .doc(estacionamentoId)
            .collection('vagas')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhuma vaga cadastrada."));
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
              String? usuarioId = dados['reservadaPor'];

              Color corVaga = status == 'livre' ? Colors.green : (status == 'reservada' ? Colors.orange : Colors.red);

              return Container(
                decoration: BoxDecoration(
                  color: corVaga.withOpacity(0.1),
                  border: Border.all(color: corVaga, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car, color: corVaga, size: 30),
                    Text(idVaga, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
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
    );
  }
}