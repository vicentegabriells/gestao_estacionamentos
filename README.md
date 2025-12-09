# 🅿️ Plataforma Inteligente de Gestão de Estacionamentos (PIGE)

## 📝 Sobre o Projeto

Este é um projeto desenvolvido para a disciplina de **Programação para Dispositivos Móveis**, solicitada pelo **Professor Jean Louis**.
Estudantes: **Larissa Borges Nascimento de Oliveira**, **Thiago Santana Santos** e **Vicente Gabriel Loiola Souza**.

O **PIGE** é um aplicativo mobile e web construído em **Flutter** e **Firebase** que visa modernizar a experiência de gerenciamento e uso de estacionamentos.

### O Aplicativo

O aplicativo oferece duas interfaces principais:

1.  **Motorista (Usuário):** Permite buscar estacionamentos próximos via Google Maps, visualizar vagas disponíveis em tempo real, fazer agendamentos futuros, cancelar, editar e pagar digitalmente (Checkout/Simulação de Pagamento) por Pix ou Cartão.
2.  **Administrador (Gestor):** Oferece um painel para monitorar e gerenciar seus estacionamentos, alterando status de vagas e acompanhando o faturamento em tempo real (Painel Operacional).

---

## 🛠️ Pré-requisitos e Instalação

Para rodar este projeto em sua máquina local, você precisará ter o ambiente de desenvolvimento configurado corretamente.

### 1. Ferramentas Necessárias

* **Flutter SDK (Versão 3.x ou superior):** Framework principal de desenvolvimento.
* **IDE (VS Code ou Android Studio):** Recomendamos o VS Code com a extensão Dart e Flutter.
* **Firebase CLI (Command Line Interface):** Necessário para gerenciar o projeto Firebase e a configuração local.

### 2. Instalação de Dependências

Após clonar o repositório, navegue até a pasta raiz do projeto no terminal e execute o comando para instalar todas as dependências do Dart:

```bash```

flutter pub get

### 3. ⚙️ Configuração do Firebase e Google Maps

O projeto depende de serviços em nuvem do Google e do Google Maps para o funcionamento do mapa e da persistência de dados.

## A. Configuração do Firebase

1. Crie um novo projeto no Console do Firebase.
2. Conecte o Flutter ao Firebase, seguindo os passos de inicialização para Android e Web: flutter configure
3. No console do Firebase, ative os seguintes serviços:
* Authentication: Habilite o login por Email/Senha.
* Firestore Database: Crie as coleções usuarios, estacionamentos, vagas (subcoleção) e reservas.

## B. Configuração das Chaves de API do Google Maps
O aplicativo usa o Google Maps tanto para o Front-end Web quanto para o Android.
1. Obtenha uma chave de API no Google Cloud Console.
2. Para Web: No arquivo web/index.html, adicione sua chave na tag <script> do Google Maps.
3. Para Android: No arquivo android/app/src/main/AndroidManifest.xml, adicione sua chave na tag <application>:
<manifest ...>
    <application ...>
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="SUA_CHAVE_API_AQUI"/>
        </application>
</manifest>