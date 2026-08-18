import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestao_estacionamentos/constants/app_colors.dart'; 
import 'package:gestao_estacionamentos/constants/map_styles.dart';
import 'package:gestao_estacionamentos/login_screen.dart';
import 'package:gestao_estacionamentos/parking_details_screen.dart';
import 'package:gestao_estacionamentos/my_reservations_screen.dart';
import 'package:gestao_estacionamentos/admin_dashboard_screen.dart';

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
      backgroundColor: AppColors.background,
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.surface,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted.withOpacity(0.5),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Localizar Vagas', style: TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: AppColors.surface, 
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
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
              controller.setMapStyle(MapStyles.darkTheme); 
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            minMaxZoomPreference: const MinMaxZoomPreference(3.0, 20.0),

            cameraTargetBounds: CameraTargetBounds(
              LatLngBounds(
                southwest: const LatLng(-85.0, -179.9),
                northeast: const LatLng(85.0, 179.9),  
              ),
            ),
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
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
            onPressed: () => _signOut(context), 
            child: const Text("Sessão expirada. Sair."),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meu Perfil', style: TextStyle(fontWeight: FontWeight.bold)), 
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Icon(Icons.person_rounded, size: 60, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 32),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nome', style: TextStyle(color: AppColors.textMuted.withOpacity(0.7), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(nomeUsuario, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textLight)),
                      const Divider(color: AppColors.background, height: 24, thickness: 2),
                      
                      Text('E-mail', style: TextStyle(color: AppColors.textMuted.withOpacity(0.7), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(emailUsuario, style: const TextStyle(fontSize: 16, color: AppColors.textLight)),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Chip(
                    label: Text(
                      tipoPerfil.toUpperCase(), 
                      style: TextStyle(
                        color: tipoPerfil == 'admin' ? AppColors.textLight : AppColors.background,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: tipoPerfil == 'admin' ? AppColors.primaryDarkest : AppColors.primary,
                    side: BorderSide.none,
                  ),
                ),
                
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MyReservationsScreen())),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Minhas Reservas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, 
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                if (tipoPerfil == 'admin')
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminDashboardScreen())),
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                      label: const Text('Painel do Administrador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDarkest, 
                        foregroundColor: AppColors.textLight,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),

                const Spacer(),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    label: const Text('Sair do Aplicativo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
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