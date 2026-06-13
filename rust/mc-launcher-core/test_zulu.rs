fn main() {
    let client = reqwest::blocking::Client::new();
    let url = "https://api.azul.com/metadata/v1/zulu/packages?java_version=8&os=macos&arch=arm&archive_type=zip&java_package_type=jre&latest=true&release_status=ga";
    let resp: Result<Vec<serde_json::Value>, _> = client.get(url).send().unwrap().json();
    match resp {
        Ok(v) => println!("Success: {}", v.len()),
        Err(e) => println!("Error: {}", e),
    }
}
