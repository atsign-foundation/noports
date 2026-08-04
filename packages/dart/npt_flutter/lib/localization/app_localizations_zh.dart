// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get activate => '激活';

  @override
  String get activating => '正在激活';

  @override
  String get activationAtsignFileStorageLocation => '选择一个文件夹来保存您的 .atKeys 文件';

  @override
  String get activationAtsignListDescription => '以下 Atsign 将被激活：';

  @override
  String get activationButtonDescription => '完成激活并设置新的 Atsign';

  @override
  String get activationComplete => '完成激活';

  @override
  String get activationFileBased => '基于文件的激活';

  @override
  String get activationFileBasedDescription =>
      '请上传您的激活文件 (.yaml)。\n此文件可从您的管理门户下载。';

  @override
  String get activationFileErrorMessage => '请使用有效的激活文件。';

  @override
  String get activationFileLoadingMessage => '正在处理文件...';

  @override
  String get activationFileSuccessMessage => '激活文件上传成功！';

  @override
  String get activationFileUploadDragDropDescription =>
      '上传或拖放您的一次性激活文件 (.yaml)';

  @override
  String get activationKeyStatusActivated => '已激活';

  @override
  String get activationKeyStatusActivating => '正在激活';

  @override
  String get activationKeyStatusAlreadyActivated => '已激活';

  @override
  String get activationKeyStatusFailed => '失败';

  @override
  String get activationKeyStatusWaiting => '等待中';

  @override
  String get activationManual => '手动激活';

  @override
  String get activationStatus => '激活状态';

  @override
  String get activationStatusActivating => '正在激活';

  @override
  String activationStatusCount(Object current, Object total) {
    return '已激活 $total 个中的 $current 个 Atsign：';
  }

  @override
  String get activationStatusOtpWait => '请从您的电子邮件中输入 OTP';

  @override
  String get activationStatusPreparing => '准备激活';

  @override
  String get add => '添加';

  @override
  String get addAtsign => '添加 Atsign';

  @override
  String get addNew => '添加新项';

  @override
  String get advanced => '高级';

  @override
  String get advancedSettings => '高级设置';

  @override
  String get alertDialogTitle => '你确定吗？';

  @override
  String get allRightsReserved => '© 2026 Atsign, 版权所有';

  @override
  String get americas => '美洲';

  @override
  String get approveInstructions => '请使用管理员密钥在应用中批准请求';

  @override
  String get asiaPacific => '亚太地区';

  @override
  String get atDirectory => 'AtDirectory';

  @override
  String get atDirectorySubtitle => '选择您想要使用的域';

  @override
  String get atsignDialogSubtitle => '请选择您的 Atsign';

  @override
  String get atsignDialogTitle => 'Atsign';

  @override
  String get atsignFrom => '来自 Atsign';

  @override
  String get atsignsUser => '用户 Atsign';

  @override
  String get atsignsUserTooltip => '一个 Atsign，如“@alice”，它将连接到其他设备';

  @override
  String get atsignTo => '到 Atsign';

  @override
  String get atsignUncreated => '没有 Atsign？';

  @override
  String get authenticate => '身份验证';

  @override
  String get authenticator => 'Authenticator';

  @override
  String get authorization => '授权';

  @override
  String get autoStartApplication => '自动启动客户端应用程序';

  @override
  String get back => '返回';

  @override
  String get backUp => '备份';

  @override
  String get backUpAtKeys => '备份 atKeys';

  @override
  String backUpAtKeysIntroMsgFirst(String saveOrBackup) {
    String _temp0 = intl.Intl.selectLogic(saveOrBackup, {
      'save': '保存',
      'other': '备份',
    });
    return '$_temp0您的 atKeys 非常重要，这样您就可以从任何设备访问您的数据。\n\n如果您丢失了 atKeys，您将失去对您的数据的访问权限。';
  }

  @override
  String get backUpAtKeysIntroMsgLast => '\n\n您可以随时从“设置”菜单保存其他备份。';

  @override
  String get backUpAtKeysMainMsg =>
      '您的 atKeys 将在未来用于将您的 Atsign 与此设备和其他设备配对。\n\natKeys 是用于保护您的 Atsign 的加密密钥。\n\n它们是您独有的，用于加密和解密您的数据。';

  @override
  String get backupKeyDialogTitle => '请选择要导出到的文件：';

  @override
  String get backupYourKey => '备份您的密钥';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get connected => '已连接';

  @override
  String get connectionClosed => '连接已关闭，将重试...';

  @override
  String get connectionRetrying => '正在重试连接 (keep-alive)...';

  @override
  String get connections => '连接';

  @override
  String get connectionTimedOut => '连接超时，将重试...';

  @override
  String get connectUriProtocolDescription =>
      '此设置会在建立连接后，根据所选协议自动启动相应的应用程序。如果未选择协议，则不会启动任何应用程序。选择用于连接的协议。';

  @override
  String get connectUriProtocolNone => '无';

  @override
  String get connectUriUsername => '用户名';

  @override
  String get connectUriUsernameDescription =>
      '协议（如 SSH）的可选用户名（例如，ssh://user@host 中的 user）';

  @override
  String get couldNotLoadPreviousState => '无法加载先前的状态错误';

  @override
  String get custom => '自定义';

  @override
  String get dashboard => '仪表板';

  @override
  String get dashboardView => '仪表板视图';

  @override
  String get debugDumpLogTitle => '开发：将日志转储到终端';

  @override
  String get defaultRelaySelection => '默认 Relay 选择';

  @override
  String get delete => '删除';

  @override
  String get demo => '演示';

  @override
  String get demoDescription => '点击此处加载测试配置文件。';

  @override
  String get demoTextButton => '立即体验';

  @override
  String get description => '描述';

  @override
  String get deviceAdd => '添加设备';

  @override
  String get deviceAtsign => '设备 Atsign';

  @override
  String get deviceAtsignDescription => '这是与您的设备关联的 Atsign。';

  @override
  String get deviceAtsignDescriptionTwo =>
      '一个 Atsign，如“@bob_device”，将被连接到。 这也称为正在运行守护程序进程的守护程序或 npd 机器，连接请求将发送到该守护程序进程，连接将建立到此设备。';

  @override
  String get deviceAtsigns => '设备 Atsign';

  @override
  String get deviceEdit => '编辑设备';

  @override
  String get deviceGroup => '设备组';

  @override
  String get deviceGroupAdd => '添加设备组';

  @override
  String get deviceGroupEdit => '编辑设备组';

  @override
  String get deviceGroupNo => '无设备组';

  @override
  String get deviceGroups => '设备组';

  @override
  String get deviceGroupsNotAdded => '尚未添加设备组';

  @override
  String get deviceGroupTooltip => '指定 --dg 选项的守护程序进程，并使用字符串将允许从用户连接到指定的主机：端口';

  @override
  String get deviceName => '设备名称';

  @override
  String get deviceNameDescription => '这是您的远程设备的名称。';

  @override
  String get devices => '设备';

  @override
  String get devicesNotAdded => '尚未添加设备';

  @override
  String get devicesTooltip =>
      '设备 Atsign 下的设备名称字符串，如“默认”。一个设备 Atsign 可以有多个设备名称，设备名称有助于区分各个设备守护程序进程。 在此处添加设备名称将允许从用户 Atsign 到此设备 Atsign/设备名称对建立隧道。';

  @override
  String get disconnected => '已断开连接';

  @override
  String get discord => 'Discord 支持';

  @override
  String get done => '完成';

  @override
  String get duplicate => '复制';

  @override
  String get edit => '编辑';

  @override
  String get email => '电子邮件支持';

  @override
  String get emptyProfileMessage => '未找到配置文件。\n创建或导入配置文件以开始使用 NoPorts。';

  @override
  String get enableLogging => '启用日志记录';

  @override
  String get enroll => '注册';

  @override
  String get enrollApproved => '注册请求已获批准';

  @override
  String get enrollDenied => '注册请求被拒绝';

  @override
  String get enrollRequestDenied => '注册请求被拒绝';

  @override
  String get enrollWithAuthenticator => '使用 Authenticator 注册';

  @override
  String get enrollWithAuthenticatorDescription => '通过具有管理员密钥的应用进行身份验证';

  @override
  String get enterOtp => '输入 OTP';

  @override
  String get error => '错误';

  @override
  String errorAtKeySaveFailed(Object error) {
    return '保存 atKeys 文件失败：$error';
  }

  @override
  String get errorAtKeysFileProcessFailed => '处理 atKeys 文件失败';

  @override
  String get errorAtKeysInvalid => '检测到无效的 atKeys 文件';

  @override
  String get errorAtKeysUploadedMismatch => '您上传的 atKeys 文件与请求的 Atsign 不匹配';

  @override
  String get errorAtServerUnavailable => '无法检索 atserver 状态，请确保您有稳定的互联网连接。';

  @override
  String get errorAtServerUnreachable => '无法连接到 atServer，请确保您有稳定的互联网连接。';

  @override
  String get errorAtsignAlreadyActivated =>
      'The Atsign has already been activated.';

  @override
  String errorAtsignAlreadyPaired(Object atsign) {
    return 'Atsign $atsign 已配对，请联系支持人员。';
  }

  @override
  String get errorAtsignNotExist => '您请求的 Atsign 在此根域中不存在。';

  @override
  String get errorAtsignUnavailable =>
      'Atsign 不可用。请确保您已从仪表板按下“激活”并且具有稳定的互联网连接。';

  @override
  String get errorAuthenticatinFailed => '身份验证失败。';

  @override
  String get errorAuthenticationTimedOut => '身份验证超时。';

  @override
  String errorDuringStartupWithDetails(Object errorMessage) {
    return '启动期间出错：$errorMessage';
  }

  @override
  String get errorOtpRequestFailed => '请求 OTP 失败，请尝试重新发送，如果问题仍然存在，请联系支持人员。';

  @override
  String get errorOtpVerificationFailed =>
      '使用激活服务器验证 OTP 失败，请重试。如果问题仍然存在，请联系支持人员。';

  @override
  String get errorProfileLoadFailed => '加载此配置文件失败';

  @override
  String get errorRootDomainNotSupported => '自动激活不支持指定的根域。';

  @override
  String get errorSwitchAtsignFailed => '激活后切换 Atsign 失败。';

  @override
  String errorWithDetails(Object errorMessage) {
    return '错误：$errorMessage,';
  }

  @override
  String get europe => '欧洲';

  @override
  String get export => '导出';

  @override
  String get exportLogs => '导出日志';

  @override
  String get faq => '常见问题';

  @override
  String get fastest => '最快';

  @override
  String get feedback => '反馈';

  @override
  String get fileFormatInvalid => '文档格式无效。请上传有效文件。';

  @override
  String get fileFormatInvalidDetails => '缺少配置文件部分或格式不正确。请检查文档。';

  @override
  String get fileImported => '文件已导入';

  @override
  String get fileSaved => '文件已保存';

  @override
  String get findOtp =>
      '请求将在 Authenticator 的“请求”中显示在任何通过管理员密钥连接到您的 Atsign 的应用中。';

  @override
  String get getStarted => '开始使用';

  @override
  String get groupAdd => '添加组';

  @override
  String get groupName => '组名';

  @override
  String get import => '导入';

  @override
  String get importFile => '导入文件';

  @override
  String get info => '信息';

  @override
  String get invalidOtp => '无效 OTP';

  @override
  String get json => 'JSON';

  @override
  String get jsonCopyToClipboard => '将 JSON 复制到剪贴板';

  @override
  String get jsonPayloadCopiedToClipboard => 'JSON 负载已复制到剪贴板';

  @override
  String get keys => '上传 atKeys';

  @override
  String get language => '语言';

  @override
  String get loading => '加载中';

  @override
  String get localHost => '本地主机';

  @override
  String get localHostDescription => '要绑定到本地机器的hostname或IP地址';

  @override
  String get localPort => '本地端口';

  @override
  String get localPortDescription => '您将在本地机器上使用的端口';

  @override
  String get logs => '日志';

  @override
  String get logsClear => '清除日志';

  @override
  String get logsNotAvailable => '尚无可用日志。\n当发出策略请求时，活动将显示在此处。';

  @override
  String get logsNotAvailableStartMonitoring => '没有可用的日志。\n从策略管理器启动监控以查看活动。';

  @override
  String get logsView => '查看日志';

  @override
  String get logType => '日志类型';

  @override
  String get manageAtsigns => '管理 Atsign';

  @override
  String get minimal => '简单';

  @override
  String get monitoringActive => '监控活动';

  @override
  String get monitoringInactive => '监控不活动';

  @override
  String get monitoringStart => '开始监控';

  @override
  String get monitoringStop => '停止监控';

  @override
  String get myNoPortsMsg => '在 My NoPorts 中检索您的 Atsign →';

  @override
  String get name => '名称';

  @override
  String get next => '下一步';

  @override
  String get noAtsign => '无 Atsign';

  @override
  String get noAtsignsAdded => '尚未添加 Atsign';

  @override
  String get noDescription => '无描述';

  @override
  String get noEmailClientAvailable => '没有可用的电子邮件客户端';

  @override
  String get noName => '无名称';

  @override
  String get noPorts => 'NoPorts';

  @override
  String get nptStartupTimedout => 'Npt 启动超时';

  @override
  String get ok => '确定';

  @override
  String get onboard => '引导';

  @override
  String get onboardingButtonStatusPicking => '等待选择文件';

  @override
  String get onboardingButtonStatusProcessingFile => '正在处理文件';

  @override
  String get onboardingError => '发生错误';

  @override
  String get onboardingSubTitle => '到 NoPorts 桌面';

  @override
  String get onboardingTitle => '欢迎';

  @override
  String get or => '或';

  @override
  String get overrideAllProfile => '使用默认 Relay 选择覆盖所有配置文件';

  @override
  String get pasteProfile => '粘贴配置文件';

  @override
  String get pasteProfileDescription => '在此处粘贴 JSON/YAML 内容';

  @override
  String permitOpens(Object permitOpens) {
    return '允许打开：$permitOpens';
  }

  @override
  String get permitOpensHostPort => '允许打开 (host:port)';

  @override
  String get permitOpensNotConfigured => '未配置允许打开';

  @override
  String get policy => '策略';

  @override
  String get policyLogs => '策略日志';

  @override
  String get policyManager => '策略管理器';

  @override
  String get policyRequestPayload => '策略请求负载';

  @override
  String get preview => '预览';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get profile => '配置文件';

  @override
  String get profileDeleteMessage => '此配置文件将被永久删除。';

  @override
  String get profileDeleteSecondaryMessage =>
      '某些配置文件正在运行，不会被删除，请先停止这些配置文件再进行删除。';

  @override
  String get profileDeleteSelectedMessage => '选定的配置文件将被永久删除。';

  @override
  String get profileExportDialogTitle => '选择文件类型';

  @override
  String get profileExportMessage => '您想导出为哪种文件类型？';

  @override
  String get profileExportSelectedMessage => '您想将选定的配置文件导出为哪种文件类型？';

  @override
  String get profileFailedLoaded => '配置文件加载失败';

  @override
  String get profileFailedSaveMessage => '配置文件保存失败';

  @override
  String get profileFailedUnknownMessage => '未提供原因';

  @override
  String get profileImportDialogTitle => '选择导入方式';

  @override
  String get profileImportFailed => '导入文件失败';

  @override
  String get profileImportSelectedMessage => '您想如何导入配置文件？';

  @override
  String get profileKeepAlive => '🕺 保持活动';

  @override
  String get profileKeepAliveDescription =>
      '保持活动。如果会话结束，则创建一个新的会话并重新绑定到本地端口。会话可能会因超时或网络问题而未被使用而结束。';

  @override
  String get profileName => '配置文件名称';

  @override
  String get profileNameDescription => '这将是您的配置的名称。';

  @override
  String get profilePort443 => '使用端口 443';

  @override
  String get profilePort443Description =>
      '强制中继使用端口 443 而不是临时端口。 自动启用 ESCR 中继身份验证模式以提高安全性。';

  @override
  String get profileRunningActionDeniedMessage => '配置文件运行时无法执行此操作。';

  @override
  String get profileRunningCloseMsgStart => '以下配置文件已连接：';

  @override
  String get profilesFailedLoaded => '配置文件加载失败';

  @override
  String get profileStatusFailedLoad => '加载失败';

  @override
  String get profileStatusFailedSave => '保存失败';

  @override
  String get profileStatusFailedStart => '启动失败';

  @override
  String get profileStatusLoaded => '已断开连接';

  @override
  String get profileStatusLoadedMessage => '当前已断开连接';

  @override
  String get profileStatusLoading => '正在加载';

  @override
  String get profileStatusStarted => '已连接';

  @override
  String get profileStatusStartedMessage => '连接成功';

  @override
  String get profileStatusStarting => '正在启动';

  @override
  String get profileStatusStopping => '正在关闭';

  @override
  String get quit => '退出';

  @override
  String get refresh => '刷新';

  @override
  String get register => '注册';

  @override
  String get relay => 'Relay';

  @override
  String get relayDescription => '从我们现有的 Relay 中选择或创建一个新的。';

  @override
  String get reload => '重新加载';

  @override
  String get remoteHost => '远程主机';

  @override
  String get remoteHostDescription => '您在远程机器上连接到的服务的hostname或IP地址';

  @override
  String get remotePort => '远程端口';

  @override
  String get remotePortDescription => '将在远程机器上使用的端口';

  @override
  String get removeAtsign => '删除 Atsign';

  @override
  String removeAtsignConfirmation(String atsign) {
    return 'Are you sure you want to remove $atsign from this device? You will need your atKeys file to sign in again.';
  }

  @override
  String get requestExpired => '原始请求已过期。请再次提交';

  @override
  String get required => '必填';

  @override
  String get resendPin => '重新发送 Pin';

  @override
  String retryFailedWithDetails(Object errorMessage) {
    return '重试失败：$errorMessage，将重试...';
  }

  @override
  String get roleAddNew => '添加新角色';

  @override
  String get roleCreatingFailed => '创建角色失败';

  @override
  String roleCreatingFailedWithDetails(Object errorMessage) {
    return '创建角色失败：$errorMessage';
  }

  @override
  String get roleDelete => '删除角色';

  @override
  String roleDeleteConfirmation(Object roleName) {
    return '您确定要删除角色“$roleName”吗？此操作无法撤消。';
  }

  @override
  String get roleDeletedSuccessfully => '角色删除成功！';

  @override
  String get roleDeletingFailed => '删除角色失败';

  @override
  String roleDeletingFailedWithDetails(Object errorMessage) {
    return '删除角色失败：$errorMessage';
  }

  @override
  String roleLoadingFailedWithDetails(Object errorMessage) {
    return '加载角色失败：$errorMessage';
  }

  @override
  String get roleNotFound => '未找到角色';

  @override
  String get roleNotLoaded => '未加载角色';

  @override
  String get roles => '角色';

  @override
  String get roleSaveFailed => '保存角色失败';

  @override
  String roleSaveFailedWithDetails(Object errorMessage) {
    return '保存角色失败：$errorMessage';
  }

  @override
  String get roleSelectToViewDetails => '选择角色以查看详细信息';

  @override
  String rolesLoadingFailedWithDetails(Object errorMessage) {
    return '加载角色失败：$errorMessage';
  }

  @override
  String get rolesRefresh => '刷新角色';

  @override
  String get roleUpdatingFailed => '更新角色失败';

  @override
  String roleUpdatingFailedWithDetails(Object errorMessage) {
    return '更新角色失败：$errorMessage';
  }

  @override
  String get rootDomainDefault => '默认 (Prod)';

  @override
  String get rootDomainDemo => '演示 (VE)';

  @override
  String get save => '保存';

  @override
  String get saveAtKeys => '保存 atKeys';

  @override
  String get saveLater => '稍后保存';

  @override
  String get selectEnrollMethod => '选择您的注册方法';

  @override
  String get selectExportFile => '请选择要导出到的文件：';

  @override
  String get selectKey => '选择 atKey';

  @override
  String get selectorSubTitleAtsign => '在下方输入您的 NoPorts Atsign。';

  @override
  String get selectorSubTitleRootDomain => '输入 atDirectory 域。';

  @override
  String get selectorTitleAtsign => 'NoPorts Atsign';

  @override
  String get selectorTitleRootDomain => 'atDirectory 域';

  @override
  String get serviceMapping => '服务映射';

  @override
  String get servicesAllowed => '允许的服务';

  @override
  String get settings => '设置';

  @override
  String get settingsCouldNotFetch => '无法获取设置';

  @override
  String get showWindow => '显示窗口';

  @override
  String get signIn => '登录';

  @override
  String get signInButtonDescription => '使用已激活的 Atsign 登录';

  @override
  String get signout => '退出';

  @override
  String get socketconnectorClosedPrematurely => 'Socketconnector 提前关闭';

  @override
  String get sshStyle => '高级';

  @override
  String get starting => '正在启动';

  @override
  String get status => '状态';

  @override
  String get stopping => '正在关闭';

  @override
  String get submit => '提交';

  @override
  String get submitOtp => '提交 OTP';

  @override
  String get success => '成功';

  @override
  String get switchAtsign => '切换 Atsign';

  @override
  String get switchAtsignDescription => '您确定要切换 Atsign 吗？';

  @override
  String get switchAtsignNote => '注意：切换 Atsign 会结束所有连接。';

  @override
  String get syncCompleted => '同步完成。所有配置文件已加载。';

  @override
  String get syncInProgress => '同步进行中。某些配置文件可能仍在加载。';

  @override
  String get timestamp => '时间戳';

  @override
  String get unknownError => '发生了未知错误';

  @override
  String get uploadKey => '上传 atKey';

  @override
  String get uploadKeyDescription => '选择本地 .atkey 文件';

  @override
  String get validationErrorAtsignField => '字段必须是有效的 atsign';

  @override
  String get validationErrorDeviceNameField => '字段只能包含小写字母、数字和下划线。';

  @override
  String get validationErrorEmptyField => '此字段不能为空';

  @override
  String get validationErrorHostField => '字段必须是部分或完全限定的主机名或 IP 地址';

  @override
  String get validationErrorLocalPortField => '数字必须介于 1024 和 65535 之间';

  @override
  String get validationErrorLongField => '字段长度必须为 1-36 个字符';

  @override
  String get validationErrorRelayField => 'Relay 必须是有效的 atsign';

  @override
  String get validationErrorRemotePortField => '数字必须介于 1 和 65535 之间';

  @override
  String get waitingForApproval => '等待批准...';

  @override
  String get whatAreAtKeys => '什么是 atKeys？';

  @override
  String get whatIsAnAtsign => '什么是 Atsign？';

  @override
  String get whatIsAnAtsignDescription => 'Atsign 既是地址，也是您设备的唯一标识符。';

  @override
  String get whereToAccept => '在哪里接受？';

  @override
  String get whereToAcceptDescription => '请在具有管理密钥的应用中批准该请求。';

  @override
  String get yaml => 'YAML';

  @override
  String get yamlRecommended => 'YAML (推荐)';
}

