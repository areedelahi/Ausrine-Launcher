use discord_rich_presence::{activity, DiscordIpc, DiscordIpcClient};
use lazy_static::lazy_static;
use std::sync::Mutex;

lazy_static! {
    static ref DISCORD_CLIENT: Mutex<Option<DiscordIpcClient>> = Mutex::new(None);
}

pub fn init_discord_rpc(client_id: String) {
    println!("Trying to connect to Discord RPC with client ID: {}", client_id);
    let mut client = DiscordIpcClient::new(&client_id);
    match client.connect() {
        Ok(_) => {
            println!("Successfully connected to Discord RPC");
            if let Ok(mut guard) = DISCORD_CLIENT.lock() {
                *guard = Some(client);
            }
        }
        Err(e) => {
            println!("Failed to connect to Discord RPC: {:?}", e);
        }
    }
}

pub fn set_discord_presence(state: String, details: String, start_timestamp: i64) {
    if let Ok(mut guard) = DISCORD_CLIENT.lock() {
        if let Some(client) = guard.as_mut() {
            let act = activity::Activity::new()
                .state(&state)
                .details(&details)
                .assets(activity::Assets::new().large_image("icon"))
                .timestamps(activity::Timestamps::new().start(start_timestamp));
            
            let _ = client.set_activity(act);
        }
    }
}

pub fn clear_discord_presence() {
    if let Ok(mut guard) = DISCORD_CLIENT.lock() {
        if let Some(client) = guard.as_mut() {
            let _ = client.clear_activity();
        }
    }
}
