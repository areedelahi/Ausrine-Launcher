use std::path::PathBuf;

fn get_jvm_platform_string() -> &'static str {
    "mac-os-arm64"
}

pub fn get_executable_path(
    jvm_version: &str,
    minecraft_directory: impl AsRef<std::path::Path>,
) -> Option<PathBuf> {
    let base_dir = minecraft_directory
        .as_ref()
        .join("runtime")
        .join(jvm_version)
        .join(get_jvm_platform_string())
        .join(jvm_version);

    if let Ok(entries) = std::fs::read_dir(&base_dir) {
        for entry in entries.flatten() {
            if entry.path().is_dir() {
                let check_paths = [
                    entry.path().join("bin").join("java"),
                    entry.path().join("bin").join("java.exe"),
                    entry.path().join("Contents").join("Home").join("bin").join("java"),
                ];
                for path in &check_paths {
                    if path.is_file() {
                        return Some(path.clone());
                    }
                }
                
                if let Ok(sub_entries) = std::fs::read_dir(entry.path()) {
                    for sub in sub_entries.flatten() {
                        if sub.path().is_dir() {
                            let deep_paths = [
                                sub.path().join("Contents").join("Home").join("bin").join("java"),
                                sub.path().join("bin").join("java"),
                                sub.path().join("bin").join("java.exe"),
                            ];
                            for dp in &deep_paths {
                                if dp.is_file() {
                                    return Some(dp.clone());
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    None
}

fn main() {
    let path = get_executable_path("java-runtime-alpha", "/Users/areedelahi/Documents/mc");
    println!("Found Java path: {:?}", path);
}
