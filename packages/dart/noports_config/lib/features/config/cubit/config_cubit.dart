import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/config/config_repository.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/features/config/model/sshnpd_config_document.dart';

enum ConfigStatus { initial, loading, ready, error }

class ConfigState extends Equatable {
  const ConfigState({
    this.status = ConfigStatus.initial,
    this.doc,
    this.savedSource,
    this.existed = false,
    this.error,
    this.yamlError,
    this.showAdvanced = false,
    this.saving = false,
  });

  final ConfigStatus status;

  /// Working copy. Mutated in place by the cubit; [source] changes drive
  /// rebuilds.
  final SshnpdConfigDocument? doc;

  /// Text as last loaded from or written to disk, for dirty tracking and
  /// revert.
  final String? savedSource;

  /// Whether the file existed on disk when loaded.
  final bool existed;
  final String? error;

  /// Set when the raw YAML editor holds text that does not parse.
  final String? yamlError;
  final bool showAdvanced;
  final bool saving;

  String get source => doc?.source ?? '';
  bool get isDirty => doc != null && source != savedSource;
  bool get isUnconfigured => doc?.isUnconfigured ?? true;
  List<ConfigProblem> get problems => doc?.validate() ?? const [];

  ConfigState copyWith({
    ConfigStatus? status,
    SshnpdConfigDocument? doc,
    String? savedSource,
    bool? existed,
    String? error,
    String? yamlError,
    bool? showAdvanced,
    bool? saving,
    bool clearError = false,
    bool clearYamlError = false,
  }) {
    return ConfigState(
      status: status ?? this.status,
      doc: doc ?? this.doc,
      savedSource: savedSource ?? this.savedSource,
      existed: existed ?? this.existed,
      error: clearError ? null : error ?? this.error,
      yamlError: clearYamlError ? null : yamlError ?? this.yamlError,
      showAdvanced: showAdvanced ?? this.showAdvanced,
      saving: saving ?? this.saving,
    );
  }

  @override
  List<Object?> get props => [
    status,
    source,
    savedSource,
    existed,
    error,
    yamlError,
    showAdvanced,
    saving,
  ];
}

/// Owns the working copy of sshnpd.yaml for the whole app.
class ConfigCubit extends Cubit<ConfigState> {
  ConfigCubit(this._repo) : super(const ConfigState());

  final ConfigRepository _repo;

  ConfigRepository get repository => _repo;

  Future<void> load() async {
    emit(state.copyWith(status: ConfigStatus.loading, clearError: true));
    try {
      final r = await _repo.load();
      emit(
        ConfigState(
          status: ConfigStatus.ready,
          doc: r.doc,
          savedSource: r.existed ? r.doc.source : null,
          existed: r.existed,
          showAdvanced: state.showAdvanced,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ConfigStatus.error, error: e.toString()));
    }
  }

  void toggleAdvanced([bool? value]) =>
      emit(state.copyWith(showAdvanced: value ?? !state.showAdvanced));

  /// Sets one form field. [value] is already of the right Dart type for the
  /// field kind (String, int, bool, `List<String>` or null).
  void setField(ConfigField field, Object? value) {
    final doc = state.doc;
    if (doc == null) return;
    doc.set(field.path, value);
    emit(state.copyWith(clearYamlError: true));
  }

  /// Convenience used by the wizard and keys import.
  void update(void Function(SshnpdConfigDocument doc) edit) {
    final doc = state.doc;
    if (doc == null) return;
    edit(doc);
    emit(state.copyWith(clearYamlError: true));
  }

  /// Replace the whole document from the raw YAML editor. Invalid YAML is
  /// reported through [ConfigState.yamlError] and leaves the document as is.
  void replaceYaml(String yaml) {
    try {
      final doc = SshnpdConfigDocument.parse(yaml);
      emit(state.copyWith(doc: doc, clearYamlError: true));
    } catch (e) {
      emit(state.copyWith(yamlError: e.toString()));
    }
  }

  /// Returns true on success. Validation problems are exposed through
  /// [ConfigState.problems]; the caller decides whether to show them.
  Future<bool> save({bool force = false}) async {
    final doc = state.doc;
    if (doc == null) return false;
    if (!force && doc.validate().isNotEmpty) return false;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repo.save(doc);
      emit(state.copyWith(saving: false, savedSource: doc.source, existed: true));
      return true;
    } catch (e) {
      emit(state.copyWith(saving: false, error: e.toString()));
      return false;
    }
  }

  void revert() {
    final saved = state.savedSource;
    if (saved == null) {
      load();
      return;
    }
    emit(state.copyWith(doc: SshnpdConfigDocument.parse(saved), clearYamlError: true));
  }
}
