use flutter_rust_bridge::frb;
use mc_launcher_core::prelude::*;
use std::path::PathBuf;
use std::cell::RefCell;

thread_local! {
    static JAVA_DOWNLOAD_PROGRESS_CB: RefCell<Option<Box<dyn FnMut(i32)>>> = RefCell::new(None);
}

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

#[derive(Debug, Clone)]
pub enum DartProgressEvent {
    StageStarted { stage: String },
    TaskStarted { label: String, path: String },
    TaskSkipped { label: String, reason: String },
    TaskFinished { label: String },
    BytesReceived { label: String, received: u64, total: Option<u64> },
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

pub fn install_instance(
    minecraft_dir: String,
    version: String,
    loader: DartLoaderSpec,
    progress_sink: crate::frb_generated::StreamSink<DartProgressEvent>,
) -> anyhow::Result<String> {
    let launcher = Launcher::new(PathBuf::from(minecraft_dir.clone()));

    let loader_spec = match loader {
        DartLoaderSpec::Vanilla => None,
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

    // ---- BEGIN MOJANG JAVA INSTALLATION ----
    let _ = progress_sink.add(DartProgressEvent::TaskStarted {
        label: "Resolving Mojang Java Runtime".to_string(),
        path: "".to_string(),
    });

    if let Some(jvm_info) = mc_launcher_core::runtime::get_version_runtime_information(&version, &minecraft_dir) {
        let jvm_version = jvm_info.name; // e.g. "java-runtime-gamma"
        let _ = progress_sink.add(DartProgressEvent::TaskStarted {
            label: format!("Installing {}", jvm_version),
            path: "".to_string(),
        });

        // Setup callbacks for Java downloading
        let sink_clone = progress_sink.clone();
        let jvm_name = jvm_version.clone();
        
        JAVA_DOWNLOAD_PROGRESS_CB.with(|cb| {
            *cb.borrow_mut() = Some(Box::new(move |progress| {
                let _ = sink_clone.add(DartProgressEvent::TaskStarted {
                    label: format!("Extracting {} (File {})", jvm_name, progress),
                    path: "".to_string(),
                });
            }));
        });

        let cb = mc_launcher_core::types::CallbackDict {
            set_max: None,
            set_status: None,
            set_progress: Some(|progress| {
                JAVA_DOWNLOAD_PROGRESS_CB.with(|cb| {
                    if let Some(f) = cb.borrow_mut().as_mut() {
                        f(progress);
                    }
                });
            }),
        };

        if let Err(e) = mc_launcher_core::runtime::install_jvm_runtime(&jvm_version, &minecraft_dir, &cb) {
            println!("Failed to install Mojang JVM: {}", e);
        }
        
        // Clean up the thread-local storage to prevent memory leaks across FFI boundaries
        JAVA_DOWNLOAD_PROGRESS_CB.with(|cb| {
            *cb.borrow_mut() = None;
        });
    }
    // ---- END MOJANG JAVA INSTALLATION ----

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
