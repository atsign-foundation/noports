// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get activationStatusActivating => 'Activando';

  @override
  String get activationStatusOtpWait =>
      'Por favor, ingresa el OTP de tu correo electrónico';

  @override
  String get activationStatusPreparing => 'Preparando para la activación';

  @override
  String get addNew => 'Agregar Nuevo';

  @override
  String get advanced => 'Avanzado';

  @override
  String get alertDialogTitle => '¿Estás seguro?';

  @override
  String get allRightsReserved =>
      '@ 2025 Atsign, Todos los derechos reservados';

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
  String get atsignDialogSubtitle => 'Por favor, selecciona tu atSign';

  @override
  String get atsignDialogTitle => 'AtSign';

  @override
  String get atsignUncreated => '¿No tienes un atSign?';

  @override
  String get authenticate => 'Autenticar';

  @override
  String get authorisation => 'Autorización';

  @override
  String get back => 'Atrás';

  @override
  String get backUpAtKeys => 'Respaldar atKeys';

  @override
  String get backUpAtKeysIntroMsgFirst =>
      'Es importante que resguardes tus atKeys para que puedas acceder a tus datos desde cualquier dispositivo.\n\nSi pierdes tus atKeys, perderás el acceso a tus datos.';

  @override
  String get backUpAtKeysIntroMsgLast =>
      '\n\nPuedes guardar copias de seguridad adicionales desde el menú de Configuración en cualquier momento.';

  @override
  String get backUpAtKeysMainMsg =>
      'Tus atKeys se utilizarán para vincular tu atSign con este y otros dispositivos en el futuro.\n\nLas atKeys son claves criptográficas que se utilizan para proteger tu atSign.\n\nSon únicas para ti y se utilizan para cifrar y descifrar tus datos.';

  @override
  String get backupKeyDialogTitle =>
      'Por favor, selecciona un archivo para exportar a:';

  @override
  String get backupYourKey => 'Respalda tu Clave';

  @override
  String get cancel => 'Cancelar';

  @override
  String get clientAtsignDescription =>
      'Un atSign es una dirección resoluble\nasignada a un dispositivo.';

  @override
  String get confirm => 'Confirmar';

  @override
  String get connected => 'Conectado';

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
  String get deviceAtsign => 'atSign del Dispositivo';

  @override
  String get deviceAtsignDescription =>
      'Este es el atSign asociado con tu dispositivo.';

  @override
  String get deviceName => 'Nombre del Dispositivo';

  @override
  String get deviceNameDescription =>
      'Este es el nombre de tu dispositivo remoto.';

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
      'No se encontraron perfiles\nCrea o importa un perfil para empezar a usar NoPorts.';

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
      'El archivo atKeys que subiste no coincide con el atSign solicitado';

  @override
  String get errorAtServerUnavailable =>
      'No se pudo recuperar el estado del atServer, asegúrate de tener una conexión a internet estable.';

  @override
  String get errorAtServerUnreachable =>
      'No se puede conectar al atServer, asegúrate de tener una conexión a internet estable.';

  @override
  String errorAtSignAlreadyPaired(Object atsign) {
    return 'El atSign $atsign ya está vinculado, por favor contacta con soporte.';
  }

  @override
  String get errorAtSignNotExist =>
      'El atSign que solicitaste no existe en este dominio raíz.';

  @override
  String get errorAtSignUnavailable =>
      'El atSign no está disponible. Asegúrate de haber presionado \"Activar\" desde tu panel y tener una conexión a internet estable.';

  @override
  String get errorAuthenticatinFailed => 'Autenticación fallida.';

  @override
  String get errorAuthenticationTimedOut => 'La autenticación ha expirado.';

  @override
  String get errorOtpRequestFailed =>
      'Error al solicitar un OTP, intenta reenviar o contacta a soporte si el problema persiste.';

  @override
  String get errorOtpVerificationFailed =>
      'Error al verificar el OTP con el servidor de activación, por favor intenta nuevamente. Contacta a soporte si el problema persiste.';

  @override
  String get errorProfileLoadFailed => 'Error al cargar este perfil:';

  @override
  String get errorRootDomainNotSupported =>
      'El dominio raíz especificado no es compatible con la activación automática.';

  @override
  String get errorSwitchAtSignFailed =>
      'Error al cambiar de atSign después de la activación.';

  @override
  String get europe => 'Europa';

  @override
  String get export => 'Exportar';

  @override
  String get exportLogs => 'Exportar Registros';

  @override
  String get faq => 'Preguntas Frecuentes';

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
      'La solicitud se mostrará en el Authenticator en Solicitudes en cualquier aplicación conectada a tu atSign con claves de administrador.';

  @override
  String get getStarted => 'Comenzar';

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
  String get keys => 'Subir atKeys';

  @override
  String get language => 'Idioma';

  @override
  String get loading => 'Cargando';

  @override
  String get localPort => 'Puerto Local';

  @override
  String get logs => 'Registros';

  @override
  String get minimal => 'Simple';

  @override
  String get myNoPortsMsg => 'Recupera el tuyo en ';

  @override
  String get next => 'Siguiente';

  @override
  String get noAtsign => 'Sin atSign';

  @override
  String get noEmailClientAvailable => 'No hay cliente de correo disponible';

  @override
  String get noName => 'Sin Nombre';

  @override
  String get noPorts => 'NoPorts';

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
  String get profileName => 'Nombre del Perfil';

  @override
  String get profileNameDescription =>
      'Este será el nombre de tus configuraciones.';

  @override
  String get profileRunningActionDeniedMessage =>
      'No se puede realizar esta acción mientras el perfil está en ejecución.';

  @override
  String get profileRunningCloseMsgStart =>
      'El/Los siguiente(s) perfil(es) está/n conectado(s):';

  @override
  String get profilesFailedLoaded => 'Error al cargar los perfiles';

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
  String get remotePort => 'Puerto Remoto';

  @override
  String get requestExpired =>
      'La solicitud original ha expirado. Por favor, vuelve a enviar.';

  @override
  String get required => 'Requerido';

  @override
  String get resendPin => 'Reenviar Pin';

  @override
  String get resetAtsign => 'Restablecer atSign';

  @override
  String get rootDomainDefault => 'Predeterminado (Prod)';

  @override
  String get rootDomainDemo => 'Demo (VE)';

  @override
  String get saveAtKeys => 'Guardar atKeys';

  @override
  String get saveLater => 'Guardar para Después';

  @override
  String get selectEnrollMethod => 'Selecciona tu método de inscripción';

  @override
  String get selectExportFile =>
      'Por favor, selecciona un archivo para exportar a:';

  @override
  String get selectKey => 'Seleccionar atKey';

  @override
  String get selectorSubTitleAtsign =>
      'Ingresa tu atSign de NoPorts a continuación.';

  @override
  String get selectorSubTitleRootDomain =>
      'Ingresa el dominio de atDirectory (anteriormente llamado dominio raíz).';

  @override
  String get selectorTitleAtsign => 'atSign de NoPorts';

  @override
  String get selectorTitleRootDomain => 'Dominio de atDirectory';

  @override
  String get serviceMapping => 'Mapeo de Servicios';

  @override
  String get settings => 'Configuraciones';

  @override
  String get showWindow => 'Mostrar Ventana';

  @override
  String get signout => 'Cerrar Sesión';

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
  String get switchAtSign => 'Cambiar atSign';

  @override
  String get switchAtSignDescription =>
      '¿Estás seguro de que quieres cambiar de atSign?';

  @override
  String get switchAtSignNote =>
      'Nota: Cambiar de atSign finaliza todas las conexiones.';

  @override
  String get syncCompleted =>
      'Sincronización completada. Todos los perfiles cargados.';

  @override
  String get syncInProgress =>
      'Sincronización en curso. Algunos perfiles podrían estar todavía cargando.';

  @override
  String get unknownError => 'Ocurrió un error desconocido';

  @override
  String get uploadKey => 'Subir atKey';

  @override
  String get uploadKeyDescription => 'Selecciona un archivo .atkey local';

  @override
  String get validationErrorAtsignField => 'El campo debe ser un atSign válido';

  @override
  String get validationErrorDeviceNameField =>
      'El campo solo puede contener letras minúsculas, dígitos, guiones bajos.';

  @override
  String get validationErrorEmptyField => 'Este campo no puede quedar vacío';

  @override
  String get validationErrorLocalPortField =>
      'El número debe estar entre 1024 y 65535';

  @override
  String get validationErrorLongField =>
      'El campo debe tener entre 1 y 36 caracteres';

  @override
  String get validationErrorRelayField => 'El relay debe ser un atSign válido';

  @override
  String get validationErrorRemoteHostField =>
      'El campo debe ser un nombre de host parcial o totalmente cualificado o una dirección IP';

  @override
  String get validationErrorRemotePortField =>
      'El número debe estar entre 1 y 65535';

  @override
  String get waitingForApproval => 'Esperando aprobación...';

  @override
  String get whatAreAtKeys => '¿Qué son las atKeys?';

  @override
  String get whatIsClientAtsign => '¿Qué es un atSign de NoPorts?';

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
