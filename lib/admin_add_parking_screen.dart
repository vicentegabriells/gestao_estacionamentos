import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gestao_estacionamentos/constants/app_colors.dart';
import 'package:gestao_estacionamentos/constants/map_styles.dart'; 

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
        const SnackBar(content: Text("Por favor, selecione a localização no mapa!", style: TextStyle(color: AppColors.adminText)), backgroundColor: Colors.redAccent),
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
          const SnackBar(content: Text("Estacionamento criado com sucesso!", style: TextStyle(color: AppColors.adminBackground, fontWeight: FontWeight.bold)), backgroundColor: AppColors.adminAccent),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao criar: $e", style: const TextStyle(color: AppColors.adminText)), backgroundColor: Colors.redAccent),
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

  InputDecoration _buildInputDecoration(String label, {String? prefixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.adminAccent),
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: AppColors.adminText, fontWeight: FontWeight.bold),
      filled: true,
      fillColor: AppColors.adminCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.adminAccent, width: 2),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminBackground, 
      appBar: AppBar(
        title: const Text("Novo Estacionamento", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.adminHeader,
        foregroundColor: AppColors.adminText,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dados do Estabelecimento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.adminText)),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nomeController,
                style: const TextStyle(color: AppColors.adminText),
                decoration: _buildInputDecoration("Nome do Estacionamento"),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _enderecoController,
                style: const TextStyle(color: AppColors.adminText),
                decoration: _buildInputDecoration("Endereço Completo"),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _precoController,
                style: const TextStyle(color: AppColors.adminText),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _buildInputDecoration("Preço por Hora (R\$)", prefixText: "R\$ "),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 32),

              const Text("Localização no Mapa", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.adminText)),
              const SizedBox(height: 16),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.adminCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (_localizacaoSelecionada != null) ...[
                      const Icon(Icons.location_on_rounded, color: AppColors.adminAccent, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        "Lat: ${_localizacaoSelecionada!.latitude.toStringAsFixed(4)}\nLng: ${_localizacaoSelecionada!.longitude.toStringAsFixed(4)}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.adminText, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Icon(Icons.map_rounded, color: AppColors.adminAccent.withOpacity(0.5), size: 48),
                      const SizedBox(height: 8),
                      Text("Nenhuma localização definida", style: TextStyle(color: AppColors.adminAccent.withOpacity(0.7))),
                      const SizedBox(height: 16),
                    ],
                    
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _abrirMapaSelecao,
                        icon: const Icon(Icons.edit_location_alt_rounded),
                        label: Text(_localizacaoSelecionada == null ? "Marcar no Mapa" : "Alterar Localização", style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.adminPrimary, 
                          foregroundColor: AppColors.adminText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.adminAccent))
                  : ElevatedButton.icon(
                      onPressed: _cadastrarEstacionamento,
                      icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.adminBackground),
                      label: const Text("CRIAR ESTACIONAMENTO", style: TextStyle(color: AppColors.adminBackground, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.adminAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                    ),
              ),
              const SizedBox(height: 20), 
            ],
          ),
        ),
      ),
    );
  }
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
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
      backgroundColor: AppColors.adminBackground,
      appBar: AppBar(
        title: const Text("Toque para marcar", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.adminHeader,
        foregroundColor: AppColors.adminText,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
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
              zoom: 15.0, 
            ),
            onMapCreated: (controller) {
              controller.setMapStyle(MapStyles.adminTheme);
            },
            onTap: _onMapTap,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _pickedLocation == null 
              ? {} 
              : {
                  Marker(
                    markerId: const MarkerId('picked'),
                    position: _pickedLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                  ),
                },
          ),
          if (_pickedLocation != null)
            Positioned(
              bottom: 30,
              left: 24,
              right: 24,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _pickedLocation),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.adminAccent,
                    foregroundColor: AppColors.adminBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: const Text("CONFIRMAR LOCALIZAÇÃO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
                ),
              ),
            ),
          if (_pickedLocation == null)
            Positioned(
              top: 20,
              left: 24,
              right: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.adminCard.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_rounded, color: AppColors.adminAccent, size: 24),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        "Toque no mapa para definir a posição",
                        style: TextStyle(color: AppColors.adminText, fontWeight: FontWeight.w600, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}