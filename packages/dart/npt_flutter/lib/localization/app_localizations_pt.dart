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
  String get add => 'Adicionar';

  @override
  String get addAtsign => 'Adicionar atSign';

  @override
  String get addNew => 'Adicionar Novo';

  @override
  String get advanced => 'Avançado';

  @override
  String get advancedSettings => 'Configurações Avançadas';

  @override
  String get alertDialogTitle => 'Você tem certeza?';

  @override
  String get allRightsReserved => '© 2026 Atsign, Todos os Direitos Reservados';

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
  String get atsignFrom => 'De atSign';

  @override
  String get atsignsUser => 'atSigns do Usuário';

  @override
  String get atsignsUserTooltip =>
      'Um atSign como \"@alice\" que estará se conectando a outros dispositivos';

  @override
  String get atsignTo => 'Para atSign';

  @override
  String get atsignUncreated => 'Não tem um atSign?';

  @override
  String get authenticate => 'Autenticar';

  @override
  String get authenticator => 'Authenticator';

  @override
  String get authorisation => 'Autorização';

  @override
  String get autoStartApplication =>
      'Iniciar Aplicação do Cliente Automaticamente';

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
  String get confirm => 'Confirmar';

  @override
  String get connected => 'Conectado';

  @override
  String get connectionClosed => 'Conexão fechada, tentará novamente...';

  @override
  String get connectionRetrying => 'Reconectando (keep-alive)...';

  @override
  String get connections => 'Conexões';

  @override
  String get connectionTimedOut =>
      'Tempo limite da conexão, tentará novamente...';

  @override
  String get connectUriProtocolDescription =>
      'Esta definição lança automaticamente a aplicação apropriada após uma ligação ser estabelecida, com base no protocolo selecionado. Se nenhum protocolo for selecionado, nenhuma aplicação será lançada. Selecione o protocolo a utilizar para a ligação.';

  @override
  String get connectUriProtocolNone => 'Nenhum';

  @override
  String get connectUriUsername => 'Nome de Usuário';

  @override
  String get connectUriUsernameDescription =>
      'Nome de usuário opcional para protocolos como SSH (por exemplo, usuário em ssh://usuário@host)';

  @override
  String get couldNotLoadPreviousState =>
      'Não foi possível carregar o estado anterior';

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
  String get description => 'Descrição';

  @override
  String get deviceAdd => 'Adicionar Dispositivo';

  @override
  String get deviceAtsign => 'atSign do Dispositivo';

  @override
  String get deviceAtsignDescription =>
      'Este é o atSign associado ao seu dispositivo.';

  @override
  String get deviceAtsignDescriptionTwo =>
      'Um atSign como \"@bob_device\", que será conectado. Isso também é conhecido como o daemon ou máquina npd que está executando o processo daemon que receberá solicitações de conexão, onde as conexões serão estabelecidas para este dispositivo.';

  @override
  String get deviceAtsigns => 'atSigns do Dispositivo';

  @override
  String get deviceEdit => 'Editar Dispositivo';

  @override
  String get deviceGroup => 'Grupo de Dispositivo';

  @override
  String get deviceGroupAdd => 'Adicionar Grupo de Dispositivos';

  @override
  String get deviceGroupEdit => 'Editar Grupo de Dispositivos';

  @override
  String get deviceGroupNo => 'Nenhum Grupo de Dispositivos';

  @override
  String get deviceGroups => 'Grupos de Dispositivos';

  @override
  String get deviceGroupsNotAdded =>
      'Nenhum grupo de dispositivos adicionado ainda';

  @override
  String get deviceGroupTooltip =>
      'Processos daemon que especificam a opção --dg com uma string permitirão conexões do usuário para os host:portas especificados';

  @override
  String get deviceName => 'Nome do Dispositivo';

  @override
  String get deviceNameDescription =>
      'Este é o nome do seu dispositivo remoto.';

  @override
  String get devices => 'Dispositivos';

  @override
  String get devicesNotAdded => 'Nenhum dispositivo adicionado ainda';

  @override
  String get devicesTooltip =>
      'Uma string de nome de dispositivo como \"default\" que está sob um atSign de dispositivo. Um atSign de dispositivo pode ter vários nomes de dispositivo, os nomes de dispositivo ajudam a distinguir processos daemon de dispositivos individuais. Adicionar um nome de dispositivo aqui permitirá que túneis sejam estabelecidos dos atSigns do usuário para este par atSign/nome de dispositivo.';

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
  String errorDuringStartupWithDetails(Object errorMessage) {
    return 'Erro durante a inicialização: $errorMessage';
  }

  @override
  String get errorOtpRequestFailed =>
      'Falha ao solicitar um OTP, tente reenviar ou entre em contato com o suporte se o problema persistir.';

  @override
  String get errorOtpVerificationFailed =>
      'Falha ao verificar o OTP com o servidor de ativação, tente novamente. Entre em contato com o suporte se o problema persistir.';

  @override
  String get errorProfileLoadFailed => 'Falha ao carregar este perfil:';

  @override
  String get errorRootDomainNotSupported =>
      'O domínio raiz especificado não é suportado pela ativação automática.';

  @override
  String get errorSwitchAtSignFailed =>
      'Falha ao trocar de atSigns após a ativação.';

  @override
  String errorWithDetails(Object errorMessage) {
    return 'Erro: $errorMessage,';
  }

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
  String get groupAdd => 'Adicionar Grupo';

  @override
  String get groupName => 'Nome do Grupo';

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
  String get jsonCopyToClipboard => 'Copiar JSON para a Área de Transferência';

  @override
  String get jsonPayloadCopiedToClipboard =>
      'Payload JSON copiado para a área de transferência';

  @override
  String get keys => 'Enviar atKeys';

  @override
  String get language => 'Idioma';

  @override
  String get loading => 'Carregando';

  @override
  String get localHost => 'Host Local';

  @override
  String get localHostDescription =>
      'O nome do host ou endereço IP para vincular à sua máquina local';

  @override
  String get localPort => 'Porta Local';

  @override
  String get localPortDescription =>
      'A porta que você usará em sua máquina local';

  @override
  String get logs => 'Logs';

  @override
  String get logsClear => 'Limpar Logs';

  @override
  String get logsNotAvailable =>
      'Nenhum log disponível ainda.\nA atividade aparecerá aqui quando as solicitações de política forem feitas.';

  @override
  String get logsNotAvailableStartMonitoring =>
      'Nenhum log disponível.\nInicie o monitoramento do Gerenciador de Políticas para ver a atividade.';

  @override
  String get logsView => 'Visualizar Logs';

  @override
  String get logType => 'Tipo de Log';

  @override
  String get manageAtsigns => 'Gerenciar atSigns';

  @override
  String get minimal => 'Simples';

  @override
  String get monitoringActive => 'Monitoramento Ativo';

  @override
  String get monitoringInactive => 'Monitoramento Inativo';

  @override
  String get monitoringStart => 'Iniciar Monitoramento';

  @override
  String get monitoringStop => 'Parar Monitoramento';

  @override
  String get name => 'Nome';

  @override
  String get next => 'Próximo';

  @override
  String get noAtsign => 'Sem atSign';

  @override
  String get noAtsignsAdded => 'Nenhum atSign adicionado ainda';

  @override
  String get noDescription => 'Sem descrição';

  @override
  String get noEmailClientAvailable => 'Nenhum cliente de email disponível';

  @override
  String get noName => 'Sem Nome';

  @override
  String get noPorts => 'NoPorts';

  @override
  String get nptStartupTimedout =>
      'Tempo limite de inicialização do Npt excedido';

  @override
  String get ok => 'OK';

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
  String get overrideAllProfile =>
      'Substituir todos os perfis com a seleção de relay padrão';

  @override
  String get pasteProfile => 'Colar Perfil';

  @override
  String get pasteProfileDescription => 'Cole o conteúdo JSON/YAML aqui';

  @override
  String permitOpens(Object permitOpens) {
    return 'Permitir Aberturas: $permitOpens';
  }

  @override
  String get permitOpensHostPort => 'Permitir Aberturas (host:porta)';

  @override
  String get permitOpensNotConfigured =>
      'Nenhuma abertura permitida configurada';

  @override
  String get policy => 'Política';

  @override
  String get policyLogs => 'Logs de Política';

  @override
  String get policyManager => 'Gerenciador de Políticas';

  @override
  String get policyRequestPayload => 'Payload da Solicitação de Política';

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
  String get profileKeepAlive => '🕺 Manter Ativo';

  @override
  String get profileKeepAliveDescription =>
      'Manter ativo. Se uma sessão terminar, crie uma nova sessão e religue à porta local. As sessões podem terminar devido a não serem usadas após um tempo limite ou por problemas de rede.';

  @override
  String get profileName => 'Nome do Perfil';

  @override
  String get profileNameDescription =>
      'Este será o nome de suas configurações.';

  @override
  String get profilePort443 => 'Usar Porta 443';

  @override
  String get profilePort443Description =>
      'Força o relay a usar a porta 443 em vez de uma porta efêmera. Habilita automaticamente o modo de autenticação ESCR do relay para segurança.';

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
  String get remoteHostDescription =>
      'O nome do host ou endereço IP do serviço ao qual você está se conectando na máquina remota';

  @override
  String get remotePort => 'Porta Remota';

  @override
  String get remotePortDescription =>
      'A porta que será usada na máquina remota';

  @override
  String get removeAtsign => 'Remover atSign';

  @override
  String get requestExpired =>
      'A solicitação original expirou. Por favor, envie novamente';

  @override
  String get required => 'Obrigatório';

  @override
  String get resendPin => 'Reenviar Pin';

  @override
  String retryFailedWithDetails(Object errorMessage) {
    return 'Falha ao tentar novamente: $errorMessage, tentará novamente...';
  }

  @override
  String get roleAddNew => 'Adicionar Nova Função';

  @override
  String get roleCreatingFailed => 'Falha ao criar a função';

  @override
  String roleCreatingFailedWithDetails(Object errorMessage) {
    return 'Falha ao criar a função: $errorMessage';
  }

  @override
  String get roleDelete => 'Excluir Função';

  @override
  String roleDeleteConfirmation(Object roleName) {
    return 'Tem certeza de que deseja excluir a função \"$roleName\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get roleDeletedSuccessfully => 'Função excluída com sucesso!';

  @override
  String get roleDeletingFailed => 'Falha ao excluir a função';

  @override
  String roleDeletingFailedWithDetails(Object errorMessage) {
    return 'Falha ao excluir a função: $errorMessage';
  }

  @override
  String roleLoadingFailedWithDetails(Object errorMessage) {
    return 'Falha ao carregar a função: $errorMessage';
  }

  @override
  String get roleNotFound => 'Nenhuma função encontrada';

  @override
  String get roleNotLoaded => 'Nenhuma função carregada';

  @override
  String get roles => 'Funções';

  @override
  String get roleSaveFailed => 'Falha ao salvar a função';

  @override
  String roleSaveFailedWithDetails(Object errorMessage) {
    return 'Falha ao salvar a função: $errorMessage';
  }

  @override
  String get roleSelectToViewDetails =>
      'Selecione uma função para ver os detalhes';

  @override
  String rolesLoadingFailedWithDetails(Object errorMessage) {
    return 'Falha ao carregar as funções: $errorMessage';
  }

  @override
  String get rolesRefresh => 'Atualizar Funções';

  @override
  String get roleUpdatingFailed => 'Falha ao atualizar a função';

  @override
  String roleUpdatingFailedWithDetails(Object errorMessage) {
    return 'Falha ao atualizar a função: $errorMessage';
  }

  @override
  String get rootDomainDefault => 'Padrão (Prod)';

  @override
  String get rootDomainDemo => 'Demonstração (VE)';

  @override
  String get save => 'Salvar';

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
  String get servicesAllowed => 'Serviços Permitidos';

  @override
  String get settings => 'Configurações';

  @override
  String get settingsCouldNotFetch =>
      'Não foi possível buscar as configurações';

  @override
  String get showWindow => 'Mostrar Janela';

  @override
  String get signout => 'Sair';

  @override
  String get socketconnectorClosedPrematurely =>
      'Socketconnector fechado prematuramente';

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
  String get syncCompleted =>
      'Sincronização concluída. Todos os perfis carregados.';

  @override
  String get syncInProgress =>
      'Sincronização em andamento. Alguns perfis ainda podem estar carregando.';

  @override
  String get timestamp => 'Timestamp';

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
  String get validationErrorHostField =>
      'O campo deve ser um nome de host parcial ou totalmente qualificado ou um endereço IP';

  @override
  String get validationErrorLocalPortField =>
      'O número deve estar entre 1024 e 65535';

  @override
  String get validationErrorLongField =>
      'O campo deve ter entre 1 e 36 caracteres';

  @override
  String get validationErrorRelayField => 'O relay deve ser um atSign válido';

  @override
  String get validationErrorRemotePortField =>
      'O número deve estar entre 1 e 65535';

  @override
  String get waitingForApproval => 'Aguardando aprovação...';

  @override
  String get whatAreAtKeys => 'O que são atKeys?';

  @override
  String get whereToAccept => 'Onde aceitar?';

  @override
  String get whereToAcceptDescription =>
      'Por favor, aprov a solicitação em um aplicativo com uma chave de gerenciador.';

  @override
  String get yaml => 'YAML';

  @override
  String get activationComplete => 'Complete Activation';

  @override
  String get activationFileBased => 'File-based Activation';

  @override
  String get activationFileBasedDescription =>
      'Please upload the file saved from your Management Portal. \nYou’ll only need to do this once.';

  @override
  String get activationLinkText => 'Where to find this →';

  @override
  String get activationButtonDescription =>
      'Complete Activation and set up a new atSign';

  @override
  String get activationDragDropDescription =>
      'OR drag and drop your .YAML file';

  @override
  String get activationFileUploadDescription =>
      'Upload one-time activation file';

  @override
  String get activationManual => 'Manual Activation';

  @override
  String get signIn => 'Sign In';

  @override
  String get signInButtonDescription => 'Sign in with an activated atSign';

  @override
  String get whatIsAnAtsign => 'What is an atSign?';

  @override
  String get whatIsAnAtsignDescription =>
      'An atSign is a resolvable\naddress assigned to a device.';

  @override
  String get or => 'Ou';

  @override
  String get myNoPortsMsg => 'Recupere o seu em ';

  @override
  String get yamlRecommended => 'YAML (Recomendado)';
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
  String get add => 'Adicionar';

  @override
  String get addAtsign => 'Adicionar atSign';

  @override
  String get addNew => 'Adicionar Novo';

  @override
  String get advanced => 'Avançado';

  @override
  String get advancedSettings => 'Configurações Avançadas';

  @override
  String get alertDialogTitle => 'Você tem certeza?';

  @override
  String get allRightsReserved => '© 2026 Atsign, Todos os Direitos Reservados';

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
  String get atsignFrom => 'De atSign';

  @override
  String get atsignsUser => 'atSigns do Usuário';

  @override
  String get atsignsUserTooltip =>
      'Um atSign como \"@alice\" que estará se conectando a outros dispositivos';

  @override
  String get atsignTo => 'Para atSign';

  @override
  String get atsignUncreated => 'Não tem um atSign?';

  @override
  String get authenticate => 'Autenticar';

  @override
  String get authenticator => 'Authenticator';

  @override
  String get authorisation => 'Autorização';

  @override
  String get autoStartApplication =>
      'Iniciar Aplicação do Cliente Automaticamente';

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
  String get confirm => 'Confirmar';

  @override
  String get connected => 'Conectado';

  @override
  String get connectionClosed => 'Conexão fechada, tentará novamente...';

  @override
  String get connectionRetrying => 'Reconectando (keep-alive)...';

  @override
  String get connections => 'Conexões';

  @override
  String get connectionTimedOut =>
      'Tempo limite da conexão, tentará novamente...';

  @override
  String get connectUriProtocolDescription =>
      'Esta configuração inicia automaticamente o aplicativo apropriado após uma conexão ser estabelecida, com base no protocolo selecionado. Se nenhum protocolo for selecionado, nenhum aplicativo será iniciado. Selecione o protocolo a ser usado para a conexão.';

  @override
  String get connectUriProtocolNone => 'Nenhum';

  @override
  String get connectUriUsername => 'Nome de Usuário';

  @override
  String get connectUriUsernameDescription =>
      'Nome de usuário opcional para protocolos como SSH (por exemplo, usuário em ssh://usuário@host)';

  @override
  String get couldNotLoadPreviousState =>
      'Não foi possível carregar o estado anterior';

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
  String get description => 'Descrição';

  @override
  String get deviceAdd => 'Adicionar Dispositivo';

  @override
  String get deviceAtsign => 'atSign do Dispositivo';

  @override
  String get deviceAtsignDescription =>
      'Este é o atSign associado ao seu dispositivo.';

  @override
  String get deviceAtsignDescriptionTwo =>
      'Um atSign como \"@bob_device\", que será conectado. Isso também é conhecido como o daemon ou máquina npd que está executando o processo daemon que receberá solicitações de conexão, onde as conexões serão estabelecidas para este dispositivo.';

  @override
  String get deviceAtsigns => 'atSigns do Dispositivo';

  @override
  String get deviceEdit => 'Editar Dispositivo';

  @override
  String get deviceGroup => 'Grupo de Dispositivo';

  @override
  String get deviceGroupAdd => 'Adicionar Grupo de Dispositivos';

  @override
  String get deviceGroupEdit => 'Editar Grupo de Dispositivos';

  @override
  String get deviceGroupNo => 'Nenhum Grupo de Dispositivos';

  @override
  String get deviceGroups => 'Grupos de Dispositivos';

  @override
  String get deviceGroupsNotAdded =>
      'Nenhum grupo de dispositivos adicionado ainda';

  @override
  String get deviceGroupTooltip =>
      'Processos daemon que especificam a opção --dg com uma string permitirão conexões do usuário para os host:portas especificados';

  @override
  String get deviceName => 'Nome do Dispositivo';

  @override
  String get deviceNameDescription =>
      'Este é o nome do seu dispositivo remoto.';

  @override
  String get devices => 'Dispositivos';

  @override
  String get devicesNotAdded => 'Nenhum dispositivo adicionado ainda';

  @override
  String get devicesTooltip =>
      'Uma string de nome de dispositivo como \"default\" que está sob um atSign de dispositivo. Um atSign de dispositivo pode ter vários nomes de dispositivo, os nomes de dispositivo ajudam a distinguir processos daemon de dispositivos individuais. Adicionar um nome de dispositivo aqui permitirá que túneis sejam estabelecidos dos atSigns do usuário para este par atSign/nome de dispositivo.';

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
  String errorDuringStartupWithDetails(Object errorMessage) {
    return 'Erro durante a inicialização: $errorMessage';
  }

  @override
  String get errorOtpRequestFailed =>
      'Falha ao solicitar um OTP, tente reenviar ou entre em contato com o suporte se o problema persistir.';

  @override
  String get errorOtpVerificationFailed =>
      'Falha ao verificar o OTP com o servidor de ativação, tente novamente. Entre em contato com o suporte se o problema persistir.';

  @override
  String get errorProfileLoadFailed => 'Falha ao carregar este perfil:';

  @override
  String get errorRootDomainNotSupported =>
      'O domínio raiz especificado não é suportado pela ativação automática.';

  @override
  String get errorSwitchAtSignFailed =>
      'Falha ao trocar de atSigns após a ativação.';

  @override
  String errorWithDetails(Object errorMessage) {
    return 'Erro: $errorMessage,';
  }

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
  String get groupAdd => 'Adicionar Grupo';

  @override
  String get groupName => 'Nome do Grupo';

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
  String get jsonCopyToClipboard => 'Copiar JSON para a Área de Transferência';

  @override
  String get jsonPayloadCopiedToClipboard =>
      'Payload JSON copiado para a área de transferência';

  @override
  String get keys => 'Enviar atKeys';

  @override
  String get language => 'Idioma';

  @override
  String get loading => 'Carregando';

  @override
  String get localHost => 'Host Local';

  @override
  String get localHostDescription =>
      'O nome do host ou endereço IP para vincular à sua máquina local';

  @override
  String get localPort => 'Porta Local';

  @override
  String get localPortDescription =>
      'A porta que você usará em sua máquina local';

  @override
  String get logs => 'Logs';

  @override
  String get logsClear => 'Limpar Logs';

  @override
  String get logsNotAvailable =>
      'Nenhum log disponível ainda.\nA atividade aparecerá aqui quando as solicitações de política forem feitas.';

  @override
  String get logsNotAvailableStartMonitoring =>
      'Nenhum log disponível.\nInicie o monitoramento do Gerenciador de Políticas para ver a atividade.';

  @override
  String get logsView => 'Visualizar Logs';

  @override
  String get logType => 'Tipo de Log';

  @override
  String get manageAtsigns => 'Gerenciar atSigns';

  @override
  String get minimal => 'Simples';

  @override
  String get monitoringActive => 'Monitoramento Ativo';

  @override
  String get monitoringInactive => 'Monitoramento Inativo';

  @override
  String get monitoringStart => 'Iniciar Monitoramento';

  @override
  String get monitoringStop => 'Parar Monitoramento';

  @override
  String get name => 'Nome';

  @override
  String get next => 'Próximo';

  @override
  String get noAtsign => 'Sem atSign';

  @override
  String get noAtsignsAdded => 'Nenhum atSign adicionado ainda';

  @override
  String get noDescription => 'Sem descrição';

  @override
  String get noEmailClientAvailable => 'Nenhum cliente de email disponível';

  @override
  String get noName => 'Sem Nome';

  @override
  String get noPorts => 'NoPorts';

  @override
  String get nptStartupTimedout =>
      'Tempo limite de inicialização do Npt excedido';

  @override
  String get ok => 'OK';

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
  String get overrideAllProfile =>
      'Substituir todos os perfis com a seleção de relay padrão';

  @override
  String get pasteProfile => 'Colar Perfil';

  @override
  String get pasteProfileDescription => 'Cole o conteúdo JSON/YAML aqui';

  @override
  String permitOpens(Object permitOpens) {
    return 'Permitir Aberturas: $permitOpens';
  }

  @override
  String get permitOpensHostPort => 'Permitir Aberturas (host:porta)';

  @override
  String get permitOpensNotConfigured =>
      'Nenhuma abertura permitida configurada';

  @override
  String get policy => 'Política';

  @override
  String get policyLogs => 'Logs de Política';

  @override
  String get policyManager => 'Gerenciador de Políticas';

  @override
  String get policyRequestPayload => 'Payload da Solicitação de Política';

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
  String get profileKeepAlive => '🕺 Manter Ativo';

  @override
  String get profileKeepAliveDescription =>
      'Manter ativo. Se uma sessão terminar, crie uma nova sessão e religue à porta local. As sessões podem terminar devido a não serem usadas após um tempo limite ou por problemas de rede.';

  @override
  String get profileName => 'Nome do Perfil';

  @override
  String get profileNameDescription =>
      'Este será o nome de suas configurações.';

  @override
  String get profilePort443 => 'Usar Porta 443';

  @override
  String get profilePort443Description =>
      'Força o relay a usar a porta 443 em vez de uma porta efêmera. Habilita automaticamente o modo de autenticação ESCR do relay para segurança.';

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
  String get remoteHostDescription =>
      'O nome do host ou endereço IP do serviço ao qual você está se conectando na máquina remota';

  @override
  String get remotePort => 'Porta Remota';

  @override
  String get remotePortDescription =>
      'A porta que será usada na máquina remota';

  @override
  String get removeAtsign => 'Remover atSign';

  @override
  String get requestExpired =>
      'A solicitação original expirou. Por favor, envie novamente';

  @override
  String get required => 'Obrigatório';

  @override
  String get resendPin => 'Reenviar Pin';

  @override
  String retryFailedWithDetails(Object errorMessage) {
    return 'Falha ao tentar novamente: $errorMessage, tentará novamente...';
  }

  @override
  String get roleAddNew => 'Adicionar Nova Função';

  @override
  String get roleCreatingFailed => 'Falha ao criar a função';

  @override
  String roleCreatingFailedWithDetails(Object errorMessage) {
    return 'Falha ao criar a função: $errorMessage';
  }

  @override
  String get roleDelete => 'Excluir Função';

  @override
  String roleDeleteConfirmation(Object roleName) {
    return 'Tem certeza de que deseja excluir a função \"$roleName\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get roleDeletedSuccessfully => 'Função excluída com sucesso!';

  @override
  String get roleDeletingFailed => 'Falha ao excluir a função';

  @override
  String roleDeletingFailedWithDetails(Object errorMessage) {
    return 'Falha ao excluir a função: $errorMessage';
  }

  @override
  String roleLoadingFailedWithDetails(Object errorMessage) {
    return 'Falha ao carregar a função: $errorMessage';
  }

  @override
  String get roleNotFound => 'Nenhuma função encontrada';

  @override
  String get roleNotLoaded => 'Nenhuma função carregada';

  @override
  String get roles => 'Funções';

  @override
  String get roleSaveFailed => 'Falha ao salvar a função';

  @override
  String roleSaveFailedWithDetails(Object errorMessage) {
    return 'Falha ao salvar a função: $errorMessage';
  }

  @override
  String get roleSelectToViewDetails =>
      'Selecione uma função para ver os detalhes';

  @override
  String rolesLoadingFailedWithDetails(Object errorMessage) {
    return 'Falha ao carregar as funções: $errorMessage';
  }

  @override
  String get rolesRefresh => 'Atualizar Funções';

  @override
  String get roleUpdatingFailed => 'Falha ao atualizar a função';

  @override
  String roleUpdatingFailedWithDetails(Object errorMessage) {
    return 'Falha ao atualizar a função: $errorMessage';
  }

  @override
  String get rootDomainDefault => 'Padrão (Prod)';

  @override
  String get rootDomainDemo => 'Demonstração (VE)';

  @override
  String get save => 'Salvar';

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
  String get servicesAllowed => 'Serviços Permitidos';

  @override
  String get settings => 'Configurações';

  @override
  String get settingsCouldNotFetch =>
      'Não foi possível buscar as configurações';

  @override
  String get showWindow => 'Mostrar Janela';

  @override
  String get signout => 'Sair';

  @override
  String get socketconnectorClosedPrematurely =>
      'Socketconnector fechado prematuramente';

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
  String get syncCompleted =>
      'Sincronização concluída. Todos os perfis carregados.';

  @override
  String get syncInProgress =>
      'Sincronização em andamento. Alguns perfis ainda podem estar carregando.';

  @override
  String get timestamp => 'Timestamp';

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
  String get validationErrorHostField =>
      'O campo deve ser um nome de host parcial ou totalmente qualificado ou um endereço IP';

  @override
  String get validationErrorLocalPortField =>
      'O número deve estar entre 1024 e 65535';

  @override
  String get validationErrorLongField =>
      'O campo deve ter entre 1 e 36 caracteres';

  @override
  String get validationErrorRelayField => 'O relay deve ser um atSign válido';

  @override
  String get validationErrorRemotePortField =>
      'O número deve estar entre 1 e 65535';

  @override
  String get waitingForApproval => 'Aguardando aprovação...';

  @override
  String get whatAreAtKeys => 'O que são atKeys?';

  @override
  String get whereToAccept => 'Onde aceitar?';

  @override
  String get whereToAcceptDescription =>
      'Por favor, aprov a solicitação em um aplicativo com uma chave de gerenciador.';

  @override
  String get yaml => 'YAML';

  @override
  String get or => 'Ou';

  @override
  String get myNoPortsMsg => 'Recupere o seu em ';

  @override
  String get yamlRecommended => 'YAML (Recomendado)';
}
