

use std::{
    collections::HashMap,
    env, fs,
    io::Write,
    path::{Path, PathBuf},
    process::Command,
};

use chrono::DateTime;
use reqwest::header;

use crate::{
    types::{
        runtime_types::{PlatformManifestJson, RuntimeListJson},
        CallbackDict, JvmRuntimeInformation, VersionRuntimeInformation,
    },
    utils::helper::{
        check_path_inside_minecraft_directory, get_client_json, get_sha1_hash,
        get_user_agent,
    },
};

const JVM_MANIFEST_URL: &str = "https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json";

fn get_jvm_platform_string() -> String {
    let os = env::consts::OS;
    let arch = env::consts::ARCH;

    match (os, arch) {
        ("windows", "x86") => "windows-x86".to_string(),
        ("windows", "aarch64") => "windows-arm64".to_string(),
        ("windows", _) => "windows-x64".to_string(),
        ("linux", "x86") => "linux-i386".to_string(),
        ("linux", "aarch64") => "linux-arm64".to_string(),
        ("linux", _) => "linux".to_string(),
        ("macos", "aarch64") => "mac-os-arm64".to_string(),
        ("macos", _) => "mac-os".to_string(),
        _ => "gamecore".to_string(),
    }
}

pub fn get_jvm_runtimes() -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let client = reqwest::blocking::Client::new();
    let response = client
        .get(JVM_MANIFEST_URL)
        .header(header::USER_AGENT, get_user_agent())
        .send()?;
    let manifest_data: RuntimeListJson = response.json()?;
    let platform_string = get_jvm_platform_string();
    if let Some(platform_data) = manifest_data.get(&platform_string) {
        let jvm_list: Vec<String> = platform_data.keys().cloned().collect();
        Ok(jvm_list)
    } else {
        Err("Platform not found in manifest".into())
    }
}

pub fn get_installed_jvm_runtimes(minecraft_directory: impl AsRef<Path>) -> Vec<String> {
    let runtime_dir = minecraft_directory.as_ref().join("runtime");
    match fs::read_dir(runtime_dir) {
        Ok(entries) => entries
            .filter_map(|entry| entry.ok().and_then(|e| e.file_name().into_string().ok()))
            .collect(),
        Err(_) => Vec::new(),
    }
}

pub fn install_jvm_runtime(
    jvm_version: &str,
    java_major_version: u32,
    minecraft_directory: impl AsRef<Path>,
    reporter: &mut dyn crate::progress::ProgressReporter,
) -> Result<(), Box<dyn std::error::Error>> {
    let client = reqwest::blocking::Client::new();
    let manifest_data: RuntimeListJson = client
        .get(JVM_MANIFEST_URL)
        .header(header::USER_AGENT, get_user_agent())
        .send()?
        .json()?;
    let platform_string = get_jvm_platform_string();

    let empty_map = HashMap::new();
    let platform_data = manifest_data
        .get(&platform_string)
        .unwrap_or(&empty_map);

    let has_valid_mojang_runtime = platform_data.contains_key(jvm_version) 
        && !platform_data.get(jvm_version).unwrap().is_empty();

    if !has_valid_mojang_runtime {
        return install_zulu_jvm_runtime(java_major_version, jvm_version, minecraft_directory, reporter);
    }

    let platform_manifest_url = platform_data
        .get(jvm_version)
        .unwrap()[0]
        .manifest
        .url
        .clone();
    let platform_manifest: PlatformManifestJson = client
        .get(platform_manifest_url)
        .header(header::USER_AGENT, get_user_agent())
        .send()?
        .json()?;
    let base_path = minecraft_directory
        .as_ref()
        .join("runtime")
        .join(jvm_version)
        .join(&platform_string)
        .join(jvm_version);

    let mut plan = crate::net::download::DownloadPlan::default();
    let mut file_list: Vec<String> = vec![];

    for (key, value) in platform_manifest.files.iter() {
        let current_path = base_path.join(key);
        check_path_inside_minecraft_directory(&minecraft_directory, &current_path)?;
        if let Some(vtype) = &value.r#type {
            if vtype == "file" {
                file_list.push(key.clone());
                if let Some(download_info) = &value.downloads {
                    if download_info.contains_key("lzma") {
                        let info = download_info.get("lzma").unwrap();
                        let raw_info = download_info.get("raw").unwrap();
                        plan.tasks.push(crate::net::download::DownloadTask {
                            url: info.url.clone(),
                            destination: current_path.clone(),
                            checksum: Some(crate::net::download::Checksum::Sha1(raw_info.sha1.clone())),
                            label: format!("jvm {}", key),
                            size: Some(info.size as u64),
                            lzma_compressed: true,
                            executable: value.executable.unwrap_or(false),
                        });
                    } else {
                        let info = download_info.get("raw").unwrap();
                        plan.tasks.push(crate::net::download::DownloadTask {
                            url: info.url.clone(),
                            destination: current_path.clone(),
                            checksum: Some(crate::net::download::Checksum::Sha1(info.sha1.clone())),
                            label: format!("jvm {}", key),
                            size: Some(info.size as u64),
                            lzma_compressed: false,
                            executable: value.executable.unwrap_or(false),
                        });
                    }
                }
            } else if vtype == "directory" {
                let _ = std::fs::create_dir_all(&current_path);
            } else if vtype == "link" {

                #[cfg(unix)]
                {
                    if let Some(target) = value.target.as_ref() {
                        let _ = std::os::unix::fs::symlink(Path::new(target), &current_path);
                    }
                }
            }
        }
    }

    crate::net::download::execute_plan(&plan, reporter)?;

    let version_path = minecraft_directory
        .as_ref()
        .join("runtime")
        .join(jvm_version)
        .join(&platform_string)
        .join(".version");
    check_path_inside_minecraft_directory(&minecraft_directory, &version_path)?;
    let mut version_file = fs::File::create(&version_path)?;
    version_file.write_all(
        manifest_data
            .get(&platform_string)
            .unwrap()
            .get(jvm_version)
            .unwrap()[0]
            .version
            .get("name")
            .unwrap()
            .as_bytes(),
    )?;

    let sha1_path = minecraft_directory
        .as_ref()
        .join("runtime")
        .join(jvm_version)
        .join(platform_string)
        .join(format!("{}.sha1", jvm_version));
    check_path_inside_minecraft_directory(&minecraft_directory, &sha1_path)?;
    let mut sha1_file = fs::File::create(&sha1_path)?;
    for file in file_list {
        let current_path = base_path.join(&file);
        let ctime = current_path.metadata()?.modified()?.elapsed()?.as_nanos(); 
        let sha1 = get_sha1_hash(current_path.to_str().unwrap())?;
        sha1_file.write_all(format!("{} /#// {} {}\n", file, sha1, ctime).as_bytes())?;
    }
    Ok(())
}

