// Synchronous greeting function for early bridge testing
#[flutter_rust_bridge::frb(sync)] 
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

// Initialize Rust utilities needed by flutter_rust_bridge
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Setup default panic handler and other utilities
    flutter_rust_bridge::setup_default_user_utils();
}
