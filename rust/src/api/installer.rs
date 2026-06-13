use flutter_rust_bridge::frb;
use mc_launcher_core::prelude::*;
use std::path::PathBuf;

#[frb(mirror(InstallStage))]
pub enum _InstallStage {
    ResolveVersion,
    DownloadLibraries,
    DownloadAssets,
    InstallRuntime,
    ExtractNatives,
    LoaderInstall,
    Verify,
}

// Convert Rust progress events to Dart-friendly format for UI display
#[derive(Debug, Clone)]
pub enum DartProgressEvent {
    StageStarted { stage: String },
    TaskStarted { label: String, path: String },
    TaskSkipped { label: String, reason: String },
    TaskFinished { label: String },
    BytesReceived { label: String, received: u64, total: Option<u64> },
    PlanProgress { completed_bytes: u64, total_bytes: u64 },
    InstallComplete { version_id: String },
}

impl From<ProgressEvent> for DartProgressEvent {
    fn from(event: ProgressEvent) -> Self {
        match event {
            ProgressEvent::StageStarted { stage } => DartProgressEvent::StageStarted {
                stage: format!("{:?}", stage),
            },
            ProgressEvent::TaskStarted { label, path } => DartProgressEvent::TaskStarted {
                label,
                path: path.to_string_lossy().to_string(),
            },
            ProgressEvent::TaskSkipped { label, reason } => DartProgressEvent::TaskSkipped {
                label,
                reason: format!("{:?}", reason),
            },
            ProgressEvent::TaskFinished { label } => DartProgressEvent::TaskFinished { label },
            ProgressEvent::BytesReceived { label, received, total } => {
                DartProgressEvent::BytesReceived {
                    label,
                    received,
                    total,
                }
            }
            ProgressEvent::PlanProgress { completed_bytes, total_bytes } => {
                DartProgressEvent::PlanProgress {
                    completed_bytes,
                    total_bytes,
                }
            }
        }
    }
}

pub enum DartLoaderSpec {
    Vanilla,
    Fabric { version: String },
    Forge { version: String },
    Quilt { version: String },
    NeoForge { version: String },
}

// Install game version with optional loader, streaming progress events
pub fn install_instance(
    minecraft_dir: String,
    version: String,
    loader: DartLoaderSpec,
    progress_sink: crate::frb_generated::StreamSink<DartProgressEvent>,
) -> anyhow::Result<String> {
    let launcher = Launcher::new(PathBuf::from(minecraft_dir.clone()));

    let loader_spec = match loader {
        DartLoaderSpec::Vanilla => None,
        // Map Dart enum to mc-launcher-core loader specs
        DartLoaderSpec::Fabric { version } => Some(LoaderSpec::Fabric {
            version: LoaderVersion::Exact(version),
        }),
        DartLoaderSpec::Forge { version } => Some(LoaderSpec::Forge {
            version: LoaderVersion::Exact(version),
        }),
        DartLoaderSpec::Quilt { version } => Some(LoaderSpec::Quilt {
            version: LoaderVersion::Exact(version),
        }),
        DartLoaderSpec::NeoForge { version } => Some(LoaderSpec::NeoForge {
            version: LoaderVersion::Exact(version),
        }),
    };

    let request = InstallRequest {
        minecraft_version: version.clone(),
        loader: loader_spec,
        java: JavaInstallPolicy::Auto,
    };

    let mut reporter = |event: ProgressEvent| {
        let _ = progress_sink.add(event.into());
    };

    let install_result = launcher.install_with_progress(request, &mut reporter)?;

    let _ = progress_sink.add(DartProgressEvent::InstallComplete {
        version_id: install_result.version_id.clone(),
    });

    Ok(install_result.version_id)
}

pub fn get_java_executable_path(minecraft_dir: String, version_id: String) -> Option<String> {
    if let Some(jvm_info) = mc_launcher_core::runtime::get_version_runtime_information(&version_id, &minecraft_dir) {
        if let Some(path) = mc_launcher_core::runtime::get_executable_path(&jvm_info.name, &minecraft_dir) {
            return Some(path.to_string_lossy().to_string());
        }
    }
    None
}
