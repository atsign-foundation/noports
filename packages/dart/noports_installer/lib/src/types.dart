enum PlatformArch { x64, arm64, armv7, riscv }

enum BinaryLanguage {
  dart(100),
  c(50);

  final int priority;
  const BinaryLanguage(this.priority);
}
