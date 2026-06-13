use mc_launcher_core::loader::forge;

#[test]
fn test_list_forge_versions() {
    let versions = forge::list_forge_versions().unwrap();
    println!("Found {} versions", versions.len());
}
