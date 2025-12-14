// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
// use std::io::Stdout;

use tauri::Manager;

#[tauri::command]
fn get_parent_dir(path: String) -> Result<String, String> {
    let mut dir = std::path::Path::new(&path)
        .parent()
        .and_then(|p| p.to_str())
        .map(|s| s.to_string())
        .ok_or("Failed to get parent directory".to_string())?;

    if !dir.ends_with('\\') && !dir.ends_with('/') {
        dir.push(std::path::MAIN_SEPARATOR);
    }

    Ok(dir)
}

#[tauri::command]
fn read_config(app: tauri::AppHandle) -> Result<serde_json::Value, String> {
    let config_path: std::path::PathBuf = app
        .path()
        .app_config_dir()
        .map_err(|e: tauri::Error| e.to_string())?
        .join("config.json");

    let content: String =
        std::fs::read_to_string(&config_path).map_err(|e: std::io::Error| e.to_string())?;
    serde_json::from_str(&content).map_err(|e: serde_json::Error| e.to_string())
}

#[tauri::command]
fn write_config(app: tauri::AppHandle, config: serde_json::Value) -> Result<(), String> {
    let config_dir: std::path::PathBuf = app
        .path()
        .app_config_dir()
        .map_err(|e: tauri::Error| e.to_string())?;
    std::fs::create_dir_all(&config_dir).map_err(|e: std::io::Error| e.to_string())?;

    let config_path: std::path::PathBuf = config_dir.join("config.json");
    std::fs::write(&config_path, config.to_string()).map_err(|e: std::io::Error| e.to_string())
}

#[tauri::command]
fn read_file(file_path: String) -> Result<String, String> {
    std::fs::read_to_string(&file_path).map_err(|e| e.to_string())
}

#[tauri::command]
fn write_file(file_path: String, contents: String) -> Result<String, String> {
    std::fs::write(&file_path, contents)
        .map(|_| "File written successfully".to_string())
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn query_typst(file_path: String, output_dir: String) -> Result<String, String> {
    use std::fs;
    use std::process::Command;

    // Run typst query command
    let output: std::process::Output = Command::new("typst")
        .args(&[
            "query",
            &file_path,
            "<problems-state>",
            "--one",
            "--field",
            "value",
        ])
        .output()
        .map_err(|e: std::io::Error| e.to_string())?;

    if !output.status.success() {
        let stderr: std::borrow::Cow<'_, str> = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Typst query failed: {}", stderr));
    }

    let stdout: String =
        String::from_utf8(output.stdout).map_err(|e: std::string::FromUtf8Error| e.to_string())?;

    // Write to JSON file
    let json_path: String = format!("{}problems.json", output_dir);
    fs::write(&json_path, &stdout).map_err(|e| e.to_string())?;

    Ok(stdout)
}

#[tauri::command]
fn compile_typst(
    input_file: String,
    output_file: String,
    args: Vec<String>,
) -> Result<String, String> {
    use std::process::Command;

    let mut cmd = Command::new("typst");
    let mut cmd_display = format!("typst compile \"{}\" \"{}\"", &input_file, &output_file);

    cmd.args(&["compile", &input_file, &output_file]);

    for arg in args {
        cmd.arg("--input").arg(&arg);
        cmd_display.push_str(&format!(" --input {}", &arg));
    }
    println!("Running: {}", cmd_display);

    let output = cmd.output().map_err(|e: std::io::Error| e.to_string())?;

    if !output.status.success() {
        let stderr: std::borrow::Cow<'_, str> = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Typst compile failed: {}", stderr));
    }

    let stdout = String::from_utf8(output.stdout).map_err(|e| e.to_string())?;

    Ok(stdout)
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            query_typst,
            compile_typst,
            get_parent_dir,
            read_config,
            write_config,
            read_file,
            write_file
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
