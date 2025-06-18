class AppInfo {
  static const String appName = 'Seus Lembretes';
  static const String version = '1.0.0';
  static const String buildNumber = '1';
  static const String createdBy = 'Criado em Olinda/PE';
  static const String developer = '@ProjTech';

  // PIX e contato
  static const String pixKey = 'projtechgestaoetecnologia@gmail.com';
  static const String contactEmail = 'projtechgestaoetecnologia@gmail.com';

  // Para futuro uso
  static const String downloadUrl =
      'https://seusite.com/download'; //Criar no futuro

  // LGPD e privacidade
  static const String dataRetentionPeriod = '2 anos';
  static const String lastUpdate = '16 de junho de 2025';

  // Mensagens carinhosas para PIX
  static const List<String> pixMessages = [
    'Gostou do app? Apoie o desenvolvimento com um PIX! 😊',
    'Um PIX me ajuda a continuar melhorando o app! 🚀',
    'Seu apoio vira código novo! 💡💰',
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
