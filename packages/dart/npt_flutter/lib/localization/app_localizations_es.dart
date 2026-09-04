// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get activate => 'Activar';

  @override
  String get activating => 'Activando';

  @override
  String get activationAtsignFileStorageLocation =>
      'Selecciona una carpeta para guardar tus archivos .atKeys';

  @override
  String get activationAtsignListDescription =>
      'Los siguientes Atsigns serán activados:';

  @override
  String get activationButtonDescription =>
      'Completa la activación y configura un nuevo Atsign';

  @override
  String get activationComplete => 'Completar Activación';

  @override
  String get activationFileBased => 'Activación basada en archivo';

  @override
  String get activationFileBasedDescription =>
      'Por favor, sube tu archivo de activación (.yaml).\nEste archivo se descarga desde tu Portal de Gestión.';

  @override
  String get activationFileErrorMessage =>
      'Por favor, usa un archivo de activación válido.';

  @override
  String get activationFileLoadingMessage => 'Procesando Archivo...';

  @override
  String get activationFileSuccessMessage =>
      '¡Archivo de activación subido con éxito!';

  @override
  String get activationFileUploadDragDropDescription =>
      'Sube o arrastra y suelta tu archivo de activación de un solo uso (.yaml)';

  @override
  String get activationInProgress =>
      'Activando, por favor espera hasta que cada Atsign haya terminado.';

  @override
  String get activationKeyStatusActivated => 'Activado';

  @override
  String get activationKeyStatusActivating => 'Activando';

  @override
  String get activationKeyStatusAlreadyActivated => 'Ya Activado';

  @override
  String get activationKeyStatusFailed => 'Fallido';

  @override
  String get activationKeyStatusWaiting => 'Esperando';

  @override
  String get activationManual => 'Activación Manual';

  @override
  String get activationRetryFailed => 'Reintento fallido';

  @override
  String get activationStatus => 'Estado de Activación';

  @override
  String get activationStatusActivating => 'Activando';

  @override
  String activationStatusCount(Object current, Object total) {
    return '$current de $total Atsigns activados:';
  }

  @override
  String get activationStatusOtpWait =>
      'Por favor, ingresa el OTP de tu correo electrónico';

  @override
  String get activationStatusPreparing => 'Preparando para la activación';

  @override
  String get add => 'Agregar';

  @override
  String get addAtsign => 'Agregar Atsign';

  @override
  String get addNew => 'Agregar Nuevo';

  @override
  String get advanced => 'Avanzado';

  @override
  String get advancedSettings => 'Configuración Avanzada';

  @override
  String get alertDialogTitle => '¿Estás seguro?';

  @override
  String get allRightsReserved =>
      '© 2026 Atsign, Todos los derechos reservados';

  @override
  String get americas => 'Américas';

  @override
  String get approveInstructions =>
      'Por favor, aprueba la solicitud en la aplicación con claves de administrador';

  @override
  String get asiaPacific => 'Asia-Pacífico';

  @override
  String get atDirectory => 'AtDirectory';

  @override
  String get atDirectorySubtitle => 'Selecciona el dominio que deseas usar';

  @override
  String get atsignDialogSubtitle => 'Por favor, selecciona tu Atsign';

  @override
  String get atsignDialogTitle => 'Atsign';

  @override
  String get atsignFrom => 'Desde Atsign';

  @override
  String get atsignTo => 'A Atsign';

  @override
  String get atsignUncreated => '¿No tienes un Atsign?';

  @override
  String get atsignsUser => 'Atsign de Usuario';

  @override
  String get atsignsUserTooltip =>
      'Un Atsign como \"@alice\" que se conectará a otros dispositivos';

  @override
  String get authenticate => 'Autenticar';

  @override
  String get authenticator => 'Authenticator';

  @override
  String get authorisation => 'Autorización';

  @override
  String get autoStartApplication =>
      'Iniciar Aplicación del Cliente Automáticamente';

  @override
  String get back => 'Atrás';

  @override
  String get backUp => 'Respaldar';

  @override
  String get backUpAtKeys => 'Respaldar atKeys';

  @override
  String backUpAtKeysIntroMsgFirst(String saveOrBackup) {
    String _temp0 = intl.Intl.selectLogic(saveOrBackup, {
      'save': 'guardar',
      'other': 'respaldar',
    });
    return 'Es importante $_temp0 tus atKeys para que puedas acceder a tus datos desde cualquier dispositivo. \n\nSi pierdes tus atKeys, perderás el acceso a tus datos.';
  }

  @override
  String get backUpAtKeysIntroMsgLast =>
      '\n\nPuedes guardar copias de seguridad adicionales desde el menú de Configuración en cualquier momento.';

  @override
  String get backUpAtKeysMainMsg =>
      'Tus atKeys se utilizarán para vincular tu Atsign con este y otros dispositivos en el futuro.\n\nLas atKeys son claves criptográficas que se utilizan para proteger tu Atsign. \n\nSon únicas para ti y se utilizan para cifrar y descifrar tus datos.';

  @override
  String get backupKeyDialogTitle =>
      'Por favor, selecciona un archivo para exportar a:';

  @override
  String get backupYourKey => 'Respalda Tu Clave';

  @override
  String get cancel => 'Cancelar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get connectUriProtocolDescription =>
      'Esta configuración inicia automáticamente la aplicación apropiada después de establecerse una conexión, según el protocolo seleccionado. Si no se selecciona ningún protocolo, no se iniciará ninguna aplicación. Selecciona el protocolo a utilizar para la conexión.';

  @override
  String get connectUriProtocolNone => 'Ninguno';

  @override
  String get connectUriUsername => 'Nombre de Usuario';

  @override
  String get connectUriUsernameDescription =>
      'Nombre de usuario opcional para protocolos como SSH (por ejemplo, usuario en ssh://usuario@host)';

  @override
  String get connected => 'Conectado';

  @override
  String get connectionClosed => 'Conexión cerrada, se reintentará...';

  @override
  String get connectionRetrying =>
      'Reintentando la conexión (mantener activa)...';

  @override
  String get connectionTimedOut =>
      'Tiempo de espera de la conexión agotado, se reintentará...';

  @override
  String get connections => 'Conexiones';

  @override
  String get couldNotLoadPreviousState => 'Error al cargar el estado anterior';

  @override
  String get custom => 'Personalizado';

  @override
  String get dashboard => 'Panel';

  @override
  String get dashboardView => 'Vista del Panel';

  @override
  String get debugDumpLogTitle => 'Desarrollo: Volcar registros a la terminal';

  @override
  String get defaultRelaySelection => 'Selección de Relay Predeterminado';

  @override
  String get delete => 'Eliminar';

  @override
  String get demo => 'Demo';

  @override
  String get demoDescription =>
      'Haz clic aquí para cargar el perfil de prueba.';

  @override
  String get demoTextButton => 'Probar Ahora';

  @override
  String get description => 'Descripción';

  @override
  String get deviceAdd => 'Agregar Dispositivo';

  @override
  String get deviceAtsign => 'Atsign del Dispositivo';

  @override
  String get deviceAtsignDescription =>
      'Este es el Atsign asociado con tu dispositivo.';

  @override
  String get deviceAtsignDescriptionTwo =>
      'Un Atsign como \"@bob_device\", al que se conectará. Esto también se conoce como el demonio o máquina npd que está ejecutando el proceso de demonio que recibirá las solicitudes de conexión donde se establecerán las conexiones a este dispositivo.';

  @override
  String get deviceAtsigns => 'Atsign del Dispositivo';

  @override
  String get deviceEdit => 'Editar Dispositivo';

  @override
  String get deviceGroup => 'Grupo de Dispositivos';

  @override
  String get deviceGroupAdd => 'Agregar Grupo de Dispositivos';

  @override
  String get deviceGroupEdit => 'Editar Grupo de Dispositivos';

  @override
  String get deviceGroupNo => 'Ningún Grupo de Dispositivos';

  @override
  String get deviceGroupTooltip =>
      'Los procesos de demonio que especifican la opción --dg con una cadena permitirán conexiones desde el usuario a los host:puertos especificados';

  @override
  String get deviceGroups => 'Grupos de Dispositivos';

  @override
  String get deviceGroupsNotAdded =>
      'Aún no se han agregado grupos de dispositivos';

  @override
  String get deviceName => 'Nombre del Dispositivo';

  @override
  String get deviceNameDescription =>
      'Este es el nombre de tu dispositivo remoto.';

  @override
  String get devices => 'Dispositivos';

  @override
  String get devicesNotAdded => 'Aún no se han agregado dispositivos';

  @override
  String get devicesTooltip =>
      'Una cadena de nombre de dispositivo como \"default\" que está bajo un Atsign de dispositivo. Un Atsign de dispositivo puede tener múltiples nombres de dispositivo, los nombres de dispositivo ayudan a distinguir procesos de demonio de dispositivos individuales. Agregar un nombre de dispositivo aquí permitirá establecer túneles desde el Atsign del usuario a este par Atsign de dispositivo/nombre de dispositivo.';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get discord => 'Soporte de Discord';

  @override
  String get done => 'Listo';

  @override
  String get duplicate => 'Duplicar';

  @override
  String get edit => 'Editar';

  @override
  String get email => 'Soporte por Correo Electrónico';

  @override
  String get emptyProfileMessage =>
      'No se encontraron perfiles.\nCrea o importa un perfil para empezar a usar NoPorts.';

  @override
  String get enableLogging => 'Habilitar Registro';

  @override
  String get enroll => 'Inscribirse';

  @override
  String get enrollApproved => 'Solicitud de inscripción aprobada';

  @override
  String get enrollDenied => 'Solicitud de inscripción denegada';

  @override
  String get enrollRequestDenied => 'Solicitud de inscripción rechazada';

  @override
  String get enrollWithAuthenticator => 'Inscribirse con Authenticator';

  @override
  String get enrollWithAuthenticatorDescription =>
      'Autenticar a través de la aplicación con claves de administrador';

  @override
  String get enterOtp => 'Ingresar OTP';

  @override
  String get error => 'Error';

  @override
  String get errorActivationKeysConflict =>
      'Este Atsign fue integrado previamente con un conjunto diferente de claves. Elimínalo de la aplicación e intenta de nuevo.';

  @override
  String errorAtKeySaveFailed(Object error) {
    return 'Error al guardar el archivo atKeys: $error';
  }

  @override
  String get errorAtKeysFileProcessFailed =>
      'Error al procesar el archivo atKeys';

  @override
  String get errorAtKeysInvalid => 'Se detectó un archivo atKeys inválido';

  @override
  String get errorAtKeysUploadedMismatch =>
      'El archivo atKeys que subiste no coincide con el Atsign solicitado';

  @override
  String get errorAtServerUnavailable =>
      'No se pudo recuperar el estado del atServer, asegúrate de tener una conexión a internet estable.';

  @override
  String get errorAtServerUnreachable =>
      'No se puede conectar al atServer, asegúrate de tener una conexión a internet estable.';

  @override
  String get errorAtsignActivated => 'Este Atsign ya ha sido activado.';

  @override
  String errorAtsignAlreadyPaired(Object atsign) {
    return 'El Atsign $atsign ya está vinculado, por favor contacta con soporte.';
  }

  @override
  String get errorAtsignNotExist =>
      'El Atsign que solicitaste no existe en este dominio raíz.';

  @override
  String get errorAtsignUnavailable =>
      'El Atsign no está disponible. Asegúrate de haber presionado \"Activar\" desde tu panel y tener una conexión a internet estable.';

  @override
  String get errorAuthenticatinFailed => 'Autenticación fallida.';

  @override
  String get errorAuthenticationFailed =>
      'Autenticación fallida. Por favor, verifica tus datos e intenta de nuevo.';

  @override
  String get errorAuthenticationTimedOut => 'La autenticación ha expirado.';

  @override
  String get errorCramAuthFailed =>
      'La clave de activación fue rechazada por el atServer. Es posible que este archivo de activación ya se haya utilizado.';

  @override
  String errorDuringStartupWithDetails(Object errorMessage) {
    return 'Error durante el inicio: $errorMessage';
  }

  @override
  String get errorEnrollmentRevoked =>
      'Tu inscripción ha sido revocada. Por favor, inicia sesión nuevamente para solicitar una nueva inscripción.';

  @override
  String errorOnboardingWithDetails(Object details) {
    return 'La integración falló: $details';
  }

  @override
  String get errorOtpRequestFailed =>
      'Error al solicitar un OTP, intenta reenviar o contacta a soporte si el problema persiste.';

  @override
  String get errorOtpVerificationFailed =>
      'Error al verificar el OTP con el servidor de activación, por favor intenta nuevamente. Contacta a soporte si el problema persiste.';

  @override
  String get errorProfileLoadFailed => 'Error al cargar este perfil';

  @override
  String get errorRootDomainNotSupported =>
      'El dominio raíz especificado no es compatible con la activación automática.';

  @override
  String get errorServerUnavailable =>
      'El servidor no está disponible actualmente. Por favor, intenta de nuevo más tarde.';

  @override
  String get errorSwitchAtsignFailed =>
      'Error al cambiar de Atsign después de la activación.';

  @override
  String errorWithDetails(Object errorMessage) {
    return 'Error: $errorMessage,';
  }

  @override
  String get europe => 'Europa';

  @override
  String get export => 'Exportar';

  @override
  String get exportLogs => 'Exportar Registros';

  @override
  String get faq => 'Preguntas Frecuentes';

  @override
  String get fastest => 'Más rápido';

  @override
  String get feedback => 'Comentarios';

  @override
  String get fileFormatInvalid =>
      'El formato del documento es inválido. Por favor, sube un archivo válido.';

  @override
  String get fileFormatInvalidDetails =>
      'La sección de perfiles no se encuentra o tiene un formato incorrecto. Por favor, verifica el documento.';

  @override
  String get fileImported => 'Archivo Importado';

  @override
  String get fileSaved => 'Archivo Guardado';

  @override
  String get findOtp =>
      'La solicitud se mostrará en el Authenticator en Solicitudes en cualquier aplicación conectada a tu Atsign con claves de administrador.';

  @override
  String get getStarted => 'Comenzar';

  @override
  String get groupAdd => 'Agregar Grupo';

  @override
  String get groupAddConnection => 'Añadir conexión';

  @override
  String get groupByType => 'Agrupar por tipo';

  @override
  String get groupCollapse => 'Contraer';

  @override
  String get groupDeleteFolder => 'Eliminar carpeta';

  @override
  String get groupDeleteFolderMessage =>
      'Esta carpeta se eliminará. Las conexiones que contiene se conservarán.';

  @override
  String get groupExpand => 'Expandir';

  @override
  String get groupFolderName => 'Nombre de la carpeta';

  @override
  String get groupFolderNameRequired => 'Introduce un nombre de carpeta';

  @override
  String get groupLoadFailedRetry =>
      'No se pudieron cargar las carpetas. Reintentar';

  @override
  String get groupMoveTo => 'Mover a';

  @override
  String get groupMoveToFolder => 'Mover a carpeta';

  @override
  String get groupName => 'Nombre del Grupo';

  @override
  String get groupNewFolder => 'Nueva carpeta';

  @override
  String get groupNoFolder => 'Sin carpeta';

  @override
  String get groupRename => 'Renombrar';

  @override
  String get groupRenameFolder => 'Renombrar carpeta';

  @override
  String get groupStartAll => 'Iniciar todo';

  @override
  String get groupStopAll => 'Detener todo';

  @override
  String get groupTypeHttp => 'HTTP';

  @override
  String get groupTypeNone => 'Ninguno';

  @override
  String get groupTypeRdp => 'RDP';

  @override
  String get groupTypeSsh => 'SSH';

  @override
  String get groupTypeVnc => 'VNC';

  @override
  String get groupUngrouped => 'Sin agrupar';

  @override
  String get import => 'Importar';

  @override
  String get importFile => 'Importar Archivo';

  @override
  String get info => 'Información';

  @override
  String get invalidOtp => 'OTP inválido';

  @override
  String get json => 'JSON';

  @override
  String get jsonCopyToClipboard => 'Copiar JSON al Portapapeles';

  @override
  String get jsonPayloadCopiedToClipboard =>
      'Carga útil JSON copiada al portapapeles';

  @override
  String get keys => 'Subir atKeys';

  @override
  String get language => 'Idioma';

  @override
  String get loading => 'Cargando';

  @override
  String get localHost => 'Host Local';

  @override
  String get localHostDescription =>
      'El nombre de host o la dirección IP para enlazar a tu máquina local';

  @override
  String get localPort => 'Puerto Local';

  @override
  String get localPortDescription => 'El puerto que usarás en tu máquina local';

  @override
  String get logType => 'Tipo de Registro';

  @override
  String get logs => 'Registros';

  @override
  String get logsClear => 'Borrar Registros';

  @override
  String get logsNotAvailable =>
      'Aún no hay registros disponibles.\nLa actividad aparecerá aquí cuando se realicen solicitudes de políticas.';

  @override
  String get logsNotAvailableStartMonitoring =>
      'No hay registros disponibles.\nInicia el monitoreo desde el Administrador de Políticas para ver la actividad.';

  @override
  String get logsView => 'Ver Registros';

  @override
  String get manageAtsigns => 'Gestionar Atsign';

  @override
  String get minimal => 'Simple';

  @override
  String get monitoringActive => 'Monitoreo Activo';

  @override
  String get monitoringInactive => 'Monitoreo Inactivo';

  @override
  String get monitoringStart => 'Iniciar Monitoreo';

  @override
  String get monitoringStop => 'Detener Monitoreo';

  @override
  String get msgAtsignUnreachable =>
      'No se pudo contactar al servidor del Atsign.';

  @override
  String get msgResponseTimeOut =>
      'El tiempo de espera de la solicitud se agotó. Por favor, intenta de nuevo.';

  @override
  String get myNoPortsMsg => 'Recupera el tuyo en My NoPorts →';

  @override
  String get name => 'Nombre';

  @override
  String get next => 'Siguiente';

  @override
  String get noAtsign => 'Sin Atsign';

  @override
  String get noAtsignsAdded => 'Aún no se han agregado Atsigns';

  @override
  String get noAtsignsToRemove => 'No se encontraron Atsigns para eliminar.';

  @override
  String get noDescription => 'Sin descripción';

  @override
  String get noEmailClientAvailable => 'No hay cliente de correo disponible';

  @override
  String get noName => 'Sin Nombre';

  @override
  String get noPorts => 'NoPorts';

  @override
  String get nptStartupTimedout => 'Tiempo de espera de inicio de Npt agotado';

  @override
  String get ok => 'OK';

  @override
  String get onboard => 'Integrar';

  @override
  String get onboardingButtonStatusPicking =>
      'Esperando que se seleccione un archivo';

  @override
  String get onboardingButtonStatusProcessingFile => 'Procesando archivo';

  @override
  String get onboardingError => 'Ocurrió un error';

  @override
  String get onboardingSubTitle => 'a NoPorts Desktop';

  @override
  String get onboardingTitle => 'Bienvenido';

  @override
  String get or => 'O';

  @override
  String get overrideAllProfile =>
      'Anular todos los perfiles con la selección de relay predeterminada';

  @override
  String get pasteProfile => 'Pegar Perfil';

  @override
  String get pasteProfileDescription => 'Pega el contenido JSON/YAML aquí';

  @override
  String permitOpens(Object permitOpens) {
    return 'Permitir Aperturas: $permitOpens';
  }

  @override
  String get permitOpensHostPort => 'Permitir Aperturas (host:puerto)';

  @override
  String get permitOpensNotConfigured =>
      'No se han configurado aperturas permitidas';

  @override
  String get policy => 'Política';

  @override
  String get policyLogs => 'Registros de Políticas';

  @override
  String get policyManager => 'Administrador de Políticas';

  @override
  String get policyRequestPayload => 'Carga útil de la Solicitud de Política';

  @override
  String get preview => 'Previsualizar';

  @override
  String get privacyPolicy => 'Política de Privacidad';

  @override
  String get profile => 'Perfil';

  @override
  String get profileDeleteMessage =>
      'Este perfil será eliminado permanentemente.';

  @override
  String get profileDeleteSecondaryMessage =>
      'Algunos perfiles se están ejecutando y no se eliminarán, detén primero esos perfiles para eliminarlos.';

  @override
  String get profileDeleteSelectedMessage =>
      'Los perfiles seleccionados serán eliminados permanentemente.';

  @override
  String get profileExportDialogTitle => 'Elige el Tipo de Archivo';

  @override
  String get profileExportMessage =>
      '¿En qué tipo de archivo quieres exportar?';

  @override
  String get profileExportSelectedMessage =>
      '¿En qué tipo de archivo quieres exportar los perfiles seleccionados?';

  @override
  String get profileFailedLoaded => 'Error al cargar el perfil';

  @override
  String get profileFailedSaveMessage => 'Error al guardar el perfil';

  @override
  String get profileFailedUnknownMessage => 'No se proporcionó ninguna razón';

  @override
  String get profileImportDialogTitle => 'Elige el Método de Importación';

  @override
  String get profileImportFailed => 'Error al importar el archivo';

  @override
  String get profileImportSelectedMessage => '¿Cómo deseas importar un perfil?';

  @override
  String get profileKeepAlive => '🕺 Mantener Activo';

  @override
  String get profileKeepAliveDescription =>
      'Mantener activo. Si una sesión finaliza, crea una nueva sesión y vuelve a vincular al puerto local. Las sesiones pueden finalizar debido a que no se usan después de un tiempo de espera o por problemas de red.';

  @override
  String get profileName => 'Nombre del Perfil';

  @override
  String get profileNameDescription =>
      'Este será el nombre de tus configuraciones.';

  @override
  String get profilePort443 => 'Usar Puerto 443';

  @override
  String get profilePort443Description =>
      'Fuerza al relay a usar el puerto 443 en lugar de un puerto efímero. Habilita automáticamente el modo de autenticación ESCR del relay para mayor seguridad.';

  @override
  String get profileRunningActionDeniedMessage =>
      'No se puede realizar esta acción mientras el perfil está en ejecución.';

  @override
  String get profileRunningCloseMsgStart =>
      'Los siguientes perfiles están conectados:';

  @override
  String get profileStatusFailedLoad => 'Error al cargar';

  @override
  String get profileStatusFailedSave => 'Error al guardar';

  @override
  String get profileStatusFailedStart => 'Error al iniciar';

  @override
  String get profileStatusLoaded => 'Desconectado';

  @override
  String get profileStatusLoadedMessage => 'Actualmente Desconectado';

  @override
  String get profileStatusLoading => 'Cargando';

  @override
  String get profileStatusStarted => 'Conectado';

  @override
  String get profileStatusStartedMessage => 'Conexión exitosa';

  @override
  String get profileStatusStarting => 'Iniciando';

  @override
  String get profileStatusStopping => 'Apagando';

  @override
  String get profilesFailedLoaded => 'Error al cargar los perfiles';

  @override
  String get quit => 'Salir';

  @override
  String get refresh => 'Actualizar';

  @override
  String get register => 'Registrar';

  @override
  String get relay => 'Relay';

  @override
  String get relayDescription =>
      'Elige entre nuestros relays existentes o crea uno nuevo.';

  @override
  String get reload => 'Recargar';

  @override
  String get remoteHost => 'Host Remoto';

  @override
  String get remoteHostDescription =>
      'El nombre de host o la dirección IP del servicio al que te estás conectando en la máquina remota';

  @override
  String get remotePort => 'Puerto Remoto';

  @override
  String get remotePortDescription =>
      'El puerto que se usará en la máquina remota';

  @override
  String get removeAtsign => 'Eliminar Atsign';

  @override
  String get requestExpired =>
      'La solicitud original ha expirado. Por favor, vuelve a enviar';

  @override
  String get required => 'Requerido';

  @override
  String get resendPin => 'Reenviar Pin';

  @override
  String retryFailedWithDetails(Object errorMessage) {
    return 'El reintento falló: $errorMessage, se reintentará...';
  }

  @override
  String get roleAddNew => 'Agregar Nuevo Rol';

  @override
  String get roleCreatingFailed => 'Error al crear el rol';

  @override
  String roleCreatingFailedWithDetails(Object errorMessage) {
    return 'Error al crear el rol: $errorMessage';
  }

  @override
  String get roleDelete => 'Eliminar Rol';

  @override
  String roleDeleteConfirmation(Object roleName) {
    return '¿Estás seguro de que deseas eliminar el rol \"$roleName\"? Esta acción no se puede deshacer.';
  }

  @override
  String get roleDeletedSuccessfully => '¡Rol eliminado con éxito!';

  @override
  String get roleDeletingFailed => 'Error al eliminar el rol';

  @override
  String roleDeletingFailedWithDetails(Object errorMessage) {
    return 'Error al eliminar el rol: $errorMessage';
  }

  @override
  String roleLoadingFailedWithDetails(Object errorMessage) {
    return 'Error al cargar el rol: $errorMessage';
  }

  @override
  String get roleNotFound => 'No se encontraron roles';

  @override
  String get roleNotLoaded => 'No se cargó ningún rol';

  @override
  String get roleSaveFailed => 'Error al guardar el rol';

  @override
  String roleSaveFailedWithDetails(Object errorMessage) {
    return 'Error al guardar el rol: $errorMessage';
  }

  @override
  String get roleSelectToViewDetails =>
      'Selecciona un rol para ver los detalles';

  @override
  String get roleUpdatingFailed => 'Error al actualizar el rol';

  @override
  String roleUpdatingFailedWithDetails(Object errorMessage) {
    return 'Error al actualizar el rol: $errorMessage';
  }

  @override
  String get roles => 'Roles';

  @override
  String rolesLoadingFailedWithDetails(Object errorMessage) {
    return 'Error al cargar los roles: $errorMessage';
  }

  @override
  String get rolesRefresh => 'Refrescar Roles';

  @override
  String get rootDomainDefault => 'Predeterminado (Prod)';

  @override
  String get rootDomainDemo => 'Demo (VE)';

  @override
  String get save => 'Guardar';

  @override
  String get saveAtKeys => 'Guardar atKeys';

  @override
  String get saveLater => 'Guardar para Después';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get selectEnrollMethod => 'Selecciona tu método de inscripción';

  @override
  String get selectExportFile =>
      'Por favor, selecciona un archivo para exportar a:';

  @override
  String get selectKey => 'Seleccionar atKey';

  @override
  String get selectorSubTitleAtsign =>
      'Ingresa tu Atsign de NoPorts a continuación.';

  @override
  String get selectorSubTitleRootDomain => 'Ingresa el dominio de atDirectory.';

  @override
  String get selectorTitleAtsign => 'Atsign de NoPorts';

  @override
  String get selectorTitleRootDomain => 'Dominio de atDirectory';

  @override
  String get serviceMapping => 'Mapeo de Servicios';

  @override
  String get servicesAllowed => 'Servicios Permitidos';

  @override
  String get settings => 'Configuraciones';

  @override
  String get settingsCouldNotFetch =>
      'No se pudieron obtener las configuraciones';

  @override
  String get showWindow => 'Mostrar Ventana';

  @override
  String get signIn => 'Iniciar Sesión';

  @override
  String get signInButtonDescription => 'Inicia sesión con un Atsign activado';

  @override
  String get signout => 'Cerrar Sesión';

  @override
  String get socketconnectorClosedPrematurely =>
      'Socketconnector se cerró prematuramente';

  @override
  String get sshStyle => 'Avanzado';

  @override
  String get starting => 'Iniciando';

  @override
  String get status => 'Estado';

  @override
  String get stopping => 'Apagando';

  @override
  String get submit => 'Enviar';

  @override
  String get submitOtp => 'Enviar OTP';

  @override
  String get success => 'Éxito';

  @override
  String get switchAtsign => 'Cambiar Atsign';

  @override
  String get switchAtsignDescription =>
      '¿Estás seguro de que deseas cambiar de Atsign?';

  @override
  String get switchAtsignNote =>
      'Nota: Cambiar de Atsign finaliza todas las conexiones.';

  @override
  String get syncCompleted =>
      'Sincronización completada. Todos los perfiles cargados.';

  @override
  String get syncInProgress =>
      'Sincronización en curso. Algunos perfiles podrían estar todavía cargando.';

  @override
  String get timestamp => 'Marca de Tiempo';

  @override
  String get unknownError => 'Ocurrió un error desconocido';

  @override
  String get uploadKey => 'Subir atKey';

  @override
  String get uploadKeyDescription => 'Selecciona un archivo .atkey local';

  @override
  String get validationErrorAtsignField => 'El campo debe ser un Atsign válido';

  @override
  String get validationErrorDeviceNameField =>
      'El campo solo puede contener letras minúsculas, dígitos, guiones bajos.';

  @override
  String get validationErrorEmptyField => 'Este campo no puede quedar vacío';

  @override
  String get validationErrorHostField =>
      'El campo debe ser un nombre de host parcial o totalmente cualificado o una dirección IP';

  @override
  String get validationErrorLocalPortField =>
      'El número debe estar entre 1024 y 65535';

  @override
  String get validationErrorLongField =>
      'El campo debe tener entre 1 y 36 caracteres';

  @override
  String get validationErrorRelayField => 'El relay debe ser un Atsign válido';

  @override
  String get validationErrorRemotePortField =>
      'El número debe estar entre 1 y 65535';

  @override
  String get waitingForApproval => 'Esperando aprobación...';

  @override
  String get whatAreAtKeys => '¿Qué son las atKeys?';

  @override
  String get whatIsAnAtsign => '¿Qué es un Atsign?';

  @override
  String get whatIsAnAtsignDescription =>
      'Un Atsign es tanto una dirección como un identificador único para tu dispositivo.';

  @override
  String get whereToAccept => '¿Dónde aceptar?';

  @override
  String get whereToAcceptDescription =>
      'Por favor, aprueba la solicitud en una aplicación con una clave de administrador.';

  @override
  String get yaml => 'YAML';

  @override
  String get yamlRecommended => 'YAML (Recomendado)';
}
