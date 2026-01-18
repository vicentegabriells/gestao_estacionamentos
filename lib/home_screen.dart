import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'parking_details_screen.dart';
import 'my_reservations_screen.dart';
import 'admin_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const MapTab(),
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
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- ABA DO MAPA ---
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  Set<Marker> _markers = {};

  static const CameraPosition _posicaoInicial = CameraPosition(
    target: LatLng(-10.9171, -37.6500), 
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _carregarEstacionamentos();
  }

  Future<void> _carregarEstacionamentos() async {
    FirebaseFirestore.instance
        .collection('estacionamentos')
        .get()
        .then((querySnapshot) {
      Set<Marker> novosMarcadores = {};
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> dados = doc.data();
        if (dados.containsKey('localizacao')) {
          GeoPoint ponto = dados['localizacao'];
          novosMarcadores.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(ponto.latitude, ponto.longitude),
              infoWindow: InfoWindow(
                title: dados['nome'] ?? 'Estacionamento',
                snippet: dados['endereco'] ?? '',
                onTap: () {
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
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
          );
        }
      }
      setState(() { _markers = novosMarcadores; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Localizar Vagas'), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
      body: GoogleMap(
        initialCameraPosition: _posicaoInicial,
        onMapCreated: (controller) => _controller.complete(controller),
        markers: _markers,
      ),
    );
  }
}

// --- ABA DO PERFIL (CORRIGIDA) ---
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _alternarPerfil(String uid, String tipoAtual) async {
    String novoTipo = tipoAtual == 'admin' ? 'usuario' : 'admin';
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'tipoPerfil': novoTipo,
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil'), automaticallyImplyLeading: false),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Erro ao carregar perfil."));
          }

          var dados = snapshot.data!.data() as Map<String, dynamic>;
          String tipoPerfil = dados['tipoPerfil'] ?? 'usuario';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50))),
                const SizedBox(height: 20),
                Text('Nome: ${dados['nome'] ?? 'Não informado'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('E-mail: ${user?.email ?? 'Não informado'}'),
                const SizedBox(height: 30),

                // Botão Minhas Reservas
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MyReservationsScreen())),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Minhas Reservas'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  ),
                ),

                const SizedBox(height: 15),

                // BOTÃO DE ADMIN: Só aparece se tipoPerfil for 'admin'
                if (tipoPerfil == 'admin')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminDashboardScreen())),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Painel do Administrador'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                    ),
                  ),

                const Divider(height: 40),
                const Text("Configurações", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Alternar tipo de conta"),
                  subtitle: Text("Atual: ${tipoPerfil.toUpperCase()}"),
                  trailing: const Icon(Icons.swap_horiz),
                  onTap: () => _alternarPerfil(user!.uid, tipoPerfil),
                ),

<<<<<<< HEAD
            const Spacer(), // Empurra o botão Sair para o final da tela
            
            // Botão de Sair (Logout)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _signOut(context), // Chama a função de deslogar
                icon: const Icon(Icons.logout),
                label: const Text('Sair do Aplicativo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),      
              ),
=======
                const Spacer(),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair do Aplicativo'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  ),
                ),
              ],
>>>>>>> upstream/main
            ),
          );
        },
      ),
    );
  }
}