/// The translations for Chinese, as used in Switzerland, using the Han script (`zh_Hans_CH`).
class AppLocalizationsZhHansCh extends AppLocalizationsZh {
  AppLocalizationsZhHansCh() : super('zh_Hans_CH');

  @override
  String get activate => '激活';

  @override
  String get activating => '正在激活';

  @override
  String get activationAtsignFileStorageLocation => '选择一个文件夹来保存您的 .atKeys 文件';

  @override
  String get activationAtsignListDescription => '以下 Atsign 将被激活：';

  @override
  String get activationButtonDescription => '完成激活并设置新的 Atsign';

  @override
  String get activationComplete => '完成激活';

  @override
  String get activationFileBased => '基于文件的激活';

  @override
  String get activationFileBasedDescription =>
      '请上传您的激活文件 (.yaml)。\n此文件可从您的管理门户下载。';

  @override
  String get activationFileErrorMessage => '请使用有效的激活文件。';

  @override
  String get activationFileLoadingMessage => '正在处理文件...';

  @override
  String get activationFileSuccessMessage => '激活文件上传成功！';

  @override
  String get activationFileUploadDragDropDescription =>
      '上传或拖放您的一次性激活文件 (.yaml)';

  @override
  String get activationKeyStatusActivated => '已激活';

