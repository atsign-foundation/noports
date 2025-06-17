// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get activationStatusActivating => '正在激活';

  @override
  String get activationStatusOtpWait => '请从您的电子邮件中输入 OTP';

  @override
  String get activationStatusPreparing => '准备激活';

  @override
  String get addNew => '添加新项';

  @override
  String get advanced => '高级';

  @override
  String get alertDialogTitle => '你确定吗？';

  @override
  String get allRightsReserved => '@ 2025 Atsign, 版权所有';

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
  String get atsignDialogSubtitle => '请选择您的 atSign';

  @override
  String get atsignDialogTitle => 'atSign';

  @override
  String get atsignUncreated => '没有 atSign？';

  @override
  String get authenticate => '身份验证';

  @override
  String get authorisation => '授权';

  @override
  String get back => '返回';

  @override
  String get backUpAtKeys => '备份 atKeys';

  @override
  String get backUpAtKeysIntroMsgFirst =>
      '备份您的 atKeys 非常重要，这样您就可以从任何设备访问您的数据。\n\n如果您丢失了 atKeys，您将失去对您的数据的访问权限。';

  @override
  String get backUpAtKeysIntroMsgLast => '\n\n您可以随时从“设置”菜单保存其他备份。';

  @override
  String get backUpAtKeysMainMsg =>
      '您的 atKeys 将在未来用于将您的 atSign 与此设备和其他设备配对。\n\natKeys 是用于保护您的 atSign 的加密密钥。\n\n它们是您独有的，用于加密和解密您的数据。';

  @override
  String get backupKeyDialogTitle => '请选择要导出到的文件：';

  @override
  String get backupYourKey => '备份您的密钥';

  @override
  String get cancel => '取消';

  @override
  String get clientAtsignDescription => 'atSign 是分配给设备的\n可解析地址。';

  @override
  String get confirm => '确认';

  @override
  String get connected => '已连接';

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
  String get demoTextButton => '立即试用';

  @override
  String get deviceAtsign => '设备 atSign';

  @override
  String get deviceAtsignDescription => '这是与您的设备关联的 atSign。';

  @override
  String get deviceName => '设备名称';

  @override
  String get deviceNameDescription => '这是您的远程设备的名称。';

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
  String get emptyProfileMessage => '未找到配置文件\n创建或导入配置文件以开始使用 NoPorts。';

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
  String get errorAtKeysUploadedMismatch => '您上传的 atKeys 文件与请求的 atSign 不匹配';

  @override
  String get errorAtServerUnavailable => '无法检索 atserver 状态，请确保您有稳定的互联网连接。';

  @override
  String get errorAtServerUnreachable => '无法连接到 atServer，请确保您有稳定的互联网连接。';

  @override
  String errorAtSignAlreadyPaired(Object atsign) {
    return 'atSign $atsign 已配对，请联系支持人员。';
  }

  @override
  String get errorAtSignNotExist => '您请求的 atSign 在此根域中不存在。';

  @override
  String get errorAtSignUnavailable =>
      'atSign 不可用。请确保您已从仪表板按下“激活”并且具有稳定的互联网连接。';

  @override
  String get errorAuthenticatinFailed => '身份验证失败。';

  @override
  String get errorAuthenticationTimedOut => '身份验证超时。';

  @override
  String get errorOtpRequestFailed => '请求 OTP 失败，请尝试重新发送，如果问题仍然存在，请联系支持人员。';

  @override
  String get errorOtpVerificationFailed =>
      '使用激活服务器验证 OTP 失败，请重试。如果问题仍然存在，请联系支持人员。';

  @override
  String get errorProfileLoadFailed => '加载此配置文件失败，请手动刷新：';

  @override
  String get errorRootDomainNotSupported => '自动激活不支持指定的根域。';

  @override
  String get errorSwitchAtSignFailed => '激活后切换 atSign 失败。';

  @override
  String get europe => '欧洲';

  @override
  String get export => '导出';

  @override
  String get exportLogs => '导出日志';

  @override
  String get faq => '常见问题';

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
      '请求将在 Authenticator 的“请求”中显示在任何通过管理员密钥连接到您的 atSign 的应用中。';

  @override
  String get getStarted => '开始使用';

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
  String get keys => '上传 atKeys';

  @override
  String get language => '语言';

  @override
  String get loading => '加载中';

  @override
  String get localPort => '本地端口';

  @override
  String get logs => '日志';

  @override
  String get minimal => '简单';

  @override
  String get myNoPortsMsg => '在以下位置检索您的：';

  @override
  String get next => '下一步';

  @override
  String get noAtsign => '无 atSign';

  @override
  String get noEmailClientAvailable => '没有可用的电子邮件客户端';

  @override
  String get noName => '无名称';

  @override
  String get noPorts => 'NoPorts';

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
  String get profileName => '配置文件名称';

  @override
  String get profileNameDescription => '这将是您的配置的名称。';

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
  String get remotePort => '远程端口';

  @override
  String get requestExpired => '原始请求已过期。请再次提交';

  @override
  String get required => '必填';

  @override
  String get resendPin => '重新发送 Pin';

  @override
  String get resetAtsign => '重置 atSign';

  @override
  String get rootDomainDefault => '默认 (Prod)';

  @override
  String get rootDomainDemo => '演示 (VE)';

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
  String get selectorSubTitleAtsign => '在下方输入您的 NoPorts atSign。';

  @override
  String get selectorSubTitleRootDomain => '输入 atDirectory 域（以前称为根域）。';

  @override
  String get selectorTitleAtsign => 'NoPorts atSign';

  @override
  String get selectorTitleRootDomain => 'atDirectory 域';

  @override
  String get serviceMapping => '服务映射';

  @override
  String get settings => '设置';

  @override
  String get showWindow => '显示窗口';

  @override
  String get signout => '退出';

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
  String get switchAtSign => '切换 atSign';

  @override
  String get switchAtSignDescription => '您确定要切换 atSign 吗？';

  @override
  String get switchAtSignNote => '注意：切换 atSign 将结束所有连接。';

  @override
  String get syncInProgress => '同步进行中。某些配置文件可能仍在加载。';

  @override
  String get unknownError => '发生了未知错误';

  @override
  String get uploadKey => '上传 atKey';

  @override
  String get uploadKeyDescription => '选择本地 .atkey 文件';

  @override
  String get validationErrorAtsignField => '字段必须是有效的 atSign';

  @override
  String get validationErrorDeviceNameField => '字段只能包含小写字母、数字和下划线。';

  @override
  String get validationErrorEmptyField => '此字段不能为空';

  @override
  String get validationErrorLocalPortField => '数字必须介于 1024 和 65535 之间';

  @override
  String get validationErrorLongField => '字段长度必须为 1-36 个字符';

  @override
  String get validationErrorRelayField => 'Relay 必须是有效的 atsign';

  @override
  String get validationErrorRemoteHostField => '字段必须是部分或完全限定的主机名或 IP 地址';

  @override
  String get validationErrorRemotePortField => '数字必须介于 1 和 65535 之间';

  @override
  String get waitingForApproval => '等待批准...';

  @override
  String get whatAreAtKeys => '什么是 atKeys？';

  @override
  String get whatIsClientAtsign => '什么是 NoPorts atSign？';

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
  String get activationStatusActivating => '正在激活';

  @override
  String get activationStatusOtpWait => '请从您的电子邮件中输入 OTP';

  @override
  String get activationStatusPreparing => '准备激活';

  @override
  String get addNew => '添加新项';

  @override
  String get advanced => '高级';

  @override
  String get alertDialogTitle => '你确定吗？';

  @override
  String get allRightsReserved => '@ 2025 Atsign, 版权所有';

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
  String get atsignDialogSubtitle => '请选择您的 atSign';

  @override
  String get atsignDialogTitle => 'atSign';

  @override
  String get atsignUncreated => '没有 atSign？';

  @override
  String get authenticate => '身份验证';

  @override
  String get authorisation => '授权';

  @override
  String get back => '返回';

  @override
  String get backUpAtKeys => '备份 atKeys';

  @override
  String get backUpAtKeysIntroMsgFirst =>
      '备份您的 atKeys 非常重要，这样您就可以从任何设备访问您的数据。\n\n如果您丢失了 atKeys，您将失去对您的数据的访问权限。';

  @override
  String get backUpAtKeysIntroMsgLast => '\n\n您可以随时从“设置”菜单保存其他备份。';

  @override
  String get backUpAtKeysMainMsg =>
      '您的 atKeys 将在未来用于将您的 atSign 与此设备和其他设备配对。\n\natKeys 是用于保护您的 atSign 的加密密钥。\n\n它们是您独有的，用于加密和解密您的数据。';

  @override
  String get backupKeyDialogTitle => '请选择要导出到的文件：';

  @override
  String get backupYourKey => '备份您的密钥';

  @override
  String get cancel => '取消';

  @override
  String get clientAtsignDescription => 'atSign 是分配给设备的\n可解析地址。';

  @override
  String get confirm => '确认';

  @override
  String get connected => '已连接';

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
  String get demoTextButton => '立即试用';

  @override
  String get deviceAtsign => '设备 atSign';

  @override
  String get deviceAtsignDescription => '这是与您的设备关联的 atSign。';

  @override
  String get deviceName => '设备名称';

  @override
  String get deviceNameDescription => '这是您的远程设备的名称。';

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
  String get emptyProfileMessage => '未找到配置文件\n创建或导入配置文件以开始使用 NoPorts。';

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
  String get errorAtKeysUploadedMismatch => '您上传的 atKeys 文件与请求的 atSign 不匹配';

  @override
  String get errorAtServerUnavailable => '无法检索 atserver 状态，请确保您有稳定的互联网连接。';

  @override
  String get errorAtServerUnreachable => '无法连接到 atServer，请确保您有稳定的互联网连接。';

  @override
  String errorAtSignAlreadyPaired(Object atsign) {
    return 'atSign $atsign 已配对，请联系支持人员。';
  }

  @override
  String get errorAtSignNotExist => '您请求的 atSign 在此根域中不存在。';

  @override
  String get errorAtSignUnavailable =>
      'atSign 不可用。请确保您已从仪表板按下“激活”并且具有稳定的互联网连接。';

  @override
  String get errorAuthenticatinFailed => '身份验证失败。';

  @override
  String get errorAuthenticationTimedOut => '身份验证超时。';

  @override
  String get errorOtpRequestFailed => '请求 OTP 失败，请尝试重新发送，如果问题仍然存在，请联系支持人员。';

  @override
  String get errorOtpVerificationFailed =>
      '使用激活服务器验证 OTP 失败，请重试。如果问题仍然存在，请联系支持人员。';

  @override
  String get errorProfileLoadFailed => '加载此配置文件失败，请手动刷新：';

  @override
  String get errorRootDomainNotSupported => '自动激活不支持指定的根域。';

  @override
  String get errorSwitchAtSignFailed => '激活后切换 atSign 失败。';

  @override
  String get europe => '欧洲';

  @override
  String get export => '导出';

  @override
  String get exportLogs => '导出日志';

  @override
  String get faq => '常见问题';

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
      '请求将在 Authenticator 的“请求”中显示在任何通过管理员密钥连接到您的 atSign 的应用中。';

  @override
  String get getStarted => '开始使用';

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
  String get keys => '上传 atKeys';

  @override
  String get language => '语言';

  @override
  String get loading => '加载中';

  @override
  String get localPort => '本地端口';

  @override
  String get logs => '日志';

  @override
  String get minimal => '简单';

  @override
  String get myNoPortsMsg => '在以下位置检索您的：';

  @override
  String get next => '下一步';

  @override
  String get noAtsign => '无 atSign';

  @override
  String get noEmailClientAvailable => '没有可用的电子邮件客户端';

  @override
  String get noName => '无名称';

  @override
  String get noPorts => 'NoPorts';

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
  String get profileName => '配置文件名称';

  @override
  String get profileNameDescription => '这将是您的配置的名称。';

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
  String get remotePort => '远程端口';

  @override
  String get requestExpired => '原始请求已过期。请再次提交';

  @override
  String get required => '必填';

  @override
  String get resendPin => '重新发送 Pin';

  @override
  String get resetAtsign => '重置 atSign';

  @override
  String get rootDomainDefault => '默认 (Prod)';

  @override
  String get rootDomainDemo => '演示 (VE)';

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
  String get selectorSubTitleAtsign => '在下方输入您的 NoPorts atSign。';

  @override
  String get selectorSubTitleRootDomain => '输入 atDirectory 域（以前称为根域）。';

  @override
  String get selectorTitleAtsign => 'NoPorts atSign';

  @override
  String get selectorTitleRootDomain => 'atDirectory 域';

  @override
  String get serviceMapping => '服务映射';

  @override
  String get settings => '设置';

  @override
  String get showWindow => '显示窗口';

  @override
  String get signout => '退出';

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
  String get switchAtSign => '切换 atSign';

  @override
  String get switchAtSignDescription => '您确定要切换 atSign 吗？';

  @override
  String get switchAtSignNote => '注意：切换 atSign 将结束所有连接。';

  @override
  String get syncInProgress => '同步进行中。某些配置文件可能仍在加载。';

  @override
  String get unknownError => '发生了未知错误';

  @override
  String get uploadKey => '上传 atKey';

  @override
  String get uploadKeyDescription => '选择本地 .atkey 文件';

  @override
  String get validationErrorAtsignField => '字段必须是有效的 atSign';

  @override
  String get validationErrorDeviceNameField => '字段只能包含小写字母、数字和下划线。';

  @override
  String get validationErrorEmptyField => '此字段不能为空';

  @override
  String get validationErrorLocalPortField => '数字必须介于 1024 和 65535 之间';

  @override
  String get validationErrorLongField => '字段长度必须为 1-36 个字符';

  @override
  String get validationErrorRelayField => 'Relay 必须是有效的 atsign';

  @override
  String get validationErrorRemoteHostField => '字段必须是部分或完全限定的主机名或 IP 地址';

  @override
  String get validationErrorRemotePortField => '数字必须介于 1 和 65535 之间';

  @override
  String get waitingForApproval => '等待批准...';

  @override
  String get whatAreAtKeys => '什么是 atKeys？';

  @override
  String get whatIsClientAtsign => '什么是 NoPorts atSign？';

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
  String get activationStatusActivating => '正在啟動';

  @override
  String get activationStatusOtpWait => '請輸入您電子郵件中的 OTP';

  @override
  String get activationStatusPreparing => '準備啟動';

  @override
  String get addNew => '新增項目';

  @override
  String get advanced => '進階';

  @override
  String get alertDialogTitle => '您確定嗎？';

  @override
  String get allRightsReserved => '@ 2025 Atsign，保留所有權利';

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
  String get atsignDialogSubtitle => '請選取您的 atSign';

  @override
  String get atsignDialogTitle => 'atSign';

  @override
  String get atsignUncreated => '沒有 atSign？';

  @override
  String get authenticate => '驗證';

  @override
  String get authorisation => '授權';

  @override
  String get back => '返回';

  @override
  String get backUpAtKeys => '備份 atKeys';

  @override
  String get backUpAtKeysIntroMsgFirst =>
      '備份您的 atKeys 非常重要，這樣您就可以從任何裝置存取您的資料。\n\n如果您遺失了 atKeys，您將失去對您的資料的存取權。';

  @override
  String get backUpAtKeysIntroMsgLast => '\n\n您可以隨時從「設定」選單儲存其他備份。';

  @override
  String get backUpAtKeysMainMsg =>
      '您的 atKeys 將在未來用於將您的 atSign 與此裝置和其他裝置配對。\n\natKeys 是用於保護您的 atSign 的加密金鑰。\n\n它們是您獨有的，用於加密和解密您的資料。';

  @override
  String get backupKeyDialogTitle => '請選取要匯出的檔案：';

  @override
  String get backupYourKey => '備份您的金鑰';

  @override
  String get cancel => '取消';

  @override
  String get clientAtsignDescription => 'atSign 是分配給裝置的\n可解析位址。';

  @override
  String get confirm => '確認';

  @override
  String get connected => '已連線';

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
  String get demoDescription => '點擊此處載入測試設定檔。';

  @override
  String get demoTextButton => '立即試用';

  @override
  String get deviceAtsign => '裝置 atSign';

  @override
  String get deviceAtsignDescription => '這是與您的裝置相關聯的 atSign。';

  @override
  String get deviceName => '裝置名稱';

  @override
  String get deviceNameDescription => '這是您遠端裝置的名稱。';

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
  String get emptyProfileMessage => '找不到設定檔\n建立或匯入設定檔以開始使用 NoPorts。';

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
  String get errorAtKeysUploadedMismatch => '您上傳的 atKeys 檔案與要求的 atSign 不符';

  @override
  String get errorAtServerUnavailable => '無法擷取 atServer 狀態，請確認您有穩定的網路連線。';

  @override
  String get errorAtServerUnreachable => '無法連線至 atServer，請確認您有穩定的網路連線。';

  @override
  String errorAtSignAlreadyPaired(Object atsign) {
    return 'atSign $atsign 已配對，請聯絡支援人員。';
  }

  @override
  String get errorAtSignNotExist => '您要求的 atSign 在此根網域中不存在。';

  @override
  String get errorAtSignUnavailable => 'atSign 無法使用。請確認您已從儀表板按下「啟動」並具有穩定的網路連線。';

  @override
  String get errorAuthenticatinFailed => '身分驗證失敗。';

  @override
  String get errorAuthenticationTimedOut => '身分驗證逾時。';

  @override
  String get errorOtpRequestFailed => '要求 OTP 失敗，請嘗試重新傳送，如果問題仍然存在，請聯絡支援人員。';

  @override
  String get errorOtpVerificationFailed =>
      '使用啟動伺服器驗證 OTP 失敗，請重試。如果問題仍然存在，請聯絡支援人員。';

  @override
  String get errorProfileLoadFailed => '載入此設定檔失敗，請手動重新整理：';

  @override
  String get errorRootDomainNotSupported => '自動啟動不支援指定的根網域。';

  @override
  String get errorSwitchAtSignFailed => '啟動後切換 atSign 失敗。';

  @override
  String get europe => '歐洲';

  @override
  String get export => '匯出';

  @override
  String get exportLogs => '匯出日誌';

  @override
  String get faq => '常見問題';

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
      '該請求將顯示在 Authenticator 的「請求」中，位於任何透過管理員金鑰連接至您 atSign 的應用程式。';

  @override
  String get getStarted => '開始使用';

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
  String get keys => '上傳 atKeys';

  @override
  String get language => '語言';

  @override
  String get loading => '載入中';

  @override
  String get localPort => '本地連接埠';

  @override
  String get logs => '日誌';

  @override
  String get minimal => '簡易';

  @override
  String get myNoPortsMsg => '在以下位置檢索您的：';

  @override
  String get next => '下一步';

  @override
  String get noAtsign => '無 atSign';

  @override
  String get noEmailClientAvailable => '沒有可用的電子郵件用戶端';

  @override
  String get noName => '無名稱';

  @override
  String get noPorts => 'NoPorts';

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
  String get profileName => '設定檔名稱';

  @override
  String get profileNameDescription => '這將是您的設定的名稱。';

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
  String get remotePort => '遠端連接埠';

  @override
  String get requestExpired => '原始請求已過期。請再次提交';

  @override
  String get required => '必填';

  @override
  String get resendPin => '重新傳送 Pin';

  @override
  String get resetAtsign => '重設 atSign';

  @override
  String get rootDomainDefault => '預設 (Prod)';

  @override
  String get rootDomainDemo => '示範 (VE)';

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
  String get selectorSubTitleAtsign => '在下方輸入您的 NoPorts atSign。';

  @override
  String get selectorSubTitleRootDomain => '輸入 atDirectory 網域 (先前稱為根網域)。';

  @override
  String get selectorTitleAtsign => 'NoPorts atSign';

  @override
  String get selectorTitleRootDomain => 'atDirectory 網域';

  @override
  String get serviceMapping => '服務對應';

  @override
  String get settings => '設定';

  @override
  String get showWindow => '顯示視窗';

  @override
  String get signout => '登出';

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
  String get switchAtSign => '切換 atSign';

  @override
  String get switchAtSignDescription => '您確定要切換 atSign 嗎？';

  @override
  String get switchAtSignNote => '注意：切換 atSign 將結束所有連線。';

  @override
  String get syncInProgress => '同步進行中。某些設定檔可能仍在載入。';

  @override
  String get unknownError => '發生未知錯誤';

  @override
  String get uploadKey => '上傳 atKey';

  @override
  String get uploadKeyDescription => '選取本機 .atkey 檔案';

  @override
  String get validationErrorAtsignField => '欄位必須是有效的 atSign';

  @override
  String get validationErrorDeviceNameField => '欄位只能包含小寫字母、數字和底線。';

  @override
  String get validationErrorEmptyField => '此欄位不得為空';

  @override
  String get validationErrorLocalPortField => '數字必須介於 1024 和 65535 之間';

  @override
  String get validationErrorLongField => '欄位長度必須為 1-36 個字元';

  @override
  String get validationErrorRelayField => 'Relay 必須是有效的 atsign';

  @override
  String get validationErrorRemoteHostField => '欄位必須是部分或完整限定的主機名稱或 IP 位址';

  @override
  String get validationErrorRemotePortField => '數字必須介於 1 和 65535 之間';

  @override
  String get waitingForApproval => '等待核准...';

  @override
  String get whatAreAtKeys => '什麼是 atKeys？';

  @override
  String get whatIsClientAtsign => '什麼是 NoPorts atSign？';

  @override
  String get whereToAccept => '在哪裡接受？';

  @override
  String get whereToAcceptDescription => '請在具有管理金鑰的應用程式中核准該請求。';

  @override
  String get yaml => 'YAML';

  @override
  String get yamlRecommended => 'YAML (推薦)';
}
