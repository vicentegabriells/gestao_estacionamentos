import 'package:cloud_firestore/cloud_firestore.dart'; 
// Importa o Firestore para acesso ao banco de dados
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
// Importa o widget principal do Google Maps
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
// Importa a autenticação para gerenciar o login/logout
import 'login_screen.dart'; 
// Para poder voltar ao login ao sair
import 'parking_details_screen.dart'; 
// Tela de detalhes do estacionamento
import 'my_reservations_screen.dart'; 
// Tela de gerenciamento de reservas
import 'admin_dashboard_screen.dart'; 
// Painel do administrador

// Esta classe é o container principal que gerencia as abas (Mapa e Perfil)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Controla qual aba está ativa (0 = Mapa, 1 = Perfil)

  // Lista de telas que serão exibidas em cada aba do BottomNavigationBar
  static final List<Widget> _widgetOptions = <Widget>[
    // ABA 0: O MAPA com a lógica de marcadores
    const MapTab(),
    
    // ABA 1: O PERFIL do usuário logado
    const ProfileTab(),
  ];

  // Função chamada ao tocar em um item do menu de navegação inferior
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Exibe a tela correspondente ao índice selecionado
      body: _widgetOptions.elementAt(_selectedIndex), 
      // Barra de navegação inferior
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

// --- WIDGET DA ABA DE MAPA (MapTab) ---
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  // Controlador para interagir com o mapa (ex: mover câmera)
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  
  // Conjunto de marcadores (pinos) que serão exibidos no mapa
  Set<Marker> _markers = {};

  // Posição inicial da câmera (Lagarto/SE - Padrão)
  static const CameraPosition _posicaoInicial = CameraPosition(
    target: LatLng(-10.9171, -37.6500), // Coordenadas iniciais
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    // Inicia o carregamento dos dados do estacionamento ao abrir a tela
    _carregarEstacionamentos();
  }

  // Função principal que busca os estacionamentos no Firebase e cria os marcadores
  Future<void> _carregarEstacionamentos() async {
    // 1. Acessa a coleção 'estacionamentos' no Firestore
    FirebaseFirestore.instance
        .collection('estacionamentos')
        .get()
        .then((querySnapshot) {
      
      // Inicializa a lista de marcadores temporária
      Set<Marker> novosMarcadores = {};

      // 2. Itera sobre cada documento (estacionamento) encontrado no banco
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> dados = doc.data();

        // Garante que o documento tenha o campo 'localizacao'
        if (dados.containsKey('localizacao')) {
          GeoPoint ponto = dados['localizacao']; // Converte o Firestore GeoPoint

          // 3. Cria o Marcador (pino) para o Google Maps
          Marker marker = Marker(
            markerId: MarkerId(doc.id), // ID do documento = ID do marcador
            position: LatLng(ponto.latitude, ponto.longitude),
            infoWindow: InfoWindow(
              title: dados['nome'] ?? 'Estacionamento',
              snippet: dados['endereco'] ?? '',
              onTap: () {
                // Ação ao clicar no balão do marcador: Navega para a tela de Detalhes
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
          );

          novosMarcadores.add(marker);
        }
      }

      // 4. Atualiza a interface (setState) com os novos marcadores
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
        // Exibe o conjunto de marcadores carregados do Firebase
        markers: _markers, 
      ),
    );
  }
}

// --- WIDGET DA ABA DE PERFIL (ProfileTab) ---
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  // Função para deslogar do Firebase Auth
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // Função para alternar entre perfil de 'admin' e 'usuario' no Firestore
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
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Escuta as mudanças no documento do usuário logado em tempo real
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          // Enquanto carrega os dados do Firestore
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Se houver erro ou o documento não existir
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Erro ao carregar dados do perfil."));
          }

          // Extrai os dados do documento
          var dados = snapshot.data!.data() as Map<String, dynamic>;
          String tipoPerfil = dados['tipoPerfil'] ?? 'usuario';
          String nomeUsuario = dados['nome'] ?? 'Usuário';

          return Padding(
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
                Text(
                  'Nome:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(nomeUsuario, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text(
                  'E-mail logado:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(user?.email ?? '-', style: const TextStyle(fontSize: 18)),
                
                const SizedBox(height: 30),

                // Botão "Minhas Reservas" - Disponível para todos
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

                const SizedBox(height: 15),

                // --- BOTÃO LÓGICO: Só aparece se tipoPerfil for 'admin' ---
                if (tipoPerfil == 'admin')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Painel do Administrador'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                const Divider(),
                const Text(
                  "Configurações:",
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                
                // Opção para o usuário mudar o próprio papel (Útil para testes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Alternar tipo de conta"),
                  subtitle: Text("Atual: ${tipoPerfil.toUpperCase()}"),
                  trailing: const Icon(Icons.swap_horiz),
                  onTap: () => _alternarPerfil(user!.uid, tipoPerfil),
                ),

                const Spacer(),
                
                // Botão de Sair
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
          );
        },
      ),
    );
  }
}