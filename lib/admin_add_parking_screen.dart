import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AdminAddParkingScreen extends StatefulWidget {
  const AdminAddParkingScreen({super.key});

  @override
  State<AdminAddParkingScreen> createState() => _AdminAddParkingScreenState();
}

class _AdminAddParkingScreenState extends State<AdminAddParkingScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _precoController = TextEditingController();

  LatLng? _localizacaoSelecionada;
  bool _isLoading = false;

  Future<void> _cadastrarEstacionamento() async {
    if (!_formKey.currentState!.validate()) return;

    if (_localizacaoSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, selecione a localização no mapa!"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      double precoHora = double.parse(_precoController.text.replaceAll(',', '.'));

      await FirebaseFirestore.instance.collection('estacionamentos').add({
        'nome': _nomeController.text.trim(),
        'endereco': _enderecoController.text.trim(),
        'tarifas': {
          'hora': precoHora,
        },
        'localizacao': GeoPoint(_localizacaoSelecionada!.latitude, _localizacaoSelecionada!.longitude),
        'criadoEm': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Estacionamento criado com sucesso!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao criar: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirMapaSelecao() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (resultado != null && resultado is LatLng) {
      setState(() {
        _localizacaoSelecionada = resultado;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Novo Estacionamento"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dados do Estabelecimento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: "Nome do Estacionamento", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 10),
              
              TextFormField(
                controller: _enderecoController,
                decoration: const InputDecoration(labelText: "Endereço Completo", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _precoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Preço por Hora (R\$)", prefixText: "R\$ ", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 20),

              const Text("Localização no Mapa", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (_localizacaoSelecionada != null) ...[
                      const Icon(Icons.location_on, color: Colors.green, size: 40),
                      Text(
                        "Lat: ${_localizacaoSelecionada!.latitude.toStringAsFixed(4)}\nLng: ${_localizacaoSelecionada!.longitude.toStringAsFixed(4)}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      const Icon(Icons.map, color: Colors.grey, size: 40),
                      const Text("Nenhuma localização definida"),
                      const SizedBox(height: 10),
                    ],
                    
                    ElevatedButton.icon(
                      onPressed: _abrirMapaSelecao,
                      icon: const Icon(Icons.edit_location_alt),
                      label: Text(_localizacaoSelecionada == null ? "Marcar no Mapa" : "Alterar Localização"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _cadastrarEstacionamento,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                      child: const Text("CRIAR ESTACIONAMENTO", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TELA DE MAPA ---
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // --- ATUALIZAÇÃO: NOVAS COORDENADAS ---
  static const LatLng _center = LatLng(-10.916377, -37.670540); 
  LatLng? _pickedLocation;

  void _onMapTap(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Toque para marcar"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _pickedLocation == null 
              ? null 
              : () => Navigator.pop(context, _pickedLocation),
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 15.0, // Zoom ajustado
            ),
            onTap: _onMapTap,
            markers: _pickedLocation == null 
              ? {} 
              : {
                  Marker(
                    markerId: const MarkerId('picked'),
                    position: _pickedLocation!,
                  ),
                },
          ),
          if (_pickedLocation != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _pickedLocation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(15),
                ),
                child: const Text("CONFIRMAR LOCALIZAÇÃO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          if (_pickedLocation == null)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(8),
                child: const Text(
                  "Toque no mapa para definir a posição",
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}