class AppSettings {
  final int minMemoryMb;
  final int maxMemoryMb;
  final String? javaExecutable;
  final String? jvmArgs;
  final bool closeOnLaunch;
  final String? customDataDirectory;

  const AppSettings({
    this.minMemoryMb = 512,
    this.maxMemoryMb = 4096,
    this.javaExecutable,
    this.jvmArgs,
    this.closeOnLaunch = false,
    this.customDataDirectory,
  });

  AppSettings copyWith({
    int? minMemoryMb,
    int? maxMemoryMb,
    bool clearJavaExecutable = false,
    String? javaExecutable,
    bool clearJvmArgs = false,
    String? jvmArgs,
    bool? closeOnLaunch,
    bool clearCustomDataDirectory = false,
    String? customDataDirectory,
  }) {
    return AppSettings(
      minMemoryMb: minMemoryMb ?? this.minMemoryMb,
      maxMemoryMb: maxMemoryMb ?? this.maxMemoryMb,
      javaExecutable: clearJavaExecutable ? null : (javaExecutable ?? this.javaExecutable),
      jvmArgs: clearJvmArgs ? null : (jvmArgs ?? this.jvmArgs),
      closeOnLaunch: closeOnLaunch ?? this.closeOnLaunch,
      customDataDirectory: clearCustomDataDirectory ? null : (customDataDirectory ?? this.customDataDirectory),
    );
  }
}
