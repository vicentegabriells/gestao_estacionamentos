import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckoutScreen extends StatefulWidget {
  final DocumentSnapshot reserva;

  const CheckoutScreen({super.key, required this.reserva});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // Variáveis originais do seu código
  bool _carregando = true;
  double _valorEstadia = 0.0;
  String _metodoPagamento = "Pix";
  
  // Novas variáveis para as Multas
  double _valorMultas = 0.0;
  List<Map<String, dynamic>> _listaMultas = [];
  bool _calculandoMultas = true;

  @override
  void initState() {
    super.initState();
    _calcularPrecoEstadia();
    _buscarMultasPendentes();
  }

  // 1. Sua lógica original de cálculo da estadia (adaptada para funcionar com o restante)
  Future<void> _calcularPrecoEstadia() async {
    try {
      var dadosReserva = widget.reserva.data() as Map<String, dynamic>;
      String estacionamentoId = dadosReserva['estacionamentoId'];

      // Busca dados do estacionamento para pegar a tarifa
      DocumentSnapshot docEst = await FirebaseFirestore.instance
          .collection('estacionamentos')
          .doc(estacionamentoId)
          .get();

      if (docEst.exists) {
        var dadosEst = docEst.data() as Map<String, dynamic>;
        // Assume 10.0 se não tiver tarifa cadastrada (ou usa a lógica que você já tinha)
        double tarifaHora = (dadosEst['tarifas']?['hora'] ?? 10.0).toDouble();

        Timestamp entrada = dadosReserva['timestampInicio'];
        Timestamp saida = Timestamp.now(); // Hora atual como saída
        
        int minutos = saida.toDate().difference(entrada.toDate()).inMinutes;
        double horas = minutos / 60.0;
        
        // Mínimo de 1 hora cobrada
        if (horas < 1) horas = 1;

        setState(() {
          _valorEstadia = horas * tarifaHora;
          _carregando = false;
        });
      }
    } catch (e) {
      setState(() { _carregando = false; });
      debugPrint("Erro ao calcular estadia: $e");
    }
  }

  // 2. Nova lógica para buscar multas daquela vaga
  Future<void> _buscarMultasPendentes() async {
    try {
      var dadosReserva = widget.reserva.data() as Map<String, dynamic>;
      String vagaId = dadosReserva['vagaId'];

      // Busca multas pendentes vinculadas a esta vaga
      var snapshot = await FirebaseFirestore.instance
          .collection('multas')
          .where('vagaId', isEqualTo: vagaId)
          .where('status', isEqualTo: 'pendente')
          .get();

      double totalMultas = 0;
      List<Map<String, dynamic>> lista = [];

      for (var doc in snapshot.docs) {
        var dados = doc.data();
        double valor = (dados['valor'] ?? 0.0).toDouble();
        totalMultas += valor;
        
        lista.add({
          'id': doc.id,
          'justificativa': dados['justificativa'] ?? 'Infração',
          'valor': valor,
        });
      }

      setState(() {
        _valorMultas = totalMultas;
        _listaMultas = lista;
        _calculandoMultas = false;
      });

    } catch (e) {
      setState(() { _calculandoMultas = false; });
      debugPrint("Erro ao buscar multas: $e");
    }
  }

  // 3. Processar Pagamento (Estadia + Multas)
  Future<void> _processarPagamento() async {
    setState(() => _carregando = true);

    try {
      var dadosReserva = widget.reserva.data() as Map<String, dynamic>;
      
      // A. Atualiza a Reserva para Concluída
      await FirebaseFirestore.instance.collection('reservas').doc(widget.reserva.id).update({
        'status': 'concluida',
        'timestampFim': FieldValue.serverTimestamp(),
        'valorTotal': _valorEstadia + _valorMultas,
        'metodoPagamento': _metodoPagamento,
      });

      // B. Libera a Vaga
      await FirebaseFirestore.instance
          .collection('estacionamentos')
          .doc(dadosReserva['estacionamentoId'])
          .collection('vagas')
          .doc(dadosReserva['vagaId'])
          .update({
        'status': 'livre',
        'reservadaPor': FieldValue.delete(),
      });

      // C. Baixa as Multas (se houver)
      for (var multa in _listaMultas) {
        await FirebaseFirestore.instance
            .collection('multas')
            .doc(multa['id'])
            .update({'status': 'pago'});
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pagamento realizado com sucesso!"), backgroundColor: Colors.green),
      );
      
      // Volta para a home ou tela anterior
      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalGeral = _valorEstadia + _valorMultas;
    bool carregandoTudo = _carregando || _calculandoMultas;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: carregandoTudo
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Card de Estadia ---
                  const Text("Resumo da Estadia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.timer, color: Colors.blue),
                      title: const Text("Tempo utilizado"),
                      // Aqui você pode melhorar a formatação do tempo se quiser
                      trailing: Text("R\$ ${_valorEstadia.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),

                  // --- Seção de Multas (Só aparece se tiver) ---
                  if (_listaMultas.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text("Infrações / Multas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    Card(
                      color: Colors.red[50],
                      child: Column(
                        children: _listaMultas.map((multa) => ListTile(
                          leading: const Icon(Icons.gavel, color: Colors.red),
                          title: Text(multa['justificativa']),
                          trailing: Text("R\$ ${multa['valor'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        )).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Text("Forma de Pagamento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  
                  RadioListTile(
                    title: const Text("Pix"),
                    value: "Pix",
                    groupValue: _metodoPagamento,
                    onChanged: (v) => setState(() => _metodoPagamento = v.toString()),
                    secondary: const Icon(Icons.qr_code),
                  ),
                  RadioListTile(
                    title: const Text("Cartão de Crédito"),
                    value: "Cartao",
                    groupValue: _metodoPagamento,
                    onChanged: (v) => setState(() => _metodoPagamento = v.toString()),
                    secondary: const Icon(Icons.credit_card),
                  ),

                  const Spacer(),
                  
                  // --- Totalizador ---
                  const Divider(thickness: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TOTAL A PAGAR:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("R\$ ${totalGeral.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _processarPagamento,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                      child: const Text("CONFIRMAR PAGAMENTO", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}