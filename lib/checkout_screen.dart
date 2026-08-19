import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:gestao_estacionamentos/constants/app_colors.dart'; 

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
  
  late DateTime _dataInicio;
  bool _podePagar = false;

  @override
  void initState() {
    super.initState();
    _verificarHorario();
    _calcularTudo();
  }

  void _verificarHorario() {
    var dados = widget.reserva.data() as Map<String, dynamic>;
    Timestamp inicio = dados['timestampInicio'];
    _dataInicio = inicio.toDate();

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
      
      int minutos = saida.toDate().difference(entrada.toDate()).inMinutes;
      double horas = minutos / 60.0;
      if (horas < 1) horas = 1; 
      
      double totalEstadia = horas * tarifa;

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
    if (!_podePagar) return;

    setState(() => _carregando = true);
    try {
      double totalGeral = _valorEstadia + _valorMultas;
      var dadosReserva = widget.reserva.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('reservas').doc(widget.reserva.id).update({
        'status': 'concluida',
        'timestampFim': FieldValue.serverTimestamp(),
        'valorTotal': totalGeral,
        'metodoPagamento': _metodoPagamento,
      });

      await FirebaseFirestore.instance
          .collection('estacionamentos')
          .doc(dadosReserva['estacionamentoId'])
          .collection('vagas')
          .doc(dadosReserva['vagaId'])
          .update({
        'status': 'livre',
        'reservadaPor': FieldValue.delete(),
      });

      for (var m in _listaMultas) {
        await FirebaseFirestore.instance.collection('multas').doc(m['id']).update({'status': 'pago'});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pagamento confirmado!", style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)), backgroundColor: AppColors.primary));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.redAccent));
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double total = _valorEstadia + _valorMultas;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Checkout", style: TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: AppColors.background, 
        foregroundColor: AppColors.textLight,
        elevation: 0,
        centerTitle: true,
      ),
      body: _carregando 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary)) 
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Resumo da Conta", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surface, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Estadia (Tempo de uso)", style: TextStyle(color: AppColors.textMuted.withOpacity(0.9), fontSize: 16)),
                          Text("R\$ ${_valorEstadia.toStringAsFixed(2)}", style: const TextStyle(color: AppColors.textLight, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      
                      if (_valorMultas > 0) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(color: AppColors.background, thickness: 2),
                        ),
                        const Text("Infrações Pendentes", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        ..._listaMultas.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(m['motivo'], style: const TextStyle(color: Colors.redAccent, fontSize: 15))),
                              Text("R\$ ${m['valor'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        )),
                      ],
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: AppColors.background, thickness: 2),
                      ),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("TOTAL A PAGAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textLight)),
                          Text("R\$ ${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),

                if (_podePagar)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _processarPagamento,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text("CONFIRMAR PAGAMENTO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.1),
                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: Colors.orangeAccent, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "O pagamento será liberado a partir de:\n${DateFormat("dd/MM/yyyy 'às' HH:mm").format(_dataInicio)}",
                            style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w600, height: 1.4),
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