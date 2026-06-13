#![allow(non_snake_case)]

use serde::{Deserialize, Serialize};
use reqwest::Client;
use std::time::Duration;
use tokio::time::sleep;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceCodeInfo {
    pub user_code: String,
    pub device_code: String,
    pub verification_uri: String,
    pub expires_in: u64,
    pub interval: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MinecraftAccount {
    pub uuid: String,
    pub username: String,
    pub access_token: String,
}

// Azure app registration ID for Microsoft OAuth device flow
const CLIENT_ID: &str = "00000000402b5328"; 

#[derive(Deserialize)]
struct DeviceCodeResponse {
    user_code: String,
    device_code: String,
    verification_uri: String,
    expires_in: u64,
    interval: u64,
}

pub async fn request_device_code() -> anyhow::Result<DeviceCodeInfo> {
    let client = Client::new();
    let res = client.post("https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")
        .form(&[
            ("client_id", CLIENT_ID),
            ("scope", "XboxLive.signin offline_access"),
        ])
        .send()
        .await?
        .json::<DeviceCodeResponse>()
        .await?;

    Ok(DeviceCodeInfo {
        user_code: res.user_code,
        device_code: res.device_code,
        verification_uri: res.verification_uri,
        expires_in: res.expires_in,
        interval: res.interval,
    })
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: Option<String>,
    error: Option<String>,
}

#[derive(Serialize)]
struct XboxLiveAuthRequest {
    Properties: XboxLiveProperties,
    RelyingParty: String,
    TokenType: String,
}

#[derive(Serialize)]
struct XboxLiveProperties {
    AuthMethod: String,
    SiteName: String,
    RpsTicket: String,
}

#[derive(Deserialize)]
struct XboxAuthResponse {
    Token: String,
    DisplayClaims: DisplayClaims,
}

#[derive(Deserialize)]
struct DisplayClaims {
    xui: Vec<Xui>,
}

#[derive(Deserialize)]
struct Xui {
    uhs: String,
}

#[derive(Serialize)]
struct XstsAuthRequest {
    Properties: XstsProperties,
    RelyingParty: String,
    TokenType: String,
}

#[derive(Serialize)]
struct XstsProperties {
    SandboxId: String,
    UserTokens: Vec<String>,
}

#[derive(Serialize)]
struct MinecraftAuthRequest {
    identityToken: String,
}

#[derive(Deserialize)]
struct MinecraftAuthResponse {
    access_token: String,
}

#[derive(Deserialize)]
struct MinecraftProfileResponse {
    id: String,
    name: String,
}

// Multi-step OAuth flow: device code -> MSA token -> Xbox Live -> XSTS -> Minecraft auth
pub async fn poll_for_token_and_login(device_code: String, interval: u64) -> anyhow::Result<MinecraftAccount> {
    let client = Client::new();

    let mut msa_token = String::new();

    // Poll Microsoft endpoint until user completes auth on device
    loop {
        let res = client.post("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
            .form(&[
                ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
                ("client_id", CLIENT_ID),
                ("device_code", &device_code),
            ])
            .send()
            .await?
            .json::<TokenResponse>()
            .await?;

        if let Some(token) = res.access_token {
            msa_token = token;
            break;
        } else if let Some(error) = res.error {
            if error != "authorization_pending" {
                return Err(anyhow::anyhow!("MSA Token Error: {}", error));
            }
        }
        // Wait before retrying to avoid rate limits
        sleep(Duration::from_secs(interval)).await;
    }

    let xbl_req = XboxLiveAuthRequest {
        Properties: XboxLiveProperties {
            AuthMethod: "RPS".to_string(),
            SiteName: "user.auth.xboxlive.com".to_string(),
            RpsTicket: format!("d={}", msa_token),
        },
        RelyingParty: "http://auth.xboxlive.com".to_string(),
        TokenType: "JWT".to_string(),
    };

    let xbl_res = client.post("https://user.auth.xboxlive.com/user/authenticate")
        .json(&xbl_req)
        .send()
        .await?
        .json::<XboxAuthResponse>()
        .await?;

    let xsts_req = XstsAuthRequest {
        Properties: XstsProperties {
            SandboxId: "RETAIL".to_string(),
            UserTokens: vec![xbl_res.Token.clone()],
        },
        RelyingParty: "rp://api.minecraftservices.com/".to_string(),
        TokenType: "JWT".to_string(),
    };

    let xsts_res = client.post("https://xsts.auth.xboxlive.com/xsts/authorize")
        .json(&xsts_req)
        .send()
        .await?;

    if !xsts_res.status().is_success() {
         return Err(anyhow::anyhow!("XSTS Auth failed. You might not have a Minecraft account."));
    }

    let xsts_res = xsts_res.json::<XboxAuthResponse>().await?;

    let uhs = xsts_res.DisplayClaims.xui.get(0)
        .map(|x| x.uhs.clone())
        .unwrap_or_default();

    let mc_req = MinecraftAuthRequest {
        identityToken: format!("XBL3.0 x={};{}", uhs, xsts_res.Token),
    };

    let mc_res = client.post("https://api.minecraftservices.com/authentication/login_with_xbox")
        .json(&mc_req)
        .send()
        .await?
        .json::<MinecraftAuthResponse>()
        .await?;

    let profile_res = client.get("https://api.minecraftservices.com/minecraft/profile")
        .header("Authorization", format!("Bearer {}", mc_res.access_token))
        .send()
        .await?
        .json::<MinecraftProfileResponse>()
        .await?;

    Ok(MinecraftAccount {
        uuid: profile_res.id,
        username: profile_res.name,
        access_token: mc_res.access_token,
    })
}
