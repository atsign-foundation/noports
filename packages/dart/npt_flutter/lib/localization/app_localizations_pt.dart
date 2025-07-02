// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get activationStatusActivating => 'Ativando';

  @override
  String get activationStatusOtpWait => 'Por favor, insira o OTP do seu e-mail';

  @override
  String get activationStatusPreparing => 'Preparando para ativação';

  @override
  String get addNew => 'Adicionar Novo';

  @override
  String get advanced => 'Avançado';

  @override
  String get alertDialogTitle => 'Você tem certeza?';

  @override
  String get allRightsReserved => '@ 2025 Atsign, Todos os Direitos Reservados';

  @override
  String get americas => 'Américas';

  @override
  String get approveInstructions =>
      'Por favor, aprov a solicitação no aplicativo com chaves de gerenciador';

  @override
  String get asiaPacific => 'Ásia-Pacífico';

  @override
  String get atDirectory => 'AtDirectory';

  @override
  String get atDirectorySubtitle => 'Selecione o domínio que você deseja usar';

  @override
  String get atsignDialogSubtitle => 'Por favor, selecione seu atSign';

  @override
  String get atsignDialogTitle => 'atSign';

  @override
  String get atsignUncreated => 'Não tem um atSign?';

  @override
  String get authenticate => 'Autenticar';

  @override
  String get authorisation => 'Autorização';

  @override
  String get back => 'Voltar';

  @override
  String get backUpAtKeys => 'Fazer Backup das atKeys';

  @override
  String get backUpAtKeysIntroMsgFirst =>
      'É importante fazer backup de suas atKeys para que você possa acessar seus dados de qualquer dispositivo.\n\nSe você perder suas atKeys, você perderá o acesso aos seus dados.';

  @override
  String get backUpAtKeysIntroMsgLast =>
      '\n\nVocê pode salvar backups adicionais no menu de Configurações a qualquer momento.';

  @override
  String get backUpAtKeysMainMsg =>
      'Suas atKeys serão usadas para emparelhar seu atSign com este e outros dispositivos no futuro.\n\nAs atKeys são chaves criptográficas que são usadas para proteger seu atSign.\n\nElas são exclusivas para você e são usadas para criptografar e descriptografar seus dados.';

  @override
  String get backupKeyDialogTitle =>
      'Por favor, selecione um arquivo para exportar para:';

  @override
  String get backupYourKey => 'Backup da sua Chave';

  @override
  String get cancel => 'Cancelar';

  @override
  String get clientAtsignDescription =>
      'Um atSign é um endereço resolvível\natribuído a um dispositivo.';

  @override
  String get confirm => 'Confirmar';

  @override
  String get connected => 'Conectado';

  @override
  String get custom => 'Personalizado';

  @override
  String get dashboard => 'Painel';

  @override
  String get dashboardView => 'Visualização do Painel';

  @override
  String get debugDumpLogTitle => 'Dev: Despejar Logs no terminal';

  @override
  String get defaultRelaySelection => 'Seleção de Relay Padrão';

  @override
  String get delete => 'Excluir';

  @override
  String get demo => 'Demonstração';

  @override
  String get demoDescription => 'Clique aqui para carregar o perfil de teste.';

  @override
  String get demoTextButton => 'Experimentar Agora';

  @override
  String get deviceAtsign => 'atSign do Dispositivo';

  @override
  String get deviceAtsignDescription =>
      'Este é o atSign associado ao seu dispositivo.';

  @override
  String get deviceName => 'Nome do Dispositivo';

  @override
  String get deviceNameDescription =>
      'Este é o nome do seu dispositivo remoto.';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get discord => 'Suporte do Discord';

  @override
  String get done => 'Concluído';

  @override
  String get duplicate => 'Duplicar';

  @override
  String get edit => 'Editar';

  @override
  String get email => 'Suporte por Email';

  @override
  String get emptyProfileMessage =>
      'Nenhum perfil encontrado\nCrie ou importe um perfil para começar a usar NoPorts.';

  @override
  String get enableLogging => 'Habilitar Log';

  @override
  String get enroll => 'Inscrever-se';

  @override
  String get enrollApproved => 'Solicitação de inscrição aprovada';

  @override
  String get enrollDenied => 'Solicitação de inscrição negada';

  @override
  String get enrollRequestDenied => 'Solicitação de inscrição negada';

  @override
  String get enrollWithAuthenticator => 'Inscrever-se com o Authenticator';

  @override
  String get enrollWithAuthenticatorDescription =>
      'Autenticar através do aplicativo com chaves de gerenciador';

  @override
  String get enterOtp => 'Inserir OTP';

  @override
  String get error => 'Erro';

  @override
  String errorAtKeySaveFailed(Object error) {
    return 'Falha ao salvar o arquivo atKeys: $error';
  }

  @override
  String get errorAtKeysFileProcessFailed =>
      'Falha ao processar o arquivo atKeys';

  @override
  String get errorAtKeysInvalid => 'Arquivo atKeys inválido detectado';

  @override
  String get errorAtKeysUploadedMismatch =>
      'O arquivo atKeys que você carregou não corresponde ao atSign solicitado';

  @override
  String get errorAtServerUnavailable =>
      'Falha ao recuperar o status do atServer, verifique se você tem uma conexão de internet estável.';

  @override
  String get errorAtServerUnreachable =>
      'Não é possível conectar ao atServer, verifique se você tem uma conexão de internet estável.';

  @override
  String errorAtSignAlreadyPaired(Object atsign) {
    return 'O atSign $atsign já está emparelhado, entre em contato com o suporte.';
  }

  @override
  String get errorAtSignNotExist =>
      'O atSign que você solicitou não existe neste domínio raiz.';

  @override
  String get errorAtSignUnavailable =>
      'O atSign está indisponível. Certifique-se de ter pressionado \"Ativar\" no seu painel e ter uma conexão de internet estável.';

  @override
  String get errorAuthenticatinFailed => 'Falha na autenticação.';

  @override
  String get errorAuthenticationTimedOut =>
      'Tempo limite de autenticação excedido.';

  @override
  String get errorOtpRequestFailed =>
      'Falha ao solicitar um OTP, tente reenviar ou entre em contato com o suporte se o problema persistir.';

  @override
  String get errorOtpVerificationFailed =>
      'Falha ao verificar o OTP com o servidor de ativação, tente novamente. Entre em contato com o suporte se o problema persistir.';

  @override
  String get errorProfileLoadFailed =>
      'Falha ao carregar este perfil, por favor, atualize manualmente:';

  @override
  String get errorRootDomainNotSupported =>
      'O domínio raiz especificado não é suportado pela ativação automática.';

  @override
  String get errorSwitchAtSignFailed =>
      'Falha ao trocar de atSigns após a ativação.';

  @override
  String get europe => 'Europa';

  @override
  String get export => 'Exportar';

  @override
  String get exportLogs => 'Exportar Logs';

  @override
  String get faq => 'FAQ';

  @override
  String get feedback => 'Feedback';

  @override
  String get fileFormatInvalid =>
      'O formato do documento é inválido. Por favor, carregue um arquivo válido.';

  @override
  String get fileFormatInvalidDetails =>
      'A seção de perfis está ausente ou formatada incorretamente. Por favor, verifique o documento.';

  @override
  String get fileImported => 'Arquivo Importado';

  @override
  String get fileSaved => 'Arquivo Salvo';

  @override
  String get findOtp =>
      'A solicitação será exibida no Authenticator em Solicitações em qualquer aplicativo conectado ao seu atSign com chaves de gerenciador.';

  @override
  String get getStarted => 'Começar';

  @override
  String get import => 'Importar';

  @override
  String get importFile => 'Importar Arquivo';

  @override
  String get info => 'Informação';

  @override
  String get invalidOtp => 'OTP inválido';

  @override
  String get json => 'JSON';

  @override
  String get keys => 'Enviar atKeys';

  @override
  String get language => 'Idioma';

  @override
  String get loading => 'Carregando';

  @override
  String get localPort => 'Porta Local';

  @override
  String get logs => 'Logs';

  @override
  String get minimal => 'Simples';

  @override
  String get myNoPortsMsg => 'Recupere o seu em ';

  @override
  String get next => 'Próximo';

  @override
  String get noAtsign => 'Sem atSign';

  @override
  String get noEmailClientAvailable => 'Nenhum cliente de email disponível';

  @override
  String get noName => 'Sem Nome';

  @override
  String get noPorts => 'NoPorts';

  @override
  String get onboard => 'Integrar';

  @override
  String get onboardingButtonStatusPicking => 'Aguardando a seleção do arquivo';

  @override
  String get onboardingButtonStatusProcessingFile => 'Processando arquivo';

  @override
  String get onboardingError => 'Ocorreu um erro';

  @override
  String get onboardingSubTitle => 'para NoPorts Desktop';

  @override
  String get onboardingTitle => 'Bem-vindo';

  @override
  String get or => 'Ou';

  @override
  String get overrideAllProfile =>
      'Substituir todos os perfis com a seleção de relay padrão';

  @override
  String get pasteProfile => 'Colar Perfil';

  @override
  String get pasteProfileDescription => 'Cole o conteúdo JSON/YAML aqui';

  @override
  String get preview => 'Visualizar';

  @override
  String get privacyPolicy => 'Política de Privacidade';

  @override
  String get profile => 'Perfil';

  @override
  String get profileDeleteMessage =>
      'Este perfil será excluído permanentemente.';

  @override
  String get profileDeleteSecondaryMessage =>
      'Alguns perfis estão em execução e não serão excluídos, pare esses perfis primeiro para excluí-los.';

  @override
  String get profileDeleteSelectedMessage =>
      'Os perfis selecionados serão excluídos permanentemente.';

  @override
  String get profileExportDialogTitle => 'Escolha o Tipo de Arquivo';

  @override
  String get profileExportMessage =>
      'Qual tipo de arquivo você gostaria de exportar?';

  @override
  String get profileExportSelectedMessage =>
      'Qual tipo de arquivo você gostaria de exportar os perfis selecionados?';

  @override
  String get profileFailedLoaded => 'Falha ao carregar o perfil';

  @override
  String get profileFailedSaveMessage => 'Falha ao salvar o perfil';

  @override
  String get profileFailedUnknownMessage => 'Nenhuma razão fornecida';

  @override
  String get profileImportDialogTitle => 'Escolha o Método de Importação';

  @override
  String get profileImportFailed => 'Falha ao importar o arquivo';

  @override
  String get profileImportSelectedMessage =>
      'Como você gostaria de importar um perfil?';

  @override
  String get profileName => 'Nome do Perfil';

  @override
  String get profileNameDescription =>
      'Este será o nome de suas configurações.';

  @override
  String get profileRunningActionDeniedMessage =>
      'Não é possível realizar esta ação enquanto o perfil estiver em execução.';

  @override
  String get profileRunningCloseMsgStart =>
      'O(s) seguinte(s) perfil(is) está(ão) conectado(s):';

  @override
  String get profilesFailedLoaded => 'Falha ao carregar os perfis';

  @override
  String get profileStatusFailedLoad => 'Falha ao carregar';

  @override
  String get profileStatusFailedSave => 'Falha ao Salvar';

  @override
  String get profileStatusFailedStart => 'Falha ao iniciar';

  @override
  String get profileStatusLoaded => 'Desconectado';

  @override
  String get profileStatusLoadedMessage => 'Atualmente Desconectado';

  @override
  String get profileStatusLoading => 'Carregando';

  @override
  String get profileStatusStarted => 'Conectado';

  @override
  String get profileStatusStartedMessage => 'Conexão bem-sucedida';

  @override
  String get profileStatusStarting => 'Iniciando';

  @override
  String get profileStatusStopping => 'Desligando';

  @override
  String get quit => 'Sair';

  @override
  String get refresh => 'Atualizar';

  @override
  String get register => 'Registrar';

  @override
  String get relay => 'Relay';

  @override
  String get relayDescription =>
      'Escolha entre nossos relays existentes ou crie um novo.';

  @override
  String get reload => 'Recarregar';

  @override
  String get remoteHost => 'Host Remoto';

  @override
  String get remotePort => 'Porta Remota';

  @override
  String get requestExpired =>
      'A solicitação original expirou. Por favor, envie novamente';

  @override
  String get required => 'Obrigatório';

  @override
  String get resendPin => 'Reenviar Pin';

  @override
  String get resetAtsign => 'Redefinir atSign';

  @override
  String get rootDomainDefault => 'Padrão (Prod)';

  @override
  String get rootDomainDemo => 'Demonstração (VE)';

  @override
  String get saveAtKeys => 'Salvar atKeys';

  @override
  String get saveLater => 'Salvar Mais Tarde';

  @override
  String get selectEnrollMethod => 'Selecione seu método de inscrição';

  @override
  String get selectExportFile =>
      'Por favor, selecione um arquivo para exportar para:';

  @override
  String get selectKey => 'Selecionar atKey';

  @override
  String get selectorSubTitleAtsign => 'Insira seu atSign NoPorts abaixo.';

  @override
  String get selectorSubTitleRootDomain =>
      'Insira o domínio atDirectory (anteriormente chamado de domínio raiz).';

  @override
  String get selectorTitleAtsign => 'atSign NoPorts';

  @override
  String get selectorTitleRootDomain => 'Domínio atDirectory';

  @override
  String get serviceMapping => 'Mapeamento de Serviços';

  @override
  String get settings => 'Configurações';

  @override
  String get showWindow => 'Mostrar Janela';

  @override
  String get signout => 'Sair';

  @override
  String get sshStyle => 'Avançado';

  @override
  String get starting => 'Iniciando';

  @override
  String get status => 'Status';

  @override
  String get stopping => 'Desligando';

  @override
  String get submit => 'Enviar';

  @override
  String get submitOtp => 'Enviar OTP';

  @override
  String get success => 'Sucesso';

  @override
  String get switchAtSign => 'Mudar atSign';

  @override
  String get switchAtSignDescription =>
      'Tem certeza de que deseja mudar de atSign?';

  @override
  String get switchAtSignNote =>
      'Observação: Mudar de atSign encerra todas as conexões.';

  @override
  String get syncInProgress =>
      'Sincronização em andamento. Alguns perfis ainda podem estar carregando.';

  @override
  String get unknownError => 'Ocorreu um erro desconhecido';

  @override
  String get uploadKey => 'Enviar atKey';

  @override
  String get uploadKeyDescription => 'Selecione um arquivo .atkey local';

  @override
  String get validationErrorAtsignField => 'O campo deve ser um atSign válido';

  @override
  String get validationErrorDeviceNameField =>
      'O campo só pode conter letras minúsculas, dígitos e underscores.';

  @override
  String get validationErrorEmptyField =>
      'Este campo não pode ser deixado em branco';

  @override
  String get validationErrorLocalPortField =>
      'O número deve estar entre 1024 e 65535';

  @override
  String get validationErrorLongField =>
      'O campo deve ter entre 1 e 36 caracteres';

  @override
  String get validationErrorRelayField => 'O relay deve ser um atSign válido';

  @override
  String get validationErrorRemoteHostField =>
      'O campo deve ser um nome de host parcial ou totalmente qualificado ou um endereço IP';

  @override
  String get validationErrorRemotePortField =>
      'O número deve estar entre 1 e 65535';

  @override
  String get waitingForApproval => 'Aguardando aprovação...';

  @override
  String get whatAreAtKeys => 'O que são atKeys?';

  @override
  String get whatIsClientAtsign => 'O que é um atSign NoPorts?';

  @override
  String get whereToAccept => 'Onde aceitar?';

  @override
  String get whereToAcceptDescription =>
      'Por favor, aprov a solicitação em um aplicativo com uma chave de gerenciador.';

  @override
  String get yaml => 'YAML';

  @override
  String get yamlRecommended => 'YAML (Recomendado)';

  @override
  String get policyManager => 'Gerenciador de Políticas';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get activationStatusActivating => 'Ativando';

  @override
  String get activationStatusOtpWait => 'Por favor, insira o OTP do seu e-mail';

  @override
  String get activationStatusPreparing => 'Preparando para ativação';

  @override
  String get addNew => 'Adicionar Novo';

  @override
  String get advanced => 'Avançado';

  @override
  String get alertDialogTitle => 'Você tem certeza?';

  @override
  String get allRightsReserved => '@ 2025 Atsign, Todos os Direitos Reservados';

  @override
  String get americas => 'Américas';

  @override
  String get approveInstructions =>
      'Por favor, aprov a solicitação no aplicativo com chaves de gerenciador';

  @override
  String get asiaPacific => 'Ásia-Pacífico';

  @override
  String get atDirectory => 'AtDirectory';

  @override
  String get atDirectorySubtitle => 'Selecione o domínio que você deseja usar';

  @override
  String get atsignDialogSubtitle => 'Por favor, selecione seu atSign';

  @override
  String get atsignDialogTitle => 'atSign';

  @override
  String get atsignUncreated => 'Não tem um atSign?';

  @override
  String get authenticate => 'Autenticar';

  @override
  String get authorisation => 'Autorização';

  @override
  String get back => 'Voltar';

  @override
  String get backUpAtKeys => 'Fazer Backup das atKeys';

  @override
  String get backUpAtKeysIntroMsgFirst =>
      'É importante fazer backup de suas atKeys para que você possa acessar seus dados de qualquer dispositivo.\n\nSe você perder suas atKeys, você perderá o acesso aos seus dados.';

  @override
  String get backUpAtKeysIntroMsgLast =>
      '\n\nVocê pode salvar backups adicionais no menu de Configurações a qualquer momento.';

  @override
  String get backUpAtKeysMainMsg =>
      'Suas atKeys serão usadas para emparelhar seu atSign com este e outros dispositivos no futuro.\n\nAs atKeys são chaves criptográficas que são usadas para proteger seu atSign.\n\nElas são exclusivas para você e são usadas para criptografar e descriptografar seus dados.';

  @override
  String get backupKeyDialogTitle =>
      'Por favor, selecione um arquivo para exportar para:';

  @override
  String get backupYourKey => 'Backup da sua Chave';

  @override
  String get cancel => 'Cancelar';

  @override
  String get clientAtsignDescription =>
      'Um atSign é um endereço resolvível\natribuído a um dispositivo.';

  @override
  String get confirm => 'Confirmar';

  @override
  String get connected => 'Conectado';

  @override
  String get custom => 'Personalizado';

  @override
  String get dashboard => 'Painel';

  @override
  String get dashboardView => 'Visualização do Painel';

  @override
  String get debugDumpLogTitle => 'Dev: Despejar Logs no terminal';

  @override
  String get defaultRelaySelection => 'Seleção de Relay Padrão';

  @override
  String get delete => 'Excluir';

  @override
  String get demo => 'Demonstração';

  @override
  String get demoDescription => 'Clique aqui para carregar o perfil de teste.';

  @override
  String get demoTextButton => 'Experimentar Agora';

  @override
  String get deviceAtsign => 'atSign do Dispositivo';

  @override
  String get deviceAtsignDescription =>
      'Este é o atSign associado ao seu dispositivo.';

  @override
  String get deviceName => 'Nome do Dispositivo';

  @override
  String get deviceNameDescription =>
      'Este é o nome do seu dispositivo remoto.';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get discord => 'Suporte do Discord';

  @override
  String get done => 'Concluído';

  @override
  String get duplicate => 'Duplicar';

  @override
  String get edit => 'Editar';

  @override
  String get email => 'Suporte por Email';

  @override
  String get emptyProfileMessage =>
      'Nenhum perfil encontrado\nCrie ou importe um perfil para começar a usar NoPorts.';

  @override
  String get enableLogging => 'Habilitar Log';

  @override
  String get enroll => 'Inscrever-se';

  @override
  String get enrollApproved => 'Solicitação de inscrição aprovada';

  @override
  String get enrollDenied => 'Solicitação de inscrição negada';

  @override
  String get enrollRequestDenied => 'Solicitação de inscrição negada';

  @override
  String get enrollWithAuthenticator => 'Inscrever-se com o Authenticator';

  @override
  String get enrollWithAuthenticatorDescription =>
      'Autenticar através do aplicativo com chaves de gerenciador';

  @override
  String get enterOtp => 'Inserir OTP';

  @override
  String get error => 'Erro';

  @override
  String errorAtKeySaveFailed(Object error) {
    return 'Falha ao salvar o arquivo atKeys: $error';
  }

  @override
  String get errorAtKeysFileProcessFailed =>
      'Falha ao processar o arquivo atKeys';

  @override
  String get errorAtKeysInvalid => 'Arquivo atKeys inválido detectado';

  @override
  String get errorAtKeysUploadedMismatch =>
      'O arquivo atKeys que você carregou não corresponde ao atSign solicitado';

  @override
  String get errorAtServerUnavailable =>
      'Falha ao recuperar o status do atServer, verifique se você tem uma conexão de internet estável.';

  @override
  String get errorAtServerUnreachable =>
      'Não é possível conectar ao atServer, verifique se você tem uma conexão de internet estável.';

  @override
  String errorAtSignAlreadyPaired(Object atsign) {
    return 'O atSign $atsign já está emparelhado, entre em contato com o suporte.';
  }

  @override
  String get errorAtSignNotExist =>
      'O atSign que você solicitou não existe neste domínio raiz.';

  @override
  String get errorAtSignUnavailable =>
      'O atSign está indisponível. Certifique-se de ter pressionado \"Ativar\" no seu painel e ter uma conexão de internet estável.';

  @override
  String get errorAuthenticatinFailed => 'Falha na autenticação.';

  @override
  String get errorAuthenticationTimedOut =>
      'Tempo limite de autenticação excedido.';

  @override
  String get errorOtpRequestFailed =>
      'Falha ao solicitar um OTP, tente reenviar ou entre em contato com o suporte se o problema persistir.';

  @override
  String get errorOtpVerificationFailed =>
      'Falha ao verificar o OTP com o servidor de ativação, tente novamente. Entre em contato com o suporte se o problema persistir.';

  @override
  String get errorProfileLoadFailed =>
      'Falha ao carregar este perfil, por favor, atualize manualmente:';

  @override
  String get errorRootDomainNotSupported =>
      'O domínio raiz especificado não é suportado pela ativação automática.';

  @override
  String get errorSwitchAtSignFailed =>
      'Falha ao trocar de atSigns após a ativação.';

  @override
  String get europe => 'Europa';

  @override
  String get export => 'Exportar';

  @override
  String get exportLogs => 'Exportar Logs';

  @override
  String get faq => 'FAQ';

  @override
  String get feedback => 'Feedback';

  @override
  String get fileFormatInvalid =>
      'O formato do documento é inválido. Por favor, carregue um arquivo válido.';

  @override
  String get fileFormatInvalidDetails =>
      'A seção de perfis está ausente ou formatada incorretamente. Por favor, verifique o documento.';

  @override
  String get fileImported => 'Arquivo Importado';

  @override
  String get fileSaved => 'Arquivo Salvo';

  @override
  String get findOtp =>
      'A solicitação será exibida no Authenticator em Solicitações em qualquer aplicativo conectado ao seu atSign com chaves de gerenciador.';

  @override
  String get getStarted => 'Começar';

  @override
  String get import => 'Importar';

  @override
  String get importFile => 'Importar Arquivo';

  @override
  String get info => 'Informação';

  @override
  String get invalidOtp => 'OTP inválido';

  @override
  String get json => 'JSON';

  @override
  String get keys => 'Enviar atKeys';

  @override
  String get language => 'Idioma';

  @override
  String get loading => 'Carregando';

  @override
  String get localPort => 'Porta Local';

  @override
  String get logs => 'Logs';

  @override
  String get minimal => 'Simples';

  @override
  String get myNoPortsMsg => 'Recupere o seu em ';

  @override
  String get next => 'Próximo';

  @override
  String get noAtsign => 'Sem atSign';

  @override
  String get noEmailClientAvailable => 'Nenhum cliente de email disponível';

  @override
  String get noName => 'Sem Nome';

  @override
  String get noPorts => 'NoPorts';

  @override
  String get onboard => 'Integrar';

  @override
  String get onboardingButtonStatusPicking => 'Aguardando a seleção do arquivo';

  @override
  String get onboardingButtonStatusProcessingFile => 'Processando arquivo';

  @override
  String get onboardingError => 'Ocorreu um erro';

  @override
  String get onboardingSubTitle => 'para NoPorts Desktop';

  @override
  String get onboardingTitle => 'Bem-vindo';

  @override
  String get or => 'Ou';

  @override
  String get overrideAllProfile =>
      'Substituir todos os perfis com a seleção de relay padrão';

  @override
  String get pasteProfile => 'Colar Perfil';

  @override
  String get pasteProfileDescription => 'Cole o conteúdo JSON/YAML aqui';

  @override
  String get preview => 'Visualizar';

  @override
  String get privacyPolicy => 'Política de Privacidade';

  @override
  String get profile => 'Perfil';

  @override
  String get profileDeleteMessage =>
      'Este perfil será excluído permanentemente.';

  @override
  String get profileDeleteSecondaryMessage =>
      'Alguns perfis estão em execução e não serão excluídos, pare esses perfis primeiro para excluí-los.';

  @override
  String get profileDeleteSelectedMessage =>
      'Os perfis selecionados serão excluídos permanentemente.';

  @override
  String get profileExportDialogTitle => 'Escolha o Tipo de Arquivo';

  @override
  String get profileExportMessage =>
      'Qual tipo de arquivo você gostaria de exportar?';

  @override
  String get profileExportSelectedMessage =>
      'Qual tipo de arquivo você gostaria de exportar os perfis selecionados?';

  @override
  String get profileFailedLoaded => 'Falha ao carregar o perfil';

  @override
  String get profileFailedSaveMessage => 'Falha ao salvar o perfil';

  @override
  String get profileFailedUnknownMessage => 'Nenhuma razão fornecida';

  @override
  String get profileImportDialogTitle => 'Escolha o Método de Importação';

  @override
  String get profileImportFailed => 'Falha ao importar o arquivo';

  @override
  String get profileImportSelectedMessage =>
      'Como você gostaria de importar um perfil?';

  @override
  String get profileName => 'Nome do Perfil';

  @override
  String get profileNameDescription =>
      'Este será o nome de suas configurações.';

  @override
  String get profileRunningActionDeniedMessage =>
      'Não é possível realizar esta ação enquanto o perfil estiver em execução.';

  @override
  String get profileRunningCloseMsgStart =>
      'O(s) seguinte(s) perfil(is) está(ão) conectado(s):';

  @override
  String get profilesFailedLoaded => 'Falha ao carregar os perfis';

  @override
  String get profileStatusFailedLoad => 'Falha ao carregar';

  @override
  String get profileStatusFailedSave => 'Falha ao Salvar';

  @override
  String get profileStatusFailedStart => 'Falha ao iniciar';

  @override
  String get profileStatusLoaded => 'Desconectado';

  @override
  String get profileStatusLoadedMessage => 'Atualmente Desconectado';

  @override
  String get profileStatusLoading => 'Carregando';

  @override
  String get profileStatusStarted => 'Conectado';

  @override
  String get profileStatusStartedMessage => 'Conexão bem-sucedida';

  @override
  String get profileStatusStarting => 'Iniciando';

  @override
  String get profileStatusStopping => 'Desligando';

  @override
  String get quit => 'Sair';

  @override
  String get refresh => 'Atualizar';

  @override
  String get register => 'Registrar';

  @override
  String get relay => 'Relay';

  @override
  String get relayDescription =>
      'Escolha entre nossos relays existentes ou crie um novo.';

  @override
  String get reload => 'Recarregar';

  @override
  String get remoteHost => 'Host Remoto';

  @override
  String get remotePort => 'Porta Remota';

  @override
  String get requestExpired =>
      'A solicitação original expirou. Por favor, envie novamente';

  @override
  String get required => 'Obrigatório';

  @override
  String get resendPin => 'Reenviar Pin';

  @override
  String get resetAtsign => 'Redefinir atSign';

  @override
  String get rootDomainDefault => 'Padrão (Prod)';

  @override
  String get rootDomainDemo => 'Demonstração (VE)';

  @override
  String get saveAtKeys => 'Salvar atKeys';

  @override
  String get saveLater => 'Salvar Mais Tarde';

  @override
  String get selectEnrollMethod => 'Selecione seu método de inscrição';

  @override
  String get selectExportFile =>
      'Por favor, selecione um arquivo para exportar para:';

  @override
  String get selectKey => 'Selecionar atKey';

  @override
  String get selectorSubTitleAtsign => 'Insira seu atSign NoPorts abaixo.';

  @override
  String get selectorSubTitleRootDomain =>
      'Insira o domínio atDirectory (anteriormente chamado de domínio raiz).';

  @override
  String get selectorTitleAtsign => 'atSign NoPorts';

  @override
  String get selectorTitleRootDomain => 'Domínio atDirectory';

  @override
  String get serviceMapping => 'Mapeamento de Serviços';

  @override
  String get settings => 'Configurações';

  @override
  String get showWindow => 'Mostrar Janela';

  @override
  String get signout => 'Sair';

  @override
  String get sshStyle => 'Avançado';

  @override
  String get starting => 'Iniciando';

  @override
  String get status => 'Status';

  @override
  String get stopping => 'Desligando';

  @override
  String get submit => 'Enviar';

  @override
  String get submitOtp => 'Enviar OTP';

  @override
  String get success => 'Sucesso';

  @override
  String get switchAtSign => 'Mudar atSign';

  @override
  String get switchAtSignDescription =>
      'Tem certeza de que deseja mudar de atSign?';

  @override
  String get switchAtSignNote =>
      'Observação: Mudar de atSign encerra todas as conexões.';

  @override
  String get syncInProgress =>
      'Sincronização em andamento. Alguns perfis ainda podem estar carregando.';

  @override
  String get unknownError => 'Ocorreu um erro desconhecido';

  @override
  String get uploadKey => 'Enviar atKey';

  @override
  String get uploadKeyDescription => 'Selecione um arquivo .atkey local';

  @override
  String get validationErrorAtsignField => 'O campo deve ser um atSign válido';

  @override
  String get validationErrorDeviceNameField =>
      'O campo só pode conter letras minúsculas, dígitos e underscores.';

  @override
  String get validationErrorEmptyField =>
      'Este campo não pode ser deixado em branco';

  @override
  String get validationErrorLocalPortField =>
      'O número deve estar entre 1024 e 65535';

  @override
  String get validationErrorLongField =>
      'O campo deve ter entre 1 e 36 caracteres';

  @override
  String get validationErrorRelayField => 'O relay deve ser um atSign válido';

  @override
  String get validationErrorRemoteHostField =>
      'O campo deve ser um nome de host parcial ou totalmente qualificado ou um endereço IP';

  @override
  String get validationErrorRemotePortField =>
      'O número deve estar entre 1 e 65535';

  @override
  String get waitingForApproval => 'Aguardando aprovação...';

  @override
  String get whatAreAtKeys => 'O que são atKeys?';

  @override
  String get whatIsClientAtsign => 'O que é um atSign NoPorts?';

  @override
  String get whereToAccept => 'Onde aceitar?';

  @override
  String get whereToAcceptDescription =>
      'Por favor, aprov a solicitação em um aplicativo com uma chave de gerenciador.';

  @override
  String get yaml => 'YAML';

  @override
  String get yamlRecommended => 'YAML (Recomendado)';

  @override
  String get policyManager => 'Gerenciador de Políticas';
}
