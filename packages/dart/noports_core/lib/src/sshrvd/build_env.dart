class BuildEnv {
  static final bool enableSnoop =
      bool.fromEnvironment('ENABLE_SNOOP', defaultValue: false);
}