  @override
  String get activationKeyStatusActivating => '正在激活';

  @override
  String get activationKeyStatusAlreadyActivated => '已激活';

  @override
  String get activationKeyStatusFailed => '失败';

  @override
  String get activationKeyStatusWaiting => '等待中';

  @override
  String get activationManual => '手动激活';

  @override
  String get activationStatus => '激活状态';

  @override
  String get activationStatusActivating => '正在激活';

  @override
  String activationStatusCount(Object current, Object total) {
    return '已激活 $total 个中的 $current 个 Atsign：';
  }

  @override
  String get activationStatusOtpWait => '请从您的电子邮件中输入 OTP';

  @override
  String get activationStatusPreparing => '准备激活';

  @override
  String get add => '添加';

  @override
  String get addAtsign => '添加 Atsign';

  @override
  String get addNew => '添加新项';

  @override
  String get advanced => '高级';

  @override
  String get advancedSettings => '高级设置';

  @override
  String get alertDialogTitle => '你确定吗？';

  @override
  String get allRightsReserved => '© 2026 Atsign, 版权所有';

  @override
  String get americas => '美洲';

  @override
  String get approveInstructions => '请使用管理员密钥在应用中批准请求';

  @override
  String get asiaPacific => '亚太地区';

  @override
  String get atDirectory => 'AtDirectory';

  @override
  String get atDirectorySubtitle => '选择您想要使用的域';

  @override
  String get atsignDialogSubtitle => '请选择您的 Atsign';

  @override
  String get atsignDialogTitle => 'Atsign';

  @override
  String get atsignFrom => '来自 Atsign';

  @override
  String get atsignsUser => '用户 Atsign';

  @override
  String get atsignsUserTooltip => '一个 Atsign，如“@alice”，它将连接到其他设备';

  @override
  String get atsignTo => '到 Atsign';

  @override
  String get atsignUncreated => '没有 Atsign？';

