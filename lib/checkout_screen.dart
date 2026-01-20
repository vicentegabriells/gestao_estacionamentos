import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Importante para formatar a data do aviso

class CheckoutScreen extends StatefulWidget {
  final DocumentSnapshot reserva;

  const CheckoutScreen({super.key, required this.reserva});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _carregando = true;
  double _valorEstadia = 0.0;
  double _valorMultas = 0.0;
  List<Map<String, dynamic>> _listaMultas = [];
  String _metodoPagamento = "Pix";
  
  // Variáveis para controle de tempo
  late DateTime _dataInicio;
  bool _podePagar = false;

  @override
  void initState() {
    super.initState();
    _verificarHorario();
    _calcularTudo();
  }

  // --- NOVA FUNÇÃO: Verifica se já chegou a hora da reserva ---
  void _verificarHorario() {
    var dados = widget.reserva.data() as Map<String, dynamic>;
    Timestamp inicio = dados['timestampInicio'];
    _dataInicio = inicio.toDate();

    // Regra: Só permite pagar se AGORA for DEPOIS do início da reserva
    // Isso cobre "dia e hora certa" e também "reservas que já passaram"
    if (DateTime.now().isAfter(_dataInicio)) {
      _podePagar = true;
    } else {
      _podePagar = false;
    }
  }

  Future<void> _calcularTudo() async {
    try {
      var dadosReserva = widget.reserva.data() as Map<String, dynamic>;
      String estacionamentoId = dadosReserva['estacionamentoId'];
      String vagaId = dadosReserva['vagaId'];

      // 1. Calcular Estadia
      DocumentSnapshot docEst = await FirebaseFirestore.instance
          .collection('estacionamentos')
          .doc(estacionamentoId)
          .get();
      
      double tarifa = 10.0;
      if (docEst.exists) {
        tarifa = (docEst['tarifas']?['hora'] ?? 10.0).toDouble();
      }

      Timestamp entrada = dadosReserva['timestampInicio'];
      Timestamp saida = Timestamp.now();
      
      // Se tentar pagar antes (mesmo que bloqueado visualmente), o cálculo usa 1h mínima
      int minutos = saida.toDate().difference(entrada.toDate()).inMinutes;
      double horas = minutos / 60.0;
      if (horas < 1) horas = 1; 
      
      double totalEstadia = horas * tarifa;

      // 2. Buscar Multas
      var snapshotMultas = await FirebaseFirestore.instance
          .collection('multas')
          .where('vagaId', isEqualTo: vagaId)
          .where('status', isEqualTo: 'pendente')
          .get();

      double totalMultas = 0;
      List<Map<String, dynamic>> multas = [];
      
      for (var doc in snapshotMultas.docs) {
        double v = (doc['valor'] ?? 0.0).toDouble();
        totalMultas += v;
        multas.add({'id': doc.id, 'motivo': doc['justificativa'], 'valor': v});
      }

      if (mounted) {
        setState(() {
          _valorEstadia = totalEstadia;
          _valorMultas = totalMultas;
          _listaMultas = multas;
          _carregando = false;
        });
      }
    } catch (e) {
      debugPrint("Erro: $e");
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _processarPagamento() async {
    // Segurança extra: impede clique forçado
    if (!_podePagar) return;

    setState(() => _carregando = true);
    try {
      double totalGeral = _valorEstadia + _valorMultas;
      var dadosReserva = widget.reserva.data() as Map<String, dynamic>;

      // Atualiza Reserva
      await FirebaseFirestore.instance.collection('reservas').doc(widget.reserva.id).update({
        'status': 'concluida',
        'timestampFim': FieldValue.serverTimestamp(),
        'valorTotal': totalGeral,
        'metodoPagamento': _metodoPagamento,
      });

      // Libera Vaga
      await FirebaseFirestore.instance
          .collection('estacionamentos')
          .doc(dadosReserva['estacionamentoId'])
          .collection('vagas')
          .doc(dadosReserva['vagaId'])
          .update({
        'status': 'livre',
        'reservadaPor': FieldValue.delete(),
      });

      // Baixa nas Multas
      for (var m in _listaMultas) {
        await FirebaseFirestore.instance.collection('multas').doc(m['id']).update({'status': 'pago'});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pagamento confirmado!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double total = _valorEstadia + _valorMultas;

    return Scaffold(
      appBar: AppBar(title: const Text("Checkout"), backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
      body: _carregando ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Resumo da Conta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListTile(title: const Text("Estadia (Tempo de uso)"), trailing: Text("R\$ ${_valorEstadia.toStringAsFixed(2)}")),
            
            if (_valorMultas > 0) ...[
              const Divider(),
              const Text("Infrações Pendentes", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ..._listaMultas.map((m) => ListTile(
                title: Text(m['motivo'], style: const TextStyle(color: Colors.red)),
                trailing: Text("R\$ ${m['valor'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.red)),
              )),
            ],
            
            const Divider(),
            ListTile(
              title: const Text("TOTAL A PAGAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              trailing: Text("R\$ ${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
            ),
            
            const Spacer(),

            // --- LÓGICA DO BOTÃO ---
            if (_podePagar)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _processarPagamento,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("CONFIRMAR PAGAMENTO", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "O pagamento só será liberado a partir de:\n${DateFormat("dd/MM/yyyy 'às' HH:mm").format(_dataInicio)}",
                        style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }
}