class BuildEnv {
  static final bool enableSnoop =
      const bool.fromEnvironment('ENABLE_SNOOP', defaultValue: false);
}