  @override
  String get authenticate => '身份验证';

  @override
  String get authenticator => 'Authenticator';

  @override
  String get authorization => '授权';

  @override
  String get autoStartApplication => '自动启动客户端应用程序';

  @override
  String get back => '返回';

  @override
  String get backUp => '备份';

  @override
  String get backUpAtKeys => '备份 atKeys';

  @override
  String backUpAtKeysIntroMsgFirst(String saveOrBackup) {
    String _temp0 = intl.Intl.selectLogic(saveOrBackup, {
      'save': '保存',
      'other': '备份',
    });
    return '$_temp0您的 atKeys 非常重要，这样您就可以从任何设备访问您的数据。\n\n如果您丢失了 atKeys，您将失去对您的数据的访问权限。';
  }

  @override
  String get backUpAtKeysIntroMsgLast => '\n\n您可以随时从“设置”菜单保存其他备份。';

  @override
  String get backUpAtKeysMainMsg =>
      '您的 atKeys 将在未来用于将您的 Atsign 与此设备和其他设备配对。\n\natKeys 是用于保护您的 Atsign 的加密密钥。\n\n它们是您独有的，用于加密和解密您的数据。';

  @override
  String get backupKeyDialogTitle => '请选择要导出到的文件：';

  @override
  String get backupYourKey => '备份您的密钥';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get connected => '已连接';

  @override
  String get connectionClosed => '连接已关闭，将重试...';

  @override
  String get connectionRetrying => '正在重试连接 (keep-alive)...';

  @override
  String get connections => '连接';

  @override
  String get connectionTimedOut => '连接超时，将重试...';

  @override
  String get connectUriProtocolDescription =>
      '此设置会在建立连接后，根据所选协议自动启动相应的应用程序。如果未选择协议，则不会启动任何应用程序。选择用于连接的协议。';

  @override
  String get connectUriProtocolNone => '无';

  @override
  String get connectUriUsername => '用户名';

  @override
  String get connectUriUsernameDescription =>
      '协议（如 SSH）的可选用户名（例如，ssh://user@host 中的 user）';

  @override
  String get couldNotLoadPreviousState => '无法加载先前的状态错误';

  @override
  String get custom => '自定义';

  @override
  String get dashboard => '仪表板';

  @override
  String get dashboardView => '仪表板视图';

  @override
  String get debugDumpLogTitle => '开发：将日志转储到终端';

  @override
  String get defaultRelaySelection => '默认 Relay 选择';

  @override
  String get delete => '删除';

  @override
  String get demo => '演示';

  @override
  String get demoDescription => '点击此处加载测试配置文件。';

  @override
  String get demoTextButton => '立即体验';

  @override
  String get description => '描述';

  @override
  String get deviceAdd => '添加设备';

  @override
  String get deviceAtsign => '设备 Atsign';

  @override
  String get deviceAtsignDescription => '这是与您的设备关联的 Atsign。';

  @override
  String get deviceAtsignDescriptionTwo =>
      '一个 Atsign，如“@bob_device”，将被连接到。 这也称为正在运行守护程序进程的守护程序或 npd 机器，连接请求将发送到该守护程序进程，连接将建立到此设备。';

  @override
  String get deviceAtsigns => '设备 Atsign';

  @override
  String get deviceEdit => '编辑设备';

  @override
  String get deviceGroup => '设备组';

  @override
  String get deviceGroupAdd => '添加设备组';

  @override
  String get deviceGroupEdit => '编辑设备组';

  @override
  String get deviceGroupNo => '无设备组';

  @override
  String get deviceGroups => '设备组';

  @override
  String get deviceGroupsNotAdded => '尚未添加设备组';

  @override
  String get deviceGroupTooltip => '指定 --dg 选项的守护程序进程，并使用字符串将允许从用户连接到指定的主机：端口';

  @override
  String get deviceName => '设备名称';

  @override
  String get deviceNameDescription => '这是您的远程设备的名称。';

  @override
  String get devices => '设备';

  @override
  String get devicesNotAdded => '尚未添加设备';

  @override
  String get devicesTooltip =>
      '设备 Atsign 下的设备名称字符串，如“默认”。一个设备 Atsign 可以有多个设备名称，设备名称有助于区分各个设备守护程序进程。 在此处添加设备名称将允许从用户 Atsign 到此设备 Atsign/设备名称对建立隧道。';

  @override
  String get disconnected => '已断开连接';

  @override
  String get discord => 'Discord 支持';

  @override
  String get done => '完成';

  @override
  String get duplicate => '复制';

  @override
  String get edit => '编辑';

  @override
  String get email => '电子邮件支持';

  @override
  String get emptyProfileMessage => '未找到配置文件。\n创建或导入配置文件以开始使用 NoPorts。';

  @override
  String get enableLogging => '启用日志记录';

  @override
  String get enroll => '注册';

  @override
  String get enrollApproved => '注册请求已获批准';

  @override
  String get enrollDenied => '注册请求被拒绝';

  @override
  String get enrollRequestDenied => '注册请求被拒绝';

  @override
  String get enrollWithAuthenticator => '使用 Authenticator 注册';

  @override
  String get enrollWithAuthenticatorDescription => '通过具有管理员密钥的应用进行身份验证';

  @override
  String get enterOtp => '输入 OTP';

  @override
  String get error => '错误';

  @override
  String errorAtKeySaveFailed(Object error) {
    return '保存 atKeys 文件失败：$error';
  }

  @override
  String get errorAtKeysFileProcessFailed => '处理 atKeys 文件失败';

  @override
  String get errorAtKeysInvalid => '检测到无效的 atKeys 文件';

  @override
  String get errorAtKeysUploadedMismatch => '您上传的 atKeys 文件与请求的 Atsign 不匹配';

  @override
  String get errorAtServerUnavailable => '无法检索 atserver 状态，请确保您有稳定的互联网连接。';

  @override
  String get errorAtServerUnreachable => '无法连接到 atServer，请确保您有稳定的互联网连接。';

  @override
  String errorAtsignAlreadyPaired(Object atsign) {
    return 'Atsign $atsign 已配对，请联系支持人员。';
  }

  @override
  String get errorAtsignNotExist => '您请求的 Atsign 在此根域中不存在。';

  @override
  String get errorAtsignUnavailable =>
      'Atsign 不可用。请确保您已从仪表板按下“激活”并且具有稳定的互联网连接。';

  @override
  String get errorAuthenticatinFailed => '身份验证失败。';

  @override
  String get errorAuthenticationTimedOut => '身份验证超时。';

  @override
  String errorDuringStartupWithDetails(Object errorMessage) {
    return '启动期间出错：$errorMessage';
  }

  @override
  String get errorOtpRequestFailed => '请求 OTP 失败，请尝试重新发送，如果问题仍然存在，请联系支持人员。';

  @override
  String get errorOtpVerificationFailed =>
      '使用激活服务器验证 OTP 失败，请重试。如果问题仍然存在，请联系支持人员。';

  @override
  String get errorProfileLoadFailed => '加载此配置文件失败';

  @override
  String get errorRootDomainNotSupported => '自动激活不支持指定的根域。';

  @override
  String get errorSwitchAtsignFailed => '激活后切换 Atsign 失败。';

  @override
  String errorWithDetails(Object errorMessage) {
    return '错误：$errorMessage,';
  }

  @override
  String get europe => '欧洲';

  @override
  String get export => '导出';

  @override
  String get exportLogs => '导出日志';

  @override
  String get faq => '常见问题';

  @override
  String get fastest => '最快';

  @override
  String get feedback => '反馈';

  @override
  String get fileFormatInvalid => '文档格式无效。请上传有效文件。';

  @override
  String get fileFormatInvalidDetails => '缺少配置文件部分或格式不正确。请检查文档。';

  @override
  String get fileImported => '文件已导入';

  @override
  String get fileSaved => '文件已保存';

  @override
  String get findOtp =>
      '请求将在 Authenticator 的“请求”中显示在任何通过管理员密钥连接到您的 Atsign 的应用中。';

  @override
  String get getStarted => '开始使用';

  @override
  String get groupAdd => '添加组';

  @override
  String get groupName => '组名';

  @override
  String get import => '导入';

  @override
  String get importFile => '导入文件';

  @override
  String get info => '信息';

  @override
  String get invalidOtp => '无效 OTP';

  @override
  String get json => 'JSON';

  @override
  String get jsonCopyToClipboard => '将 JSON 复制到剪贴板';

  @override
  String get jsonPayloadCopiedToClipboard => 'JSON 负载已复制到剪贴板';

  @override
  String get keys => '上传 atKeys';

  @override
  String get language => '语言';

  @override
  String get loading => '加载中';

  @override
  String get localHost => '本地主机';

  @override
  String get localHostDescription => '要绑定到本地机器的hostname或IP地址';

  @override
  String get localPort => '本地端口';

