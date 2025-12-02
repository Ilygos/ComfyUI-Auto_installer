param(
    [string]$InstallerPath,
    [string]$BootstrapSelectedPath,
    [string]$SelectedTag,
    [string]$InstallPath = ""
)

if (-not (Test-Path $InstallerPath)) {
    Write-Host "[ERROR] Installer file not found: $InstallerPath" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Ensuring installer uses tag: $SelectedTag" -ForegroundColor Cyan

# Read the installer content
$content = Get-Content -Path $InstallerPath -Raw -Encoding UTF8

# Replace any "raw/main/" references with "raw/{SelectedTag}/"
$content = $content -replace "raw/main/", "raw/$SelectedTag/"

# If InstallPath is provided, modify the installer to use it instead of prompting
if ($InstallPath -ne "") {
    Write-Host "[INFO] Modifying installer to use pre-selected installation path: $InstallPath" -ForegroundColor Cyan
    
    # Escape special characters for regex replacement
    $escapedInstallPath = $InstallPath -replace '\\', '\\\\' -replace '\$', '\$'
    
    # Pattern to replace the entire installation path selection section
    # This matches from ":: 1. Define the default path" to "pause > nul"
    $pathSelectionPattern = '(?s)(:: 1\. Define the default path.*?pause > nul\r?\n)'
    
    # Replacement: Set the install path directly (skip all the prompting)
    $pathReplacement = @"
:: Installation path pre-selected by meta-installer
set "InstallPath=$InstallPath"
echo [INFO] Installing to: $InstallPath
echo.

"@
    
    $content = $content -replace $pathSelectionPattern, $pathReplacement
}

# If Bootstrap-Downloader-Selected.ps1 exists, modify to use it instead of downloading
if (Test-Path $BootstrapSelectedPath) {
    Write-Host "[INFO] Modifying installer to use pre-downloaded Bootstrap-Downloader-Selected.ps1" -ForegroundColor Cyan
    
    # Replace the bootstrap download section to use the existing file
    # Pattern: Download the bootstrap script... (multiline)
    $downloadPattern = '(?s)(:: Download the bootstrap script.*?powershell\.exe.*?BootstrapUrl.*?BootstrapScript.*?\r?\n)'
    $replacement = @"
:: Using pre-downloaded Bootstrap-Downloader-Selected.ps1 for tag $SelectedTag
set "BootstrapScript=%ScriptsFolder%\Bootstrap-Downloader-Selected.ps1"
if not exist "%BootstrapScript%" (
    echo [ERROR] Bootstrap-Downloader-Selected.ps1 not found. Please run Fetch-Tag-Bootstrap.ps1 first.
    pause
    exit /b 1
)

"@
    $content = $content -replace $downloadPattern, $replacement
}

# Write the modified content
$content | Out-File -FilePath $InstallerPath -Encoding UTF8 -Force -NoNewline

Write-Host "[OK] Installer modified successfully." -ForegroundColor Green

