# 🅿️ Plataforma Inteligente de Gestão de Estacionamentos (PIGE)

## 📝 Sobre o Projeto

Este é um projeto desenvolvido para a disciplina de **Programação para Dispositivos Móveis**, solicitada pelo **Professor Jean Louis**.

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

```bash
flutter pub get

### 3. ⚙️ Configuração do Firebase e Google Maps

O projeto depende de serviços em nuvem do Google e do Google Maps para o funcionamento do mapa e da persistência de dados.