  @override
  String get localPortDescription => '您将在本地机器上使用的端口';

  @override
  String get logs => '日志';

  @override
  String get logsClear => '清除日志';

  @override
  String get logsNotAvailable => '尚无可用日志。\n当发出策略请求时，活动将显示在此处。';

  @override
  String get logsNotAvailableStartMonitoring => '没有可用的日志。\n从策略管理器启动监控以查看活动。';

  @override
  String get logsView => '查看日志';

  @override
  String get logType => '日志类型';

  @override
  String get manageAtsigns => '管理 Atsign';

  @override
  String get minimal => '简单';

  @override
  String get monitoringActive => '监控活动';

  @override
  String get monitoringInactive => '监控不活动';

  @override
  String get monitoringStart => '开始监控';

  @override
  String get monitoringStop => '停止监控';

  @override
  String get myNoPortsMsg => '在 My NoPorts 中检索您的 Atsign →';

  @override
  String get name => '名称';

  @override
  String get next => '下一步';

  @override
  String get noAtsign => '无 Atsign';

  @override
  String get noAtsignsAdded => '尚未添加 Atsign';

  @override
  String get noDescription => '无描述';

  @override
  String get noEmailClientAvailable => '没有可用的电子邮件客户端';

  @override
  String get noName => '无名称';

  @override
  String get noPorts => 'NoPorts';

  @override
  String get nptStartupTimedout => 'Npt 启动超时';

  @override
  String get ok => '确定';

  @override
  String get onboard => '引导';

  @override
  String get onboardingButtonStatusPicking => '等待选择文件';

  @override
  String get onboardingButtonStatusProcessingFile => '正在处理文件';

  @override
  String get onboardingError => '发生错误';

  @override
  String get onboardingSubTitle => '到 NoPorts 桌面';

  @override
  String get onboardingTitle => '欢迎';

  @override
  String get or => '或';

  @override
  String get overrideAllProfile => '使用默认 Relay 选择覆盖所有配置文件';

  @override
  String get pasteProfile => '粘贴配置文件';

  @override
  String get pasteProfileDescription => '在此处粘贴 JSON/YAML 内容';

  @override
  String permitOpens(Object permitOpens) {
    return '允许打开：$permitOpens';
  }

  @override
  String get permitOpensHostPort => '允许打开 (host:port)';

  @override
  String get permitOpensNotConfigured => '未配置允许打开';

  @override
  String get policy => '策略';

  @override
  String get policyLogs => '策略日志';

  @override
  String get policyManager => '策略管理器';

  @override
  String get policyRequestPayload => '策略请求负载';

  @override
  String get preview => '预览';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get profile => '配置文件';

  @override
  String get profileDeleteMessage => '此配置文件将被永久删除。';

  @override
  String get profileDeleteSecondaryMessage =>
      '某些配置文件正在运行，不会被删除，请先停止这些配置文件再进行删除。';

  @override
  String get profileDeleteSelectedMessage => '选定的配置文件将被永久删除。';

  @override
  String get profileExportDialogTitle => '选择文件类型';

  @override
  String get profileExportMessage => '您想导出为哪种文件类型？';

  @override
  String get profileExportSelectedMessage => '您想将选定的配置文件导出为哪种文件类型？';

  @override
  String get profileFailedLoaded => '配置文件加载失败';

  @override
  String get profileFailedSaveMessage => '配置文件保存失败';

  @override
  String get profileFailedUnknownMessage => '未提供原因';

  @override
  String get profileImportDialogTitle => '选择导入方式';

  @override
  String get profileImportFailed => '导入文件失败';

  @override
  String get profileImportSelectedMessage => '您想如何导入配置文件？';

  @override
  String get profileKeepAlive => '🕺 保持活动';

  @override
  String get profileKeepAliveDescription =>
      '保持活动。如果会话结束，则创建一个新的会话并重新绑定到本地端口。会话可能会因超时或网络问题而未被使用而结束。';

  @override
  String get profileName => '配置文件名称';

  @override
  String get profileNameDescription => '这将是您的配置的名称。';

  @override
  String get profilePort443 => '使用端口 443';

  @override
  String get profilePort443Description =>
      '强制中继使用端口 443 而不是临时端口。 自动启用 ESCR 中继身份验证模式以提高安全性。';

  @override
  String get profileRunningActionDeniedMessage => '配置文件运行时无法执行此操作。';

  @override
  String get profileRunningCloseMsgStart => '以下配置文件已连接：';

  @override
  String get profilesFailedLoaded => '配置文件加载失败';

  @override
  String get profileStatusFailedLoad => '加载失败';

  @override
  String get profileStatusFailedSave => '保存失败';

  @override
  String get profileStatusFailedStart => '启动失败';

  @override
  String get profileStatusLoaded => '已断开连接';

  @override
  String get profileStatusLoadedMessage => '当前已断开连接';

  @override
  String get profileStatusLoading => '正在加载';

  @override
  String get profileStatusStarted => '已连接';

  @override
  String get profileStatusStartedMessage => '连接成功';

  @override
  String get profileStatusStarting => '正在启动';

  @override
  String get profileStatusStopping => '正在关闭';

  @override
  String get quit => '退出';

  @override
  String get refresh => '刷新';

  @override
  String get register => '注册';

  @override
  String get relay => 'Relay';

  @override
  String get relayDescription => '从我们现有的 Relay 中选择或创建一个新的。';

  @override
  String get reload => '重新加载';

  @override
  String get remoteHost => '远程主机';

  @override
  String get remoteHostDescription => '您在远程机器上连接到的服务的hostname或IP地址';

  @override
  String get remotePort => '远程端口';

  @override
  String get remotePortDescription => '将在远程机器上使用的端口';

  @override
  String get removeAtsign => '删除 Atsign';

  @override
  String get requestExpired => '原始请求已过期。请再次提交';

  @override
  String get required => '必填';

  @override
  String get resendPin => '重新发送 Pin';

  @override
  String retryFailedWithDetails(Object errorMessage) {
    return '重试失败：$errorMessage，将重试...';
  }

  @override
  String get roleAddNew => '添加新角色';

  @override
  String get roleCreatingFailed => '创建角色失败';

  @override
  String roleCreatingFailedWithDetails(Object errorMessage) {
    return '创建角色失败：$errorMessage';
  }

  @override
  String get roleDelete => '删除角色';

  @override
  String roleDeleteConfirmation(Object roleName) {
    return '您确定要删除角色“$roleName”吗？此操作无法撤消。';
  }

  @override
  String get roleDeletedSuccessfully => '角色删除成功！';

  @override
  String get roleDeletingFailed => '删除角色失败';

  @override
  String roleDeletingFailedWithDetails(Object errorMessage) {
    return '删除角色失败：$errorMessage';
  }

  @override
  String roleLoadingFailedWithDetails(Object errorMessage) {
    return '加载角色失败：$errorMessage';
  }

  @override
  String get roleNotFound => '未找到角色';

  @override
  String get roleNotLoaded => '未加载角色';

  @override
  String get roles => '角色';

  @override
  String get roleSaveFailed => '保存角色失败';

  @override
  String roleSaveFailedWithDetails(Object errorMessage) {
    return '保存角色失败：$errorMessage';
  }

  @override
  String get roleSelectToViewDetails => '选择角色以查看详细信息';

  @override
  String rolesLoadingFailedWithDetails(Object errorMessage) {
    return '加载角色失败：$errorMessage';
  }

  @override
  String get rolesRefresh => '刷新角色';

  @override
  String get roleUpdatingFailed => '更新角色失败';

  @override
  String roleUpdatingFailedWithDetails(Object errorMessage) {
    return '更新角色失败：$errorMessage';
  }

  @override
  String get rootDomainDefault => '默认 (Prod)';

  @override
  String get rootDomainDemo => '演示 (VE)';

  @override
  String get save => '保存';

  @override
  String get saveAtKeys => '保存 atKeys';

  @override
  String get saveLater => '稍后保存';

  @override
  String get selectEnrollMethod => '选择您的注册方法';

  @override
  String get selectExportFile => '请选择要导出到的文件：';

  @override
  String get selectKey => '选择 atKey';

  @override
  String get selectorSubTitleAtsign => '在下方输入您的 NoPorts Atsign。';

  @override
  String get selectorSubTitleRootDomain => '输入 atDirectory 域。';

  @override
  String get selectorTitleAtsign => 'NoPorts Atsign';

  @override
  String get selectorTitleRootDomain => 'atDirectory 域';

  @override
  String get serviceMapping => '服务映射';

  @override
  String get servicesAllowed => '允许的服务';

  @override
  String get settings => '设置';

  @override
  String get settingsCouldNotFetch => '无法获取设置';

  @override
  String get showWindow => '显示窗口';

  @override
  String get signIn => '登录';

  @override
  String get signInButtonDescription => '使用已激活的 Atsign 登录';

