

use std::path::Path;

use crate::{
    core::{
        rules::{evaluate_rules, FeatureSet},
        version::{Library, LibraryArtifact},
    },
    net::download::{Checksum, DownloadTask},
    platform::Platform,
    Result,
};

pub fn plan_library_downloads(
    libraries: &[Library],
    minecraft_dir: &Path,
) -> Result<Vec<DownloadTask>> {
    plan_library_downloads_for_platform(libraries, minecraft_dir, Platform::current())
}

pub fn plan_library_downloads_for_platform(
    libraries: &[Library],
    minecraft_dir: &Path,
    platform: Platform,
) -> Result<Vec<DownloadTask>> {
    let mut tasks = Vec::new();
    for library in libraries {
        if !evaluate_rules(&library.rules, platform, &FeatureSet::default()) {
            continue;
        }
        if let Some(downloads) = &library.downloads {
            if let Some(artifact) = &downloads.artifact {
                tasks.push(download_task(library, artifact, minecraft_dir));
            }
            if let Some(classifier) = native_classifier(library, platform) {
                if let Some(artifact) = downloads.classifiers.get(&classifier) {
                    tasks.push(download_task(library, artifact, minecraft_dir));
                }
            }
        } else if let Some(base_url) = &library.url {
            if let Ok(coord) = crate::core::maven::MavenCoordinate::parse(&library.name) {
                let path = coord.artifact_path();
                let base_url = if base_url.ends_with('/') { base_url.clone() } else { format!("{}/", base_url) };
                let url = format!("{}{}", base_url, path.to_string_lossy());
                tasks.push(DownloadTask {
                    url,
                    destination: minecraft_dir.join("libraries").join(&path),
                    checksum: None,
                    label: library.name.clone(),
                    size: None,
                    lzma_compressed: false,
                    executable: false,
                });
            }
        }
    }
    Ok(tasks)
}

fn download_task(
    library: &Library,
    artifact: &LibraryArtifact,
    minecraft_dir: &Path,
) -> DownloadTask {
    DownloadTask {
        url: artifact.url.clone(),
        destination: minecraft_dir.join("libraries").join(&artifact.path),
        checksum: Some(Checksum::Sha1(artifact.sha1.clone())),
        label: library.name.clone(),
        size: Some(artifact.size as u64),
        lzma_compressed: false,
        executable: false,
    }
}

fn native_classifier(library: &Library, platform: Platform) -> Option<String> {
    library
        .natives
        .as_ref()?
        .get(platform.minecraft_os_name())
        .map(|classifier| {
            classifier.replace("${arch}", if platform.is_32_bit() { "32" } else { "64" })
        })
}
