// lib/utils/app_info.dart
class AppInfo {
  // Informações básicas do app
  static const String appName = 'Seus Lembretes';
  static const String version = '1.0.0';
  static const String buildNumber = '1';
  static const String createdBy = 'Criado com ❤️ em Recife/PE';
  static const String developer = '@ProjTech';
  
  // PIX e contato
  static const String pixKey = 'projtechgestaoetecnologia@gmail.com';
  static const String contactEmail = 'projtechgestaoetecnologia@gmail.com';
  
  // Para futuro uso
  static const String downloadUrl = 'https://seusite.com/download'; // você vai criar depois
  
  // LGPD e privacidade
  static const String dataRetentionPeriod = '2 anos';
  static const String lastUpdate = '16 de junho de 2025';
  
  // Mensagens carinhosas para PIX
  static const List<String> pixMessages = [
    'Gostou do app? Me ajude com um PIX! 😊',
    'Um PIX me ajuda a continuar melhorando o app! 🚀',
    'Que tal me prestigiar com um PIX? 😄',
    'Seu apoio faz toda diferença! 💜',
  ];
  
  // Mensagem de transparência
  static const String transparencyMessage = 
    'Este app é 100% offline. Seus lembretes ficam só no seu celular!';
    
  // Dados coletados (se usuário permitir)
  static const List<String> dataCollected = [
    'Modelo do celular (ex: Samsung Galaxy S23)',
    'Versão do Android (ex: Android 13)',
    'Versão do app (para estatísticas)',
    'Reports de bugs (para melhorar o app)',
  ];
  
  // O que NÃO fazemos
  static const List<String> dataNotCollected = [
    'Não acessamos seus contatos',
    'Não lemos suas mensagens',
    'Não sabemos sua localização',
    'Não coletamos dados pessoais sem avisar',
  ];
}