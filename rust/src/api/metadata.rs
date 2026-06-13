use flutter_rust_bridge::frb;
use mc_launcher_core::loader;
use serde::{Deserialize, Serialize};

// Fetch available Minecraft versions from official Mojang metadata
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct VanillaVersion {
    pub id: String,
    #[serde(rename = "type")]
    pub version_type: String,
}

#[derive(Debug, Deserialize)]
struct VanillaManifest {
    versions: Vec<VanillaVersion>,
}

pub fn get_vanilla_versions() -> anyhow::Result<Vec<VanillaVersion>> {
    // Fetch official version manifest from Mojang servers
    let manifest: VanillaManifest = reqwest::blocking::get("https://launchermeta.mojang.com/mc/game/version_manifest_v2.json")?.json()?;
    Ok(manifest.versions)
}

pub fn get_fabric_loaders() -> anyhow::Result<Vec<String>> {
    let loaders = loader::fabric::list_loader_versions()?;
    Ok(loaders.into_iter().map(|l| l.version).collect())
}

pub fn get_quilt_loaders() -> anyhow::Result<Vec<String>> {
    let loaders = loader::quilt::list_loader_versions()?;
    Ok(loaders.into_iter().map(|l| l.version).collect())
}

pub fn get_forge_versions() -> anyhow::Result<Vec<String>> {
    loader::forge::list_forge_versions().map_err(Into::into)
}

pub fn get_neoforge_versions() -> anyhow::Result<Vec<String>> {
    loader::neoforge::list_neoforge_versions().map_err(Into::into)
}
