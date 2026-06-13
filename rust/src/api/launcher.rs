use mc_launcher_core::prelude::*;
use std::path::PathBuf;
use std::process::Command;
use flutter_rust_bridge::frb;

#[frb(non_opaque)]
pub enum LaunchEvent {
    Started { pid: u32 },
    Exited { code: i32 },
}

pub fn launch_instance(
    minecraft_dir: String,
    instance_dir: String,
    version_id: String,
    java_executable: Option<String>,
    jvm_args: Option<String>,
    ram_mb: Option<u32>,
    is_offline: bool,
    account_name: String,
    account_uuid: String,
    account_token: String,
    // Stream events back to Flutter (process start/exit)
    sink: crate::frb_generated::StreamSink<LaunchEvent>,
) -> anyhow::Result<()> {
    let launcher = Launcher::new(PathBuf::from(&minecraft_dir));
    let version = launcher.load_version(&version_id)?;

    // Split auth logic: offline vs Microsoft live auth
    let account = if is_offline {
        Account::Offline {
            username: account_name,
            uuid: account_uuid,
        }
    } else {
        Account::Microsoft {
            username: account_name,
            uuid: account_uuid,
            access_token: account_token,
        }
    };

    let java_path = java_executable.map(PathBuf::from);

    let version_dir = PathBuf::from(&minecraft_dir).join("versions").join(&version_id);
    let natives_dir = version_dir.join("natives");
    let game_dir = PathBuf::from(instance_dir);

    let mut options = LaunchOptions {
        account,
        java_executable: java_path,
        launcher_name: "Ausrine Launcher".to_string(),
        launcher_version: "1.0.0".to_string(),
        natives_directory: Some(natives_dir),
        game_directory: Some(game_dir),
        ..Default::default()
    };

    let mut command = launcher.build_launch_command_from_version(&version, options)?;

    if let Some(ram) = ram_mb {
        let xmx = format!("-Xmx{}M", ram);
        let xms = format!("-Xms{}M", ram);
        command.args.insert(0, xmx);
        command.args.insert(0, xms);
    }

    if let Some(args_str) = jvm_args {

        let parsed_args: Vec<&str> = args_str.split_whitespace().collect();
        for arg in parsed_args.into_iter().rev() {
            command.args.insert(0, arg.to_string());
        }
    }

    #[cfg(target_os = "macos")]
    {
        // Remove quarantine attribute so JVM can execute
        let _ = Command::new("xattr")
            .arg("-r")
            .arg("-d")
            .arg("com.apple.quarantine")
            .arg(&minecraft_dir)
            .status();
    }

    #[cfg(windows)]
    use std::os::windows::process::CommandExt;
    
    #[cfg(windows)]
    let mut cmd = Command::new(&command.executable);
    #[cfg(windows)]
    cmd.args(&command.args)
       .current_dir(&command.working_dir)
       .creation_flags(0x08000000); // CREATE_NO_WINDOW

    #[cfg(not(windows))]
    let mut cmd = Command::new(&command.executable);
    #[cfg(not(windows))]
    {
        use std::os::unix::process::CommandExt;
        cmd.args(&command.args)
           .current_dir(&command.working_dir)
           .process_group(0);
    }

    println!("Executing wrapped: {:?}", cmd);

    let mut child = cmd.spawn()?;

    let pid = child.id();
    let _ = sink.add(LaunchEvent::Started { pid });

    std::thread::spawn(move || {
        let status = child.wait().ok();
        let code = status.and_then(|s| s.code()).unwrap_or(-1);
        let _ = sink.add(LaunchEvent::Exited { code });
    });

    Ok(())
}

pub fn kill_process(pid: u32) {
    #[cfg(unix)]
    unsafe { libc::kill(pid as i32, libc::SIGTERM); }
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x08000000;
        let _ = Command::new("taskkill")
            .args(["/F", "/PID", &pid.to_string()])
            .creation_flags(CREATE_NO_WINDOW)
            .status();
    }
}
