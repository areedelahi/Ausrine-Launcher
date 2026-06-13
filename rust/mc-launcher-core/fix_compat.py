import sys

with open('rust/mc-launcher-core/src/compatibility/mod.rs', 'r') as f:
    content = f.read()

# Add generic ARM64 patching logic for Windows and Linux LWJGL 2 and 3
arm64_generic_logic = '''
fn needs_linux_arm64_lwjgl3_patch(version: &VersionJson, platform: Platform) -> bool {
    platform.os == Os::Linux && platform.arch == Arch::Aarch64 && version.libraries.iter().any(|library| library.name.starts_with("org.lwjgl:"))
}

fn needs_windows_arm64_lwjgl3_patch(version: &VersionJson, platform: Platform) -> bool {
    platform.os == Os::Windows && platform.arch == Arch::Aarch64 && version.libraries.iter().any(|library| library.name.starts_with("org.lwjgl:"))
}

fn needs_linux_arm64_lwjgl2_patch(version: &VersionJson, platform: Platform) -> bool {
    platform.os == Os::Linux && platform.arch == Arch::Aarch64 && version.libraries.iter().any(|library| library.name.starts_with("org.lwjgl.lwjgl:lwjgl:"))
}

fn needs_windows_arm64_lwjgl2_patch(version: &VersionJson, platform: Platform) -> bool {
    platform.os == Os::Windows && platform.arch == Arch::Aarch64 && version.libraries.iter().any(|library| library.name.starts_with("org.lwjgl.lwjgl:lwjgl:"))
}

fn apply_generic_arm64_lwjgl_patch(version: &VersionJson, target_os: &str) -> VersionJson {
    let mut patched = version.clone();
    for library in patched.libraries.iter_mut() {
        if library.name.starts_with("org.lwjgl:") || library.name.starts_with("org.lwjgl.lwjgl:") {
            if let Some(natives) = &mut library.natives {
                if let Some(classifier) = natives.get_mut(target_os) {
                    let old_classifier = classifier.clone();
                    let new_classifier = format!("{}-arm64", old_classifier);
                    *classifier = new_classifier.clone();

                    if let Some(downloads) = &mut library.downloads {
                        if let Some(artifact) = downloads.classifiers.remove(&old_classifier) {
                            let new_path = artifact.path.replace(&old_classifier, &new_classifier);
                            // We construct a fallback maven URL assuming they exist there or officially.
                            let new_url = format!("https://libraries.minecraft.net/{}", new_path);
                            downloads.classifiers.insert(new_classifier, crate::core::version::LibraryArtifact {
                                url: new_url,
                                path: new_path,
                                sha1: String::new(),
                                size: 0,
                            });
                        }
                    }
                }
            }
        }
    }
    patched
}
'''
if 'fn apply_generic_arm64_lwjgl_patch' not in content:
    content += '\n' + arm64_generic_logic

apply_logic = '''
    if needs_linux_arm64_lwjgl3_patch(version, platform) || needs_linux_arm64_lwjgl2_patch(version, platform) {
        return CompatibilityResult {
            version: apply_generic_arm64_lwjgl_patch(version, "linux"),
            applied_patches: vec![CompatibilityPatch::MacArm64Lwjgl3], // Reusing patch enum for simplicity
            java_runtime: Some(JavaRuntimeHint {
                major_version: version.java_version.as_ref().map(|java| java.major_version).unwrap_or(8),
                arch: Arch::Aarch64,
                distribution_hint: "arm64 Java runtime matching version.json javaVersion",
                reason: "Minecraft versions need arm64 Linux native libraries on AArch64.",
            }),
            windowing: current_process_windowing_hint(),
        };
    }

    if needs_windows_arm64_lwjgl3_patch(version, platform) || needs_windows_arm64_lwjgl2_patch(version, platform) {
        return CompatibilityResult {
            version: apply_generic_arm64_lwjgl_patch(version, "windows"),
            applied_patches: vec![CompatibilityPatch::MacArm64Lwjgl3], // Reusing patch enum for simplicity
            java_runtime: Some(JavaRuntimeHint {
                major_version: version.java_version.as_ref().map(|java| java.major_version).unwrap_or(8),
                arch: Arch::Aarch64,
                distribution_hint: "arm64 Java runtime matching version.json javaVersion",
                reason: "Minecraft versions need arm64 Windows native libraries on Snapdragon.",
            }),
            windowing: current_process_windowing_hint(),
        };
    }
'''

content = content.replace('CompatibilityResult {', apply_logic + '\n    CompatibilityResult {', 1)

with open('rust/mc-launcher-core/src/compatibility/mod.rs', 'w') as f:
    f.write(content)