  @override
  String get signout => '退出';

  @override
  String get socketconnectorClosedPrematurely => 'Socketconnector 提前关闭';

  @override
  String get sshStyle => '高级';

  @override
  String get starting => '正在启动';

  @override
  String get status => '状态';

  @override
  String get stopping => '正在关闭';

  @override
  String get submit => '提交';

  @override
  String get submitOtp => '提交 OTP';

  @override
  String get success => '成功';

  @override
  String get switchAtsign => '切换 Atsign';

  @override
  String get switchAtsignDescription => '您确定要切换 Atsign 吗？';

  @override
  String get switchAtsignNote => '注意：切换 Atsign 会结束所有连接。';

  @override
  String get syncCompleted => '同步完成。所有配置文件已加载。';

  @override
  String get syncInProgress => '同步进行中。某些配置文件可能仍在加载。';

  @override
  String get timestamp => '时间戳';

  @override
  String get unknownError => '发生了未知错误';

  @override
  String get uploadKey => '上传 atKey';

  @override
  String get uploadKeyDescription => '选择本地 .atkey 文件';

  @override
  String get validationErrorAtsignField => '字段必须是有效的 atsign';

  @override
  String get validationErrorDeviceNameField => '字段只能包含小写字母、数字和下划线。';

  @override
  String get validationErrorEmptyField => '此字段不能为空';

  @override
  String get validationErrorHostField => '字段必须是部分或完全限定的主机名或 IP 地址';

  @override
  String get validationErrorLocalPortField => '数字必须介于 1024 和 65535 之间';

  @override
  String get validationErrorLongField => '字段长度必须为 1-36 个字符';

  @override
  String get validationErrorRelayField => 'Relay 必须是有效的 atsign';

  @override
  String get validationErrorRemotePortField => '数字必须介于 1 和 65535 之间';

  @override
  String get waitingForApproval => '等待批准...';

  @override
  String get whatAreAtKeys => '什么是 atKeys？';

  @override
  String get whatIsAnAtsign => '什么是 Atsign？';

  @override
  String get whatIsAnAtsignDescription => 'Atsign 既是地址，也是您设备的唯一标识符。';

  @override
  String get whereToAccept => '在哪里接受？';

  @override
  String get whereToAcceptDescription => '请在具有管理密钥的应用中批准该请求。';

  @override
  String get yaml => 'YAML';

  @override
  String get yamlRecommended => 'YAML (推荐)';
}

/// The translations for Chinese, as used in Hong Kong, using the Han script (`zh_Hant_HK`).
class AppLocalizationsZhHantHk extends AppLocalizationsZh {
  AppLocalizationsZhHantHk() : super('zh_Hant_HK');

  @override
  String get activate => '啟動';

  @override
  String get activating => '正在啟動';

  @override
  String get activationAtsignFileStorageLocation => '選擇一個資料夾來儲存您的 .atKeys 檔案';

  @override
  String get activationAtsignListDescription => '以下 Atsign 將被啟動：';

  @override
  String get activationButtonDescription => '完成啟動並設定新的 Atsign';

  @override
  String get activationComplete => '完成啟動';

  @override
  String get activationFileBased => '以檔案為基礎的啟動';

  @override
  String get activationFileBasedDescription =>
      '請上傳您的啟動檔案 (.yaml)。\n此檔案可從您的管理入口網站下載。';

  @override
  String get activationFileErrorMessage => '請使用有效的啟動檔案。';

  @override
  String get activationFileLoadingMessage => '正在處理檔案...';

  @override
  String get activationFileSuccessMessage => '啟動檔案上傳成功！';

  @override
  String get activationFileUploadDragDropDescription =>
      '上傳或拖放您的一次性啟動檔案 (.yaml)';

  @override
  String get activationKeyStatusActivated => '已啟動';

  @override
  String get activationKeyStatusActivating => '正在啟動';

  @override
  String get activationKeyStatusAlreadyActivated => '已啟動';

  @override
  String get activationKeyStatusFailed => '失敗';

  @override
  String get activationKeyStatusWaiting => '等待中';

  @override
  String get activationManual => '手動啟動';

  @override
  String get activationStatus => '啟動狀態';

  @override
  String get activationStatusActivating => '正在啟動';

  @override
  String activationStatusCount(Object current, Object total) {
    return '已啟動 $total 個中的 $current 個 Atsign：';
  }

  @override
  String get activationStatusOtpWait => '請輸入您電子郵件中的 OTP';

  @override
  String get activationStatusPreparing => '準備啟動';

  @override
  String get add => '新增';

  @override
  String get addAtsign => '新增 Atsign';

  @override
  String get addNew => '新增項目';

  @override
  String get advanced => '進階';

  @override
  String get advancedSettings => '進階設定';

  @override
  String get alertDialogTitle => '您確定嗎？';

  @override
  String get allRightsReserved => '© 2026 Atsign，保留所有權利';

  @override
  String get americas => '美洲';

  @override
  String get approveInstructions => '請使用管理員金鑰在應用程式中核准請求';

  @override
  String get asiaPacific => '亞太地區';

  @override
  String get atDirectory => 'AtDirectory';

  @override
  String get atDirectorySubtitle => '選取您想使用的網域';

  @override
  String get atsignDialogSubtitle => '請選取您的 Atsign';

  @override
  String get atsignDialogTitle => 'Atsign';

  @override
  String get atsignFrom => '來自 Atsign';

  @override
  String get atsignsUser => '使用者 Atsign';

  @override
  String get atsignsUserTooltip => '類似「@alice」的 Atsign，將連線至其他裝置';

  @override
  String get atsignTo => '至 Atsign';

  @override
  String get atsignUncreated => '沒有 Atsign？';

  @override
  String get authenticate => '驗證';

  @override
  String get authenticator => 'Authenticator';

  @override
  String get authorization => '授權';

  @override
  String get autoStartApplication => '自動啟動用戶端應用程式';

  @override
  String get back => '返回';

  @override
  String get backUp => '備份';

  @override
  String get backUpAtKeys => '備份 atKeys';

  @override
  String backUpAtKeysIntroMsgFirst(String saveOrBackup) {
    String _temp0 = intl.Intl.selectLogic(saveOrBackup, {
      'save': '儲存',
      'other': '備份',
    });
    return '$_temp0您的 atKeys 非常重要，這樣您就可以從任何裝置存取您的資料。\n\n如果您遺失了 atKeys，您將失去對您的資料的存取權。';
  }

  @override
  String get backUpAtKeysIntroMsgLast => '\n\n您可以隨時從「設定」選單儲存其他備份。';

  @override
  String get backUpAtKeysMainMsg =>
      '您的 atKeys 將在未來用於將您的 Atsign 與此裝置和其他裝置配對。\n\natKeys 是用於保護您的 Atsign 的加密金鑰。\n\n它們是您獨有的，用於加密和解密您的資料。';

  @override
  String get backupKeyDialogTitle => '請選取要匯出到的檔案：';

  @override
  String get backupYourKey => '備份您的金鑰';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '確認';

  @override
  String get connected => '已連線';

  @override
  String get connectionClosed => '連線已關閉，將重試...';

  @override
  String get connectionRetrying => '正在重試連線 (保持運作)...';

  @override
  String get connections => '連線';

  @override
  String get connectionTimedOut => '連線逾時，將重試...';

  @override
  String get connectUriProtocolDescription =>
      '此設定會根據所選的通訊協定，在建立連線後自動啟動適當的應用程式。如果未選取通訊協定，則不會啟動任何應用程式。選取用於連線的通訊協定。';

  @override
  String get connectUriProtocolNone => '無';

  @override
  String get connectUriUsername => '使用者名稱';

  @override
  String get connectUriUsernameDescription =>
      '通訊協定（如 SSH）的可選使用者名稱 (例如，ssh://user@host 中的 user)';

  @override
  String get couldNotLoadPreviousState => '無法載入先前狀態錯誤';

  @override
  String get custom => '自訂';

  @override
  String get dashboard => '儀表板';

  @override
  String get dashboardView => '儀表板檢視';

  @override
  String get debugDumpLogTitle => '開發：將日誌傾印至終端機';

  @override
  String get defaultRelaySelection => '預設 Relay 選取';

  @override
  String get delete => '刪除';

  @override
  String get demo => '示範';

  @override
  String get demoDescription => '按一下這裡載入測試設定檔。';

  @override
  String get demoTextButton => '立即試用';

  @override
  String get description => '描述';

  @override
  String get deviceAdd => '新增裝置';

  @override
  String get deviceAtsign => '裝置 Atsign';

  @override
  String get deviceAtsignDescription => '這是與您的裝置相關聯的 Atsign。';

  @override
  String get deviceAtsignDescriptionTwo =>
      '類似「@bob_device」的 Atsign，將連線至。這也稱為正在執行守護程序程序的守護程序或 npd 機器，連接要求將傳送至該守護程序程序，並於其中建立連線到此裝置。';

