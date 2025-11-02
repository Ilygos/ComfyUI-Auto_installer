@echo off
setlocal

:: ============================================================================
:: Section 1: Bootstrap downloader for all scripts
:: ============================================================================
title UmeAiRT ComfyUI Updater
echo.
set "InstallPath=%~dp0"
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

set "ScriptsFolder=%InstallPath%\scripts"
set "BootstrapScript=%ScriptsFolder%\Bootstrap-Downloader.ps1"
:: Use your main branch URL
set "BootstrapUrl=https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/main/scripts/Bootstrap-Downloader.ps1"

:: (The rest of Section 1 remains identical...)
:: ...
echo [INFO] Running the bootstrap script to update all required files...
:: [FIX] We send -SkipSelf so the (now updated) bootstrap doesn't download this .bat file
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BootstrapScript%" -InstallPath "%InstallPath%" -SkipSelf
echo [OK] All scripts are now up-to-date.
echo.

:: ============================================================================
:: Section 2: Running the main update script (Conda Activation)
:: ============================================================================
echo [INFO] Launching the main update script...
echo.
set "CondaPath=%LOCALAPPDATA%\Miniconda3"
set "CondaActivate=%CondaPath%\Scripts\activate.bat"
if not exist "%CondaActivate%" (
    echo [ERROR] Could not find Conda at: %CondaActivate%
    pause
    goto :eof
)
echo [INFO] Activating Conda environment 'UmeAiRT'...
call "%CondaActivate%" UmeAiRT
if %errorlevel% neq 0 (
    echo [ERROR] Failed to activate Conda environment 'UmeAiRT'.
    pause
    goto :eof
)
echo [INFO] Launching PowerShell update script...
powershell.exe -ExecutionPolicy Bypass -File "%ScriptsFolder%\Update-ComfyUI.ps1" -InstallPath "%InstallPath%"
echo.
echo [INFO] The update script is complete.
pause

:: Section 3 (self-update) has been removed

endlocal