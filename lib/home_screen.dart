import 'package:cloud_firestore/cloud_firestore.dart'; // <--- ADICIONE ESTE IMPORT
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // Para poder voltar ao login ao sair
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Importe isto no topo do arquivo!
import 'dart:async'; // Importe para usar o Completer
import 'parking_details_screen.dart';
import 'my_reservations_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Controla qual aba está ativa (0 = Mapa, 1 = Perfil)

  // Lista de telas que serão exibidas em cada aba
  static final List<Widget> _widgetOptions = <Widget>[
    // ABA 0: O MAPA (Por enquanto, um placeholder)
    const MapTab(),
    
    // ABA 1: O PERFIL
    const ProfileTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- WIDGET DA ABA DE MAPA (Agora com Google Maps) ---
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  
  // Conjunto de marcadores que aparecerão no mapa
  Set<Marker> _markers = {};

  // Posição inicial (Lagarto/SE)
  static const CameraPosition _posicaoInicial = CameraPosition(
    target: LatLng(-10.9171, -37.6500), 
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    // Assim que a tela abrir, buscamos os estacionamentos
    _carregarEstacionamentos();
  }

  // Função que vai no Firebase buscar os dados
  Future<void> _carregarEstacionamentos() async {
    // 1. Acessa a coleção 'estacionamentos'
    FirebaseFirestore.instance
        .collection('estacionamentos')
        .get()
        .then((querySnapshot) {
      
      // Criamos um conjunto temporário de marcadores
      Set<Marker> novosMarcadores = {};

      // 2. Para cada documento encontrado no banco...
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> dados = doc.data();

        // Verifica se tem o campo de localização
        if (dados.containsKey('localizacao')) {
          GeoPoint ponto = dados['localizacao']; // O Firestore salva como GeoPoint
          
          // 3. Cria o Marcador para o Google Maps
          Marker marker = Marker(
            markerId: MarkerId(doc.id), // O ID do documento é o ID do marcador
            position: LatLng(ponto.latitude, ponto.longitude),
            infoWindow: InfoWindow(
              title: dados['nome'] ?? 'Estacionamento', // Mostra o nome ao clicar
              snippet: dados['endereco'] ?? '', // Mostra o endereço
              onTap: () {
                // --- CÓDIGO NOVO AQUI ---
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ParkingDetailsScreen(
                      estacionamentoId: doc.id,
                      dadosEstacionamento: dados,
                    ),
                  ),
                );
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), // Cor do pino
          );

          novosMarcadores.add(marker);
        }
      }

      // 4. Atualiza a tela com os novos marcadores
      setState(() {
        _markers = novosMarcadores;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Localizar Vagas'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _posicaoInicial,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        // Passamos a nossa lista de marcadores aqui
        markers: _markers, 
      ),
    );
  }
}

// --- WIDGET DA ABA DE PERFIL ---
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  // Função para deslogar
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    
    if (context.mounted) {
      // Remove todas as telas anteriores e volta para o Login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pega o usuário atual logado
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'E-mail logado:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              user?.email ?? 'Usuário não identificado',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            const Text(
              'UID (ID do Usuário):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              user?.uid ?? '-',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            
            const SizedBox(height: 30), // Espaço

            // --- NOVO BOTÃO AQUI ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const MyReservationsScreen()),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: const Text('Minhas Reservas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const Spacer(),
            
            // Botão de Sair (Logout)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sair do Aplicativo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}