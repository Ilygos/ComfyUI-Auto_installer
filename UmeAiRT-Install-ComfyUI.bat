@echo off
setlocal
set "PYTHONPATH="
set "PYTHONNOUSERSITE=1"
:: ============================================================================
:: Section 1: Set Installation Path (Modified)
:: ============================================================================
title UmeAiRT ComfyUI Installer
echo.
cls
echo ============================================================================
echo           Welcome to the UmeAiRT ComfyUI Installer
echo ============================================================================
echo.

:: 1. Define the default path (the current directory)
set "DefaultPath=%~dp0"
if "%DefaultPath:~-1%"=="\" set "DefaultPath=%DefaultPath:~0,-1%"

echo Where would you like to install ComfyUI?
echo.
echo Current path: %DefaultPath%
echo.
echo Press ENTER to use the current path.
echo Or, enter a full path (e.g., D:\ComfyUI) and press ENTER.
echo.

:: 2. Prompt the user
set /p "InstallPath=Enter installation path: "

:: 3. If user entered nothing, use the default
if "%InstallPath%"=="" (
    set "InstallPath=%DefaultPath%"
)

:: 4. Clean up the final path (in case the user added a trailing \)
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

echo.
echo [INFO] Installing to: %InstallPath%
echo Press any key to begin...
pause > nul

:: ============================================================================
:: Section 2: Tag selection and Bootstrap downloader for all scripts
:: ============================================================================

set "ScriptsFolder=%InstallPath%\scripts"
set "FetchTagScript=%ScriptsFolder%\Fetch-Tag-Bootstrap.ps1"
set "SelectedBootstrapScript=%ScriptsFolder%\Bootstrap-Downloader-Selected.ps1"
set "SelectedTagFile=%ScriptsFolder%\selected-tag.txt"
set "FetchTagUrl=https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/main/scripts/Fetch-Tag-Bootstrap.ps1"

:: Create scripts folder if it doesn't exist
if not exist "%ScriptsFolder%" (
    echo [INFO] Creating the scripts folder: %ScriptsFolder%
    mkdir "%ScriptsFolder%"
)

:: Download Fetch-Tag-Bootstrap.ps1 if it doesn't exist
if not exist "%FetchTagScript%" (
    echo [INFO] Downloading Fetch-Tag-Bootstrap.ps1...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%FetchTagUrl%' -OutFile '%FetchTagScript%'"
)

:: Run Fetch-Tag-Bootstrap.ps1 to let user select a tag and download the bootstrap
echo [INFO] Fetching available tags and selecting bootstrap version...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%FetchTagScript%" -OutputPath "%ScriptsFolder%" -SelectedTagFile "%SelectedTagFile%"
if errorlevel 1 (
    echo [ERROR] Failed to fetch tags or user cancelled. Exiting.
    pause
    exit /b 1
)

:: Check if the selected bootstrap script exists
if not exist "%SelectedBootstrapScript%" (
    echo [ERROR] Selected bootstrap script not found: %SelectedBootstrapScript%
    echo [ERROR] Please ensure a tag was selected successfully.
    pause
    exit /b 1
)

:: Run the selected bootstrap script to download all other files
echo.
echo [INFO] Running the selected bootstrap script to download all required files...
:: Pass the clean install path to the PowerShell script.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SelectedBootstrapScript%" -InstallPath "%InstallPath%"
if errorlevel 1 (
    echo [ERROR] Bootstrap download failed.
    pause
    exit /b 1
)
echo [OK] Bootstrap download complete.
echo.

:: ============================================================================
:: Section 3: Running the main installation script (Original logic)
:: ============================================================================
echo [INFO] Launching the main installation script...
echo.
:: Pass the clean install path to the PowerShell script.
powershell.exe -ExecutionPolicy Bypass -File "%ScriptsFolder%\Install-ComfyUI-Phase1.ps1" -InstallPath "%InstallPath%"

echo.
echo [INFO] The script execution is complete.
pause