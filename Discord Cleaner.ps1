# Define the Discord folder (assuming script is run from %localappdata%\Discord)
$discordPath = Get-Location
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Cleaning Discord in: $discordPath"
Write-Host "Script running from: $scriptPath"

# Define module folders to keep
$keepModules = @(
    "discord_desktop_core-1",
    "discord_krisp-1",
    "discord_media-1",
    "discord_modules-1",
    "discord_utils-1",
    "discord_voice-1"
)

# Find all app-* directories (e.g., app-1.0.9010)
$appDirs = Get-ChildItem -Path $discordPath -Directory -Filter "app-*"

# Track the latest Discord executable for shortcut creation
$latestDiscordExe = $null
$latestVersion = $null
$latestAppDir = $null

# First pass: Find the latest version with Discord.exe
foreach ($app in $appDirs) {
    $discordExe = Join-Path $app.FullName "Discord.exe"
    
    if (Test-Path $discordExe) {
        if ($app.Name -match "app-(.+)") {
            $currentVersion = $matches[1]
            if (-not $latestVersion -or ([version]$currentVersion -gt [version]$latestVersion)) {
                $latestVersion = $currentVersion
                $latestDiscordExe = $discordExe
                $latestAppDir = $app
            }
        }
    }
}

Write-Host "Latest Discord version found: $latestVersion"

# Second pass: Clean the latest version and delete old versions
foreach ($app in $appDirs) {
    $modulePath = Join-Path $app.FullName "modules"
    $localePath = Join-Path $app.FullName "locales"
    $discordExe = Join-Path $app.FullName "Discord.exe"

    # If this is not the latest version, delete the entire folder
    if ($app.FullName -ne $latestAppDir.FullName) {
        Write-Host "Deleting old app version: $($app.Name)"
        Remove-Item $app.FullName -Recurse -Force
        continue
    }
    
    Write-Host "Cleaning latest version: $($app.Name)"

    # 1. Delete unwanted modules
    if (Test-Path $modulePath) {
        Get-ChildItem -Path $modulePath -Directory | Where-Object {
            $keepModules -notcontains $_.Name
        } | ForEach-Object {
            Write-Host "Deleting module: $($_.FullName)"
            Remove-Item $_.FullName -Recurse -Force
        }
    }

    # 2. Delete non-English locale files
    if (Test-Path $localePath) {
        Get-ChildItem -Path $localePath -File -Filter "*.pak" | Where-Object {
            $_.Name -ne "en-US.pak"
        } | ForEach-Object {
            Write-Host "Deleting locale file: $($_.FullName)"
            Remove-Item $_.FullName -Force
        }
    }

    # 3. Disable game detection DLLs
    $modDir = Join-Path $modulePath "discord_modules-1\discord_modules"
    if (Test-Path $modDir) {
        # Traverse into nested versioned subfolder (only one expected)
        $subVersion = Get-ChildItem -Path $modDir -Directory | Select-Object -First 1
        if ($subVersion) {
            $dllDir = Join-Path $subVersion.FullName "2"
            if (Test-Path $dllDir) {
                Get-ChildItem -Path $dllDir -Filter "*.dll" | ForEach-Object {
                    Write-Host "Disabling DLL: $($_.FullName)"
                    # Overwrite with blank file
                    Set-Content -Path $_.FullName -Value $null -Encoding Byte -Force
                    # Set read-only attribute
                    Set-ItemProperty -Path $_.FullName -Name IsReadOnly -Value $true
                }
            }
        }
    }
}

# 4. Create shortcut to the latest Discord executable
if ($latestDiscordExe) {
    $shortcutPath = Join-Path $scriptPath "Discord.lnk"
    
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = $latestDiscordExe
        $Shortcut.WorkingDirectory = Split-Path $latestDiscordExe -Parent
        $Shortcut.Description = "Discord - Cleaned Version"
        $Shortcut.Save()
        
        Write-Host "`nShortcut created: $shortcutPath"
        Write-Host "Points to: $latestDiscordExe"
    }
    catch {
        Write-Warning "Failed to create shortcut: $($_.Exception.Message)"
    }
}
else {
    Write-Warning "No Discord.exe found in any app directory. Shortcut not created."
}

Write-Host "`nDiscord cleanup complete."
Write-Host "Old app versions removed, only latest version ($latestVersion) kept."
Write-Host "You can now use the Discord.lnk shortcut to launch the cleaned Discord."