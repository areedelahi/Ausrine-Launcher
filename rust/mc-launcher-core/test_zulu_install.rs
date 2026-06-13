use std::collections::HashMap;

fn get_zulu_os() -> &'static str {
    match std::env::consts::OS {
        "macos" => "macos",
        "windows" => "windows",
        "linux" => "linux",
        _ => "unknown",
    }
}

fn get_zulu_arch() -> &'static str {
    match std::env::consts::ARCH {
        "aarch64" => "arm",
        "x86_64" => "x86",
        _ => "unknown",
    }
}

fn main() {
    println!("zulu os: {}, arch: {}", get_zulu_os(), get_zulu_arch());
}
