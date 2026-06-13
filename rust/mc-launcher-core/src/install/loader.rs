

use std::{
    fs,
    path::{Path, PathBuf},
    process::Command,
};

use crate::{core::version::VersionJson, loader::LoaderKind, LauncherError, Result};

pub fn loader_profile_path(minecraft_dir: impl AsRef<Path>, version_id: &str) -> PathBuf {
    minecraft_dir
        .as_ref()
        .join("versions")
        .join(version_id)
        .join(format!("{version_id}.json"))
}

pub fn write_loader_profile(
    minecraft_dir: impl AsRef<Path>,
    profile: &VersionJson,
) -> Result<PathBuf> {
    let version_id = profile
        .id
        .as_deref()
        .ok_or_else(|| LauncherError::MissingField {
            context: "loader profile".to_string(),
            field: "id".to_string(),
        })?;
    let path = loader_profile_path(minecraft_dir, version_id);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(&path, serde_json::to_vec_pretty(profile)?)?;
    Ok(path)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InstallerInvocation {

    pub loader: LoaderKind,

    pub java_executable: PathBuf,

    pub installer_path: PathBuf,

    pub minecraft_dir: PathBuf,
}

pub fn installer_command_args(invocation: &InstallerInvocation) -> Vec<String> {
    vec![
        "-jar".to_string(),
        invocation.installer_path.to_string_lossy().to_string(),
        "--installClient".to_string(),
        invocation.minecraft_dir.to_string_lossy().to_string(),
    ]
}

pub fn run_loader_installer(invocation: &InstallerInvocation) -> Result<()> {

    let profiles_path = invocation.minecraft_dir.join("launcher_profiles.json");
    if !profiles_path.exists() {
        if let Some(parent) = profiles_path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&profiles_path, "{\"profiles\":{}}")?;
    }

    let status = Command::new(&invocation.java_executable)
        .args(installer_command_args(invocation))
        .status()
        .map_err(|e| {
            if e.kind() == std::io::ErrorKind::NotFound {
                std::io::Error::new(
                    std::io::ErrorKind::NotFound,
                    format!("Java executable not found at {:?}. Please install Java.", invocation.java_executable),
                )
            } else {
                e
            }
        })?;

    if status.success() {
        Ok(())
    } else {
        // If it failed, it might be a legacy installer (e.g. 1.12.2) that doesn't support --installClient.
        // Let's try --extract to get the install_profile.json.
        let temp_dir = tempfile::tempdir()?;
        let extract_status = Command::new(&invocation.java_executable)
            .arg("-jar")
            .arg(&invocation.installer_path)
            .arg("--extract")
            .current_dir(temp_dir.path())
            .status()?;

        if extract_status.success() {
            let profile_path = temp_dir.path().join("install_profile.json");
            if profile_path.exists() {
                if let Ok(profile_content) = fs::read_to_string(&profile_path) {
                    if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&profile_content) {
                        if let Some(version_info) = parsed.get("versionInfo") {
                            if let Some(id) = version_info.get("id").and_then(|v| v.as_str()) {
                                let versions_dir = invocation.minecraft_dir.join("versions").join(id);
                                fs::create_dir_all(&versions_dir)?;
                                let target_json = versions_dir.join(format!("{}.json", id));
                                fs::write(&target_json, serde_json::to_string_pretty(version_info)?)?;
                                
                                // Also need to copy the universal jar into the libraries folder
                                if let Some(install) = parsed.get("install") {
                                    if let (Some(path), Some(file_path)) = (install.get("path").and_then(|v| v.as_str()), install.get("filePath").and_then(|v| v.as_str())) {
                                        // path is like "net.minecraftforge:forge:1.12.1-14.22.0.2444"
                                        let parts: Vec<&str> = path.split(':').collect();
                                        if parts.len() == 3 {
                                            let domain = parts[0].replace('.', "/");
                                            let name = parts[1];
                                            let version = parts[2];
                                            let lib_dir = invocation.minecraft_dir.join("libraries").join(domain).join(name).join(version);
                                            fs::create_dir_all(&lib_dir)?;
                                            let lib_file = lib_dir.join(format!("{}-{}.jar", name, version));
                                            
                                            let extracted_jar = temp_dir.path().join(file_path);
                                            if extracted_jar.exists() {
                                                fs::copy(&extracted_jar, &lib_file)?;
                                            }
                                        }
                                    }
                                }
                                return Ok(());
                            }
                        }
                    }
                }
            }
        }

        Err(LauncherError::InstallerFailed {
            loader: invocation.loader,
            status: status.code(),
        })
    }
}