  @override
  String get deviceAtsigns => '裝置 Atsign';

  @override
  String get deviceEdit => '編輯裝置';

  @override
  String get deviceGroup => '裝置群組';

  @override
  String get deviceGroupAdd => '新增裝置群組';

  @override
  String get deviceGroupEdit => '編輯裝置群組';

  @override
  String get deviceGroupNo => '無裝置群組';

  @override
  String get deviceGroups => '裝置群組';

  @override
  String get deviceGroupsNotAdded => '尚未新增裝置群組';

  @override
  String get deviceGroupTooltip =>
      '指定 --dg 選項的守護程序程序並使用字串，將允許從使用者連線至指定的 host:port';

  @override
  String get deviceName => '裝置名稱';

  @override
  String get deviceNameDescription => '這是您遠端裝置的名稱。';

  @override
  String get devices => '裝置';

  @override
  String get devicesNotAdded => '尚未新增裝置';

  @override
  String get devicesTooltip =>
      '類似「default」的裝置名稱字串，位於裝置 Atsign 之下。裝置 Atsign 可有多個裝置名稱，裝置名稱有助於區分個別裝置守護程序程序。在此新增裝置名稱，將允許從使用者 Atsign 建立至此裝置 Atsign/裝置名稱配對的通道。';

  @override
  String get disconnected => '已斷線';

  @override
  String get discord => 'Discord 支援';

  @override
  String get done => '完成';

  @override
  String get duplicate => '複製';

  @override
  String get edit => '編輯';

  @override
  String get email => '電子郵件支援';

  @override
  String get emptyProfileMessage => '找不到設定檔。\n建立或匯入設定檔以開始使用 NoPorts。';

  @override
  String get enableLogging => '啟用日誌記錄';

  @override
  String get enroll => '註冊';

  @override
  String get enrollApproved => '註冊請求已獲核准';

  @override
  String get enrollDenied => '註冊請求被拒絕';

  @override
  String get enrollRequestDenied => '註冊請求被拒絕';

  @override
  String get enrollWithAuthenticator => '使用 Authenticator 註冊';

  @override
  String get enrollWithAuthenticatorDescription => '透過具有管理員金鑰的應用程式進行驗證';

  @override
  String get enterOtp => '輸入 OTP';

  @override
  String get error => '錯誤';

  @override
  String errorAtKeySaveFailed(Object error) {
    return '儲存 atKeys 檔案失敗：$error';
  }

  @override
  String get errorAtKeysFileProcessFailed => '處理 atKeys 檔案失敗';

  @override
  String get errorAtKeysInvalid => '偵測到無效的 atKeys 檔案';

  @override
  String get errorAtKeysUploadedMismatch => '您上傳的 atKeys 檔案與要求的 Atsign 不符';

  @override
  String get errorAtServerUnavailable => '無法擷取 atServer 狀態，請確認您有穩定的網路連線。';

  @override
  String get errorAtServerUnreachable => '無法連線至 atServer，請確認您有穩定的網路連線。';

  @override
  String errorAtsignAlreadyPaired(Object atsign) {
    return 'Atsign $atsign 已配對，請聯絡支援人員。';
  }

  @override
  String get errorAtsignNotExist => '您要求的 Atsign 在此根網域中不存在。';

  @override
  String get errorAtsignUnavailable => 'Atsign 無法使用。請確認您已從儀表板按下「啟動」並具有穩定的網路連線。';

  @override
  String get errorAuthenticatinFailed => '身分驗證失敗。';

  @override
  String get errorAuthenticationTimedOut => '身分驗證逾時。';

  @override
  String errorDuringStartupWithDetails(Object errorMessage) {
    return '啟動期間發生錯誤：$errorMessage';
  }

  @override
  String get errorOtpRequestFailed => '要求 OTP 失敗，請嘗試重新傳送，如果問題仍然存在，請聯絡支援人員。';

  @override
  String get errorOtpVerificationFailed =>
      '使用啟動伺服器驗證 OTP 失敗，請重試。如果問題仍然存在，請聯絡支援人員。';

  @override
  String get errorProfileLoadFailed => '載入此設定檔失敗';

  @override
  String get errorRootDomainNotSupported => '自動啟動不支援指定的根網域。';

  @override
  String get errorSwitchAtsignFailed => '啟動後切換 Atsign 失敗。';

  @override
  String errorWithDetails(Object errorMessage) {
    return '錯誤：$errorMessage,';
  }

  @override
  String get europe => '歐洲';

  @override
  String get export => '匯出';

  @override
  String get exportLogs => '匯出日誌';

  @override
  String get faq => '常見問題';

  @override
  String get fastest => '最快';

  @override
  String get feedback => '意見反應';

  @override
  String get fileFormatInvalid => '文件格式無效。請上傳有效檔案。';

  @override
  String get fileFormatInvalidDetails => '設定檔區段遺失或格式不正確。請檢查文件。';

  @override
  String get fileImported => '檔案已匯入';

  @override
  String get fileSaved => '檔案已儲存';

  @override
  String get findOtp =>
      '該請求將顯示在 Authenticator 的「請求」中，位於任何透過管理員金鑰連接至您 Atsign 的應用程式。';

  @override
  String get getStarted => '開始使用';

  @override
  String get groupAdd => '新增群組';

  @override
  String get groupName => '群組名稱';

  @override
  String get import => '匯入';

  @override
  String get importFile => '匯入檔案';

  @override
  String get info => '資訊';

  @override
  String get invalidOtp => '無效 OTP';

  @override
  String get json => 'JSON';

  @override
  String get jsonCopyToClipboard => '將 JSON 複製到剪貼簿';

  @override
  String get jsonPayloadCopiedToClipboard => 'JSON 承載已複製到剪貼簿';

  @override
  String get keys => '上傳 atKeys';

  @override
  String get language => '語言';

  @override
  String get loading => '載入中';

  @override
  String get localHost => '本機主機';

  @override
  String get localHostDescription => '要繫結至本機機器的 host name 或 IP 位址';

  @override
  String get localPort => '本地連接埠';

  @override
  String get localPortDescription => '您將在本機機器上使用的連接埠';

  @override
  String get logs => '日誌';

  @override
  String get logsClear => '清除日誌';

  @override
  String get logsNotAvailable => '目前沒有日誌可用。\n當提出政策要求時，活動將顯示在此。';

  @override
  String get logsNotAvailableStartMonitoring => '沒有可用的日誌。\n從政策管理員啟動監控以查看活動。';

  @override
  String get logsView => '檢視日誌';

  @override
  String get logType => '日誌類型';

  @override
  String get manageAtsigns => '管理 Atsign';

  @override
  String get minimal => '簡易';

  @override
  String get monitoringActive => '監控中';

  @override
  String get monitoringInactive => '監控已停用';

  @override
  String get monitoringStart => '開始監控';

  @override
  String get monitoringStop => '停止監控';

  @override
  String get myNoPortsMsg => '在 My NoPorts 中檢索您的 Atsign →';

  @override
  String get name => '名稱';

  @override
  String get next => '下一步';

  @override
  String get noAtsign => '無 Atsign';

  @override
  String get noAtsignsAdded => '尚未新增 Atsign';

  @override
  String get noDescription => '無描述';

  @override
  String get noEmailClientAvailable => '沒有可用的電子郵件用戶端';

  @override
  String get noName => '無名稱';

  @override
  String get noPorts => 'NoPorts';

  @override
  String get nptStartupTimedout => 'Npt 啟動逾時';

  @override
  String get ok => '確定';

  @override
  String get onboard => '引導';

  @override
  String get onboardingButtonStatusPicking => '等待選取檔案';

  @override
  String get onboardingButtonStatusProcessingFile => '正在處理檔案';

  @override
  String get onboardingError => '發生錯誤';

  @override
  String get onboardingSubTitle => '至 NoPorts 桌面';

  @override
  String get onboardingTitle => '歡迎';

  @override
  String get or => '或';

  @override
  String get overrideAllProfile => '使用預設 Relay 選取覆寫所有設定檔';

  @override
  String get pasteProfile => '貼上設定檔';

  @override
  String get pasteProfileDescription => '在此處貼上 JSON/YAML 內容';

  @override
  String permitOpens(Object permitOpens) {
    return '允許開啟：$permitOpens';
  }

  @override
  String get permitOpensHostPort => '允許開啟 (host:port)';

  @override
  String get permitOpensNotConfigured => '未設定允許開啟';

  @override
  String get policy => '政策';

  @override
  String get policyLogs => '政策日誌';

  @override
  String get policyManager => '政策管理員';

  @override
  String get policyRequestPayload => '政策要求承載';

  @override
  String get preview => '預覽';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get profile => '設定檔';

  @override
  String get profileDeleteMessage => '此設定檔將被永久刪除。';

