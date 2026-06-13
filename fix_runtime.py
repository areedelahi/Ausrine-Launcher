import sys

with open('rust/mc-launcher-core/src/runtime/mod.rs', 'r') as f:
    content = f.read()

# 1. Update signature of install_jvm_runtime
content = content.replace('pub fn install_jvm_runtime(\n    jvm_version: &str,\n    minecraft_directory: impl AsRef<Path>,\n    reporter: &mut dyn crate::progress::ProgressReporter,\n) -> Result<(), Box<dyn std::error::Error>> {', 
'''pub fn install_jvm_runtime(
    jvm_version: &str,
    java_major_version: u32,
    minecraft_directory: impl AsRef<Path>,
    reporter: &mut dyn crate::progress::ProgressReporter,
) -> Result<(), Box<dyn std::error::Error>> {''')

# 2. Add Zulu fallback inside install_jvm_runtime
fallback_logic = '''
    if !manifest_data
        .get(&platform_string)
        .unwrap_or(&HashMap::new())
        .contains_key(jvm_version)
    {
        return install_zulu_jvm_runtime(java_major_version, jvm_version, minecraft_directory, reporter);
    }
'''
content = content.replace('''
    if !manifest_data
        .get(&platform_string)
        .unwrap_or(&HashMap::new())
        .contains_key(jvm_version)
    {
        return Err(format!("jvm version not found: {}", jvm_version).into());
    }''', fallback_logic)

# 3. Add install_zulu_jvm_runtime function at the end of the file
zulu_fn = '''
fn install_zulu_jvm_runtime(
    java_major_version: u32,
    jvm_version: &str,
    minecraft_directory: impl AsRef<Path>,
    reporter: &mut dyn crate::progress::ProgressReporter,
) -> Result<(), Box<dyn std::error::Error>> {
    use reqwest::blocking::Client;
    use serde_json::Value;
    
    let zulu_os = match env::consts::OS {
        "macos" => "macos",
        "windows" => "windows",
        "linux" => "linux",
        _ => return Err("Unsupported OS for Zulu fallback".into()),
    };
    
    let zulu_arch = match env::consts::ARCH {
        "aarch64" => "arm",
        "x86_64" => "x86",
        _ => return Err("Unsupported architecture for Zulu fallback".into()),
    };
    
    let url = format!("https://api.azul.com/metadata/v1/zulu/packages?java_version={}&os={}&arch={}&archive_type=zip&java_package_type=jre&latest=true&release_status=ga", java_major_version, zulu_os, zulu_arch);
    
    let client = Client::new();
    let resp: Vec<Value> = client.get(&url).send()?.json()?;
    
    let pkg = resp.first().ok_or("Azul Zulu JRE not found for this architecture and Java version.")?;
    let download_url = pkg["download_url"].as_str().ok_or("Missing Zulu download_url")?.to_string();
    let filename = pkg["name"].as_str().unwrap_or("zulu.zip").to_string();
    
    let platform_string = get_jvm_platform_string();
    let base_path = minecraft_directory
        .as_ref()
        .join("runtime")
        .join(jvm_version)
        .join(&platform_string)
        .join(jvm_version);
        
    std::fs::create_dir_all(&base_path)?;
    
    let temp_zip = base_path.join(&filename);
    
    let mut plan = crate::net::download::DownloadPlan::default();
    plan.tasks.push(crate::net::download::DownloadTask {
        url: download_url.clone(),
        destination: temp_zip.clone(),
        checksum: None,
        label: format!("Azul Zulu Java {} for {}", java_major_version, platform_string),
        size: None,
        lzma_compressed: false,
        executable: false,
    });
    
    crate::net::download::execute_plan(&plan, reporter)?;
    
    crate::io::archive::extract_zip_safely(&temp_zip, &base_path)?;
    let _ = std::fs::remove_file(&temp_zip);
    
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if let Ok(entries) = std::fs::read_dir(&base_path) {
            for entry in entries.flatten() {
                let java_bin = entry.path().join("bin").join("java");
                if java_bin.exists() {
                    let mut perms = std::fs::metadata(&java_bin)?.permissions();
                    perms.set_mode(0o755);
                    let _ = std::fs::set_permissions(&java_bin, perms);
                }
                
                // macOS bundle support
                let macos_java_bin = entry.path().join("zulu-8.jre").join("Contents").join("Home").join("bin").join("java");
                if macos_java_bin.exists() {
                    let mut perms = std::fs::metadata(&macos_java_bin)?.permissions();
                    perms.set_mode(0o755);
                    let _ = std::fs::set_permissions(&macos_java_bin, perms);
                }
            }
        }
    }
    
    let version_path = minecraft_directory
        .as_ref()
        .join("runtime")
        .join(jvm_version)
        .join(&platform_string)
        .join(".version");
    let mut version_file = fs::File::create(&version_path)?;
    version_file.write_all(format!("zulu-{}-{}", java_major_version, zulu_arch).as_bytes())?;
    
    Ok(())
}
'''
if 'fn install_zulu_jvm_runtime' not in content:
    content += '\n' + zulu_fn

# 4. Update get_executable_path to dynamically find java inside extracted folders
exec_path_new = '''pub fn get_executable_path(
    jvm_version: &str,
    minecraft_directory: impl AsRef<Path>,
) -> Option<PathBuf> {
    let base_dir = minecraft_directory
        .as_ref()
        .join("runtime")
        .join(jvm_version)
        .join(get_jvm_platform_string())
        .join(jvm_version);

    // Common standard paths
    let standard_paths = [
        base_dir.join("bin").join("java"),
        base_dir.join("bin").join("java.exe"),
        base_dir.join("jre.bundle").join("Contents").join("Home").join("bin").join("java"),
    ];

    for path in &standard_paths {
        if path.is_file() {
            return Some(path.clone());
        }
    }

    // Zulu paths (it extracts to a subfolder)
    if let Ok(entries) = std::fs::read_dir(&base_dir) {
        for entry in entries.flatten() {
            if entry.path().is_dir() {
                let check_paths = [
                    entry.path().join("bin").join("java"),
                    entry.path().join("bin").join("java.exe"),
                    entry.path().join("zulu-8.jre").join("Contents").join("Home").join("bin").join("java"),
                ];
                for path in &check_paths {
                    if path.is_file() {
                        return Some(path.clone());
                    }
                }
            }
        }
    }

    None
}'''
content = content.split('pub fn get_executable_path(')[0] + exec_path_new + '\n\n' + content.split('pub fn get_jvm_runtime_information(')[1]
content = content.replace('pub fn get_jvm_runtime_information(', 'pub fn get_jvm_runtime_information(') # fix split

with open('rust/mc-launcher-core/src/runtime/mod.rs', 'w') as f:
    f.write(content)
