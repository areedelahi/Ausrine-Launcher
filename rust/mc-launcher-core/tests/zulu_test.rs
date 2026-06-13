use reqwest::blocking::Client;
use serde_json::Value;

#[test]
fn test_zulu() {
    let client = Client::new();
    let url = "https://api.azul.com/metadata/v1/zulu/packages?java_version=8&os=macos&arch=arm&archive_type=zip&java_package_type=jre&latest=true&release_status=ga";
    let resp: Vec<Value> = client.get(url).send().unwrap().json().unwrap();
    println!("Found {} items", resp.len());
    let pkg = resp.first().unwrap();
    println!("URL: {}", pkg["download_url"].as_str().unwrap());
}
