import 'package:flutter/material.dart';// Importa o Flutter Material
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa o Firestore

class CheckoutScreen extends StatefulWidget { // Tela de Checkout / Pagamento
  final DocumentSnapshot reserva;

  const CheckoutScreen({super.key, required this.reserva});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> { // Estado da Tela de Checkout
  bool _carregando = true;
  double _valorTotal = 0.0;
  int _horasTotais = 0;
  String _metodoPagamento = "Pix";

  @override
  void initState() {
    super.initState();
    _calcularPreco();
  }

  // Busca o preço do estacionamento e calcula o total
  Future<void> _calcularPreco() async {
    try {
      var dadosReserva = widget.reserva.data() as Map<String, dynamic>;
      String estacionamentoId = dadosReserva['estacionamentoId'];

      // 1. Busca as tarifas do estacionamento no Firebase
      DocumentSnapshot docEstacionamento = await FirebaseFirestore.instance
          .collection('estacionamentos')
          .doc(estacionamentoId)
          .get();

      if (docEstacionamento.exists) {
        var dadosEst = docEstacionamento.data() as Map<String, dynamic>;
        
        // Garante que lê como número (mesmo que esteja salvo como string ou int)
        double precoHora = (dadosEst['tarifas']['hora'] ?? 0).toDouble();

        // 2. Calcula a duração usando os Timestamps
        Timestamp inicio = dadosReserva['timestampInicio'];
        Timestamp fim = dadosReserva['timestampFim'];
        
        Duration diferenca = fim.toDate().difference(inicio.toDate());
        int horas = diferenca.inHours;
        
        // Cobra pelo menos 1 hora se for menos que isso
        if (horas < 1) horas = 1; 
        
        // Se tiver minutos quebrados (ex: 1h e 10min), arredonda pra 2h (regra de negócio comum)
        if (diferenca.inMinutes % 60 > 0) horas += 1;

        setState(() { // Atualiza o estado com os valores calculados
          _horasTotais = horas;
          _valorTotal = horas * precoHora;
          _carregando = false;
        });
      }
    } catch (e) {// Tratamento de erros
      setState(() {
        _carregando = false;
      });
      print("Erro ao calcular: $e");
    }
  }

  Future<void> _processarPagamento() async { // Simula o processamento do pagamento
    setState(() => _carregando = true);

    // Simulação de tempo de processamento bancário (2 segundos)
    await Future.delayed(const Duration(seconds: 2));

    try {
      var dados = widget.reserva.data() as Map<String, dynamic>;

      // 1. Atualiza a reserva para 'concluida' (Paga)
      await FirebaseFirestore.instance.collection('reservas').doc(widget.reserva.id).update({
        'status': 'concluida',
        'valorTotal': _valorTotal,
        'metodoPagamento': _metodoPagamento,
        'dataPagamento': FieldValue.serverTimestamp(),
      });

      // 2. Libera a vaga no estacionamento (pois o ciclo encerrou)
      // Nota: Em sistemas reais, a vaga só libera quando o carro sai fisicamente.
      // Aqui, assumimos que pagar = sair.
      await FirebaseFirestore.instance
          .collection('estacionamentos')
          .doc(dados['estacionamentoId'])
          .collection('vagas')
          .doc(dados['vagaId'])
          .update({
        'status': 'livre',
        'reservadaPor': FieldValue.delete(),
      });

      if (mounted) {
        // Volta para a tela anterior e mostra sucesso
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pagamento confirmado! Obrigado."), backgroundColor: Colors.green),
        );
      }
    } catch (e) { // Tratamento de erros
      setState(() => _carregando = false);
      if (mounted) { // Verifica se o contexto ainda está válido
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) { // Construção da interface do usuário
    var dados = widget.reserva.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(title: const Text("Checkout / Pagamento")),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Resumo da Estadia", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long, size: 40, color: Colors.blue),
                      title: Text(dados['nomeEstacionamento'] ?? 'Estacionamento'),
                      subtitle: Text("${dados['agendamentoData']}\n${dados['agendamentoEntrada']} até ${dados['agendamentoSaida']}"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Detalhes do Valor
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Tempo Total:", style: TextStyle(fontSize: 16)),
                      Text("$_horasTotais horas", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Valor a Pagar:", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text("R\$ ${_valorTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),

                  const SizedBox(height: 40),
                  const Text("Forma de Pagamento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  
                  // Opções de Pagamento (Simulação)
                  RadioListTile(
                    title: const Text("Pix (Aprovação Imediata)"),
                    subtitle: const Text("Ganha 5% de cashback"),
                    value: "Pix",
                    groupValue: _metodoPagamento,
                    onChanged: (value) => setState(() => _metodoPagamento = value.toString()),
                    secondary: const Icon(Icons.qr_code),
                  ),
                  RadioListTile(
                    title: const Text("Cartão de Crédito"),
                    value: "Cartao",
                    groupValue: _metodoPagamento,
                    onChanged: (value) => setState(() => _metodoPagamento = value.toString()),
                    secondary: const Icon(Icons.credit_card),
                  ),

                  const Spacer(),

                  // Botão de Pagar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _processarPagamento,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                      child: const Text("CONFIRMAR PAGAMENTO", style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}