pub fn get_executable_path(
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
            #[cfg(unix)]
            {
                let _ = std::process::Command::new("chmod").arg("+x").arg(path).status();
            }
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
                    entry.path().join("Contents").join("Home").join("bin").join("java"),
                ];
                for path in &check_paths {
                    if path.is_file() {
                        #[cfg(unix)]
                        {
                            let _ = std::process::Command::new("chmod").arg("+x").arg(path).status();
                        }
                        return Some(path.clone());
                    }
                }
                
                // Search 1 level deeper for .jre or .jdk folders
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
                                    #[cfg(unix)]
                                    {
                                        let _ = std::process::Command::new("chmod").arg("+x").arg(dp).status();
                                    }
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

pub fn get_jvm_runtime_information(
    jvm_version: &str,
) -> Result<JvmRuntimeInformation, Box<dyn std::error::Error>> {
    let client = reqwest::blocking::Client::new();
    let manifest_data: RuntimeListJson = client
        .get(JVM_MANIFEST_URL)
        .header("user-agent", get_user_agent())
        .send()?
        .json()?;

    let platform_string = get_jvm_platform_string();

    if !manifest_data
        .get(&platform_string)
        .unwrap_or(&HashMap::new())
        .contains_key(jvm_version)
    {
        return Err(format!("jvm version is not found: {}", jvm_version).into());
    }

    if manifest_data
        .get(&platform_string)
        .unwrap()
        .get(jvm_version)
        .unwrap_or(&Vec::new())
        .is_empty()
    {
        return Err(format!("this platform not supported yet.").into());
    }
    let runtime_list_json_entry = manifest_data
        .get(&platform_string)
        .unwrap()
        .get(jvm_version)
        .unwrap();
    Ok(JvmRuntimeInformation {
        name: runtime_list_json_entry[0]
            .version
            .get("name")
            .unwrap()
            .to_string(),
        released: DateTime::parse_from_rfc3339(
            runtime_list_json_entry[0].version.get("released").unwrap(),
        )?
        .into(),
    })
}

pub fn get_version_runtime_information(
    version: &str,
    minecraft_directory: impl AsRef<Path>,
) -> Option<VersionRuntimeInformation> {
    let data = match get_client_json(version, &minecraft_directory) {
        Ok(json_data) => json_data,
        Err(_) => return None,
    };
    
    // Older Minecraft versions (1.12.2 and older) do not have a javaVersion field.
    // They inherently require Java 8 (jre-legacy).
    if data.java_version.is_none() {
        return Some(VersionRuntimeInformation {
            name: "jre-legacy".to_string(),
            java_major_version: 8,
        });
    }

    Some(VersionRuntimeInformation {
        name: data.java_version.clone().unwrap().component,
        java_major_version: data.java_version.clone().unwrap().major_version,
    })
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn debug_get_jvm_platform_string() {
        println!("{}", get_jvm_platform_string());
    }

    #[test]
    fn debug_get_jvm_runtimes() {
        match get_jvm_runtimes() {
            Ok(v) => println!("{:?}", v),
            Err(e) => println!("{}", e.to_string()),
        }
    }
}


fn install_zulu_jvm_runtime(
    java_major_version: u32,
    jvm_version: &str,
    minecraft_directory: impl AsRef<Path>,
    reporter: &mut dyn crate::progress::ProgressReporter,
) -> Result<(), Box<dyn std::error::Error>> {
    // If we already have a valid Java executable, don't redownload it
    if crate::runtime::get_executable_path(jvm_version, &minecraft_directory).is_some() {
        return Ok(());
    }

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
    
    let archive_type = if env::consts::OS == "linux" { "tar.gz" } else { "zip" };
    let url = format!("https://api.azul.com/metadata/v1/zulu/packages?java_version={}&os={}&arch={}&archive_type={}&java_package_type=jre&latest=true&release_status=ga", java_major_version, zulu_os, zulu_arch, archive_type);
    
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
    
    if temp_zip.to_string_lossy().ends_with(".tar.gz") || temp_zip.to_string_lossy().ends_with(".tar") {
        let _ = std::process::Command::new("tar")
            .arg("-xzf")
            .arg(&temp_zip)
            .current_dir(&base_path)
            .status();
    } else {
        crate::io::archive::extract_zip_safely(&temp_zip, &base_path)?;
    }
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
                
                let macos_java_bin_zip = entry.path().join("Contents").join("Home").join("bin").join("java");
                if macos_java_bin_zip.exists() {
                    let mut perms = std::fs::metadata(&macos_java_bin_zip)?.permissions();
                    perms.set_mode(0o755);
                    let _ = std::fs::set_permissions(&macos_java_bin_zip, perms);
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
