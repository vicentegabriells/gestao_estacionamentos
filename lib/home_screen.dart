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

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  
  static const CameraPosition _posicaoInicial = CameraPosition(
    target: LatLng(-10.916377, -37.670540), 
    zoom: 15.0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Localizar Vagas'), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        
        stream: FirebaseFirestore.instance.collection('estacionamentos').snapshots(),
        builder: (context, snapshot) {
          Set<Marker> markers = {};

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              var dados = doc.data() as Map<String, dynamic>;
              if (dados.containsKey('localizacao')) {
                GeoPoint p = dados['localizacao'];
                markers.add(
                  Marker(
                    markerId: MarkerId(doc.id),
                    position: LatLng(p.latitude, p.longitude),
                    infoWindow: InfoWindow(
                      title: dados['nome'],
                      snippet: "Toque para ver detalhes",
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
                  ),
                );
              }
            }
          }

          return GoogleMap(
            initialCameraPosition: _posicaoInicial,
            onMapCreated: (controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          );
        },
      ),
    );
  }
}

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

  Future<void> _garantirPerfil(String uid, String email) async {
    final docRef = FirebaseFirestore.instance.collection('usuarios').doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'nome': 'Usuário',
        'email': email,
        'tipoPerfil': 'usuario',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: ElevatedButton(
          onPressed: () => _signOut(context), 
          child: const Text("Sessão expirada. Sair."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil'), automaticallyImplyLeading: false),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          String nomeUsuario = user.displayName ?? 'Usuário';
          String tipoPerfil = 'usuario';
          String emailUsuario = user.email ?? '';

          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            try {
              var dados = snapshot.data!.data() as Map<String, dynamic>;
              nomeUsuario = dados['nome'] ?? nomeUsuario;
              tipoPerfil = dados['tipoPerfil'] ?? tipoPerfil;
            } catch (e) {
              debugPrint("Erro ao ler dados: $e");
            }
          } else {
            _garantirPerfil(user.uid, emailUsuario);
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50))),
                const SizedBox(height: 20),
                Text('Nome: $nomeUsuario', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('E-mail: $emailUsuario'),
                
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Chip(
                    label: Text(tipoPerfil.toUpperCase(), style: const TextStyle(color: Colors.white)),
                    backgroundColor: tipoPerfil == 'admin' ? Colors.orange[800] : Colors.blue[400],
                  ),
                ),
                
                const SizedBox(height: 30),

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
            ),
          );
        },
      ),
    );
  }
}