  @override
  String get profileDeleteSecondaryMessage => '某些設定檔正在執行，不會被刪除，請先停止這些設定檔再進行刪除。';

  @override
  String get profileDeleteSelectedMessage => '選取的設定檔將被永久刪除。';

  @override
  String get profileExportDialogTitle => '選取檔案類型';

  @override
  String get profileExportMessage => '您想要匯出為哪種檔案類型？';

  @override
  String get profileExportSelectedMessage => '您想要將選取的設定檔匯出為哪種檔案類型？';

  @override
  String get profileFailedLoaded => '設定檔載入失敗';

  @override
  String get profileFailedSaveMessage => '設定檔儲存失敗';

  @override
  String get profileFailedUnknownMessage => '未提供原因';

  @override
  String get profileImportDialogTitle => '選擇匯入方法';

  @override
  String get profileImportFailed => '匯入檔案失敗';

  @override
  String get profileImportSelectedMessage => '您想如何匯入設定檔？';

  @override
  String get profileKeepAlive => '🕺 保持運作';

  @override
  String get profileKeepAliveDescription =>
      '保持運作。如果工作階段結束，請建立新的工作階段並重新繫結至本機連接埠。工作階段可能會因為逾時或網路問題而未使用而結束。';

  @override
  String get profileName => '設定檔名稱';

  @override
  String get profileNameDescription => '這將是您的設定的名稱。';

  @override
  String get profilePort443 => '使用連接埠 443';

  @override
  String get profilePort443Description =>
      '強制中繼使用連接埠 443，而非臨時連接埠。自動啟用 ESCR 中繼驗證模式以確保安全性。';

  @override
  String get profileRunningActionDeniedMessage => '設定檔執行時無法執行此操作。';

  @override
  String get profileRunningCloseMsgStart => '以下設定檔已連線：';

  @override
  String get profilesFailedLoaded => '設定檔載入失敗';

  @override
  String get profileStatusFailedLoad => '載入失敗';

  @override
  String get profileStatusFailedSave => '儲存失敗';

  @override
  String get profileStatusFailedStart => '啟動失敗';

  @override
  String get profileStatusLoaded => '已斷線';

  @override
  String get profileStatusLoadedMessage => '目前已斷線';

  @override
  String get profileStatusLoading => '載入中';

  @override
  String get profileStatusStarted => '已連線';

  @override
  String get profileStatusStartedMessage => '連線成功';

  @override
  String get profileStatusStarting => '正在啟動';

  @override
  String get profileStatusStopping => '正在關閉';

  @override
  String get quit => '退出';

  @override
  String get refresh => '重新整理';

  @override
  String get register => '註冊';

  @override
  String get relay => 'Relay';

  @override
  String get relayDescription => '從我們現有的 Relay 中選擇或建立一個新的。';

  @override
  String get reload => '重新載入';

  @override
  String get remoteHost => '遠端主機';

  @override
  String get remoteHostDescription => '您連線至遠端機器上服務的主機名稱或 IP 位址';

  @override
  String get remotePort => '遠端連接埠';

  @override
  String get remotePortDescription => '將在遠端機器上使用的連接埠';

  @override
  String get removeAtsign => '移除 Atsign';

  @override
  String get requestExpired => '原始請求已過期。請再次提交';

  @override
  String get required => '必填';

  @override
  String get resendPin => '重新傳送 Pin';

  @override
  String retryFailedWithDetails(Object errorMessage) {
    return '重試失敗：$errorMessage，將重試...';
  }

  @override
  String get roleAddNew => '新增角色';

  @override
  String get roleCreatingFailed => '建立角色失敗';

  @override
  String roleCreatingFailedWithDetails(Object errorMessage) {
    return '建立角色失敗：$errorMessage';
  }

  @override
  String get roleDelete => '刪除角色';

  @override
  String roleDeleteConfirmation(Object roleName) {
    return '您確定要刪除角色「$roleName」嗎？此動作無法復原。';
  }

  @override
  String get roleDeletedSuccessfully => '角色已成功刪除！';

  @override
  String get roleDeletingFailed => '刪除角色失敗';

  @override
  String roleDeletingFailedWithDetails(Object errorMessage) {
    return '刪除角色失敗：$errorMessage';
  }

  @override
  String roleLoadingFailedWithDetails(Object errorMessage) {
    return '載入角色失敗：$errorMessage';
  }

  @override
  String get roleNotFound => '找不到角色';

  @override
  String get roleNotLoaded => '未載入角色';

  @override
  String get roles => '角色';

  @override
  String get roleSaveFailed => '儲存角色失敗';

  @override
  String roleSaveFailedWithDetails(Object errorMessage) {
    return '儲存角色失敗：$errorMessage';
  }

  @override
  String get roleSelectToViewDetails => '選取角色以檢視詳細資訊';

  @override
  String rolesLoadingFailedWithDetails(Object errorMessage) {
    return '載入角色失敗：$errorMessage';
  }

  @override
  String get rolesRefresh => '重新整理角色';

  @override
  String get roleUpdatingFailed => '更新角色失敗';

  @override
  String roleUpdatingFailedWithDetails(Object errorMessage) {
    return '更新角色失敗：$errorMessage';
  }

  @override
  String get rootDomainDefault => '預設 (Prod)';

  @override
  String get rootDomainDemo => '示範 (VE)';

  @override
  String get save => '儲存';

  @override
  String get saveAtKeys => '儲存 atKeys';

  @override
  String get saveLater => '稍後儲存';

  @override
  String get selectEnrollMethod => '選取您的註冊方法';

  @override
  String get selectExportFile => '請選取要匯出到的檔案：';

  @override
  String get selectKey => '選取 atKey';

  @override
  String get selectorSubTitleAtsign => '在下方輸入您的 NoPorts Atsign。';

  @override
  String get selectorSubTitleRootDomain => '輸入 atDirectory 網域。';

  @override
  String get selectorTitleAtsign => 'NoPorts Atsign';

  @override
  String get selectorTitleRootDomain => 'atDirectory 網域';

  @override
  String get serviceMapping => '服務對應';

  @override
  String get servicesAllowed => '允許的服務';

  @override
  String get settings => '設定';

  @override
  String get settingsCouldNotFetch => '無法提取設定';

  @override
  String get showWindow => '顯示視窗';

  @override
  String get signIn => '登入';

  @override
  String get signInButtonDescription => '使用已啟動的 Atsign 登入';

  @override
  String get signout => '登出';

  @override
  String get socketconnectorClosedPrematurely => 'Socketconnector 提前關閉';

  @override
  String get sshStyle => '進階';

  @override
  String get starting => '正在啟動';

  @override
  String get status => '狀態';

  @override
  String get stopping => '正在關閉';

  @override
  String get submit => '提交';

  @override
  String get submitOtp => '提交 OTP';

  @override
  String get success => '成功';

  @override
  String get switchAtsign => '切換 Atsign';

  @override
  String get switchAtsignDescription => '您確定要切換 Atsign 嗎？';

  @override
  String get switchAtsignNote => '注意：切換 Atsign 會結束所有連線。';

  @override
  String get syncCompleted => '同步完成。所有設定檔已載入。';

  @override
  String get syncInProgress => '同步進行中。某些設定檔可能仍在載入。';

  @override
  String get timestamp => '時間戳記';

  @override
  String get unknownError => '發生未知錯誤';

  @override
  String get uploadKey => '上傳 atKey';

  @override
  String get uploadKeyDescription => '選取本機 .atkey 檔案';

  @override
  String get validationErrorAtsignField => '欄位必須是有效的 atsign';

  @override
  String get validationErrorDeviceNameField => '欄位只能包含小寫字母、數字和底線。';

  @override
  String get validationErrorEmptyField => '此欄位不得為空';

  @override
  String get validationErrorHostField => '欄位必須是部分或完整限定的主機名稱或 IP 位址';

  @override
  String get validationErrorLocalPortField => '數字必須介於 1024 和 65535 之間';

  @override
  String get validationErrorLongField => '欄位長度必須為 1-36 個字元';

  @override
  String get validationErrorRelayField => 'Relay 必須是有效的 atsign';

  @override
  String get validationErrorRemotePortField => '數字必須介於 1 和 65535 之間';

  @override
  String get waitingForApproval => '等待核准...';

  @override
  String get whatAreAtKeys => '什麼是 atKeys？';

  @override
  String get whatIsAnAtsign => '什麼是 Atsign？';

  @override
  String get whatIsAnAtsignDescription => 'Atsign 既是位址，也是您裝置的唯一識別碼。';

  @override
  String get whereToAccept => '在哪裡接受？';

  @override
  String get whereToAcceptDescription => '請在具有管理金鑰的應用程式中核准該請求。';

  @override
  String get yaml => 'YAML';

  @override
  String get yamlRecommended => 'YAML (推薦)';
}
