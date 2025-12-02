@echo off
setlocal
set "PYTHONPATH="
set "PYTHONNOUSERSITE=1"

:: ============================================================================
:: Meta-Installer: Select version tag and download appropriate installer
:: ============================================================================
title UmeAiRT ComfyUI Meta-Installer
echo.
cls
echo ============================================================================
echo      UmeAiRT ComfyUI Meta-Installer - Version Selector
echo ============================================================================
echo.

:: Set base paths
set "BasePath=%~dp0"
if "%BasePath:~-1%"=="\" set "BasePath=%BasePath:~0,-1%"

set "ScriptsFolder=%BasePath%\scripts"
set "TempFolder=%BasePath%\temp"
set "FetchTagScript=%ScriptsFolder%\Fetch-Tag-Bootstrap.ps1"
set "SelectedTagFile=%ScriptsFolder%\selected-tag.txt"
set "BaseUrl=https://github.com/Ilygos/ComfyUI-Auto_installer"
set "FetchTagUrl=%BaseUrl%/raw/main/scripts/Fetch-Tag-Bootstrap.ps1"

:: Create necessary folders
if not exist "%ScriptsFolder%" (
    echo [INFO] Creating scripts folder: %ScriptsFolder%
    mkdir "%ScriptsFolder%"
)
if not exist "%TempFolder%" (
    echo [INFO] Creating temp folder: %TempFolder%
    mkdir "%TempFolder%"
)

:: ============================================================================
:: Step 0: Select Installation Folder
:: ============================================================================
echo.
echo ============================================================================
echo                    Installation Folder Selection
echo ============================================================================
echo.
echo Where would you like to install ComfyUI?
echo.
echo Current path: %BasePath%
echo.
echo Press ENTER to use the current path.
echo Or, enter a full path (e.g., D:\ComfyUI) and press ENTER.
echo.

:: Prompt the user for installation path
set /p "InstallPath=Enter installation path: "

:: If user entered nothing, use the default
if "%InstallPath%"=="" (
    set "InstallPath=%BasePath%"
)

:: Clean up the final path (in case the user added a trailing \)
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

echo.
echo [INFO] Installation path set to: %InstallPath%
echo.
echo Press any key to continue with tag selection...
pause > nul
echo.

:: ============================================================================
:: Step 1: Download required PowerShell scripts if needed
:: ============================================================================
set "ModifyScript=%ScriptsFolder%\Modify-Installer-For-Tag.ps1"
set "ModifyScriptUrl=%BaseUrl%/raw/main/scripts/Modify-Installer-For-Tag.ps1"

if not exist "%FetchTagScript%" (
    echo [INFO] Downloading Fetch-Tag-Bootstrap.ps1...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%FetchTagUrl%' -OutFile '%FetchTagScript%' -ErrorAction Stop; Write-Host '[OK] Download successful' -ForegroundColor Green } catch { Write-Host '[ERROR] Failed to download Fetch-Tag-Bootstrap.ps1' -ForegroundColor Red; exit 1 }"
    if errorlevel 1 (
        echo [ERROR] Failed to download Fetch-Tag-Bootstrap.ps1. Please check your internet connection.
        pause
        exit /b 1
    )
)

if not exist "%ModifyScript%" (
    echo [INFO] Downloading Modify-Installer-For-Tag.ps1...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%ModifyScriptUrl%' -OutFile '%ModifyScript%' -ErrorAction Stop; Write-Host '[OK] Download successful' -ForegroundColor Green } catch { Write-Host '[WARNING] Failed to download Modify-Installer-For-Tag.ps1' -ForegroundColor Yellow }"
)

:: ============================================================================
:: Step 2: Run Fetch-Tag-Bootstrap.ps1 to select tag and download Bootstrap
:: ============================================================================
echo [INFO] Fetching available tags and selecting version...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%FetchTagScript%" -OutputPath "%ScriptsFolder%" -SelectedTagFile "%SelectedTagFile%"
if errorlevel 1 (
    echo [ERROR] Failed to fetch tags or user cancelled. Exiting.
    pause
    exit /b 1
)

:: Check if selected tag file exists
if not exist "%SelectedTagFile%" (
    echo [ERROR] Selected tag file not found. Tag selection may have failed.
    pause
    exit /b 1
)

:: Read the selected tag
set /p SelectedTag=<"%SelectedTagFile%"
if "%SelectedTag%"=="" (
    echo [ERROR] No tag was selected or tag file is empty.
    pause
    exit /b 1
)

echo.
echo [INFO] Selected version tag: %SelectedTag%
echo.

:: ============================================================================
:: Step 3: Download UmeAiRT-Install-ComfyUI.bat from the selected tag
:: ============================================================================
set "InstallerUrl=%BaseUrl%/raw/%SelectedTag%/UmeAiRT-Install-ComfyUI.bat"
set "DownloadedInstaller=%TempFolder%\UmeAiRT-Install-ComfyUI.%SelectedTag%.bat"

echo [INFO] Downloading installer for tag %SelectedTag%...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%InstallerUrl%' -OutFile '%DownloadedInstaller%' -ErrorAction Stop; Write-Host '[OK] Installer downloaded successfully' -ForegroundColor Green } catch { Write-Host '[ERROR] Failed to download installer for tag %SelectedTag%' -ForegroundColor Red; exit 1 }"
if errorlevel 1 (
    echo [ERROR] Failed to download installer from tag %SelectedTag%.
    echo [INFO] The installer may not exist for this tag, or there may be a network issue.
    pause
    exit /b 1
)

:: Verify the downloaded installer exists
if not exist "%DownloadedInstaller%" (
    echo [ERROR] Downloaded installer file not found: %DownloadedInstaller%
    pause
    exit /b 1
)

echo [OK] Installer downloaded: %DownloadedInstaller%
echo.

:: ============================================================================
:: Step 4: Modify the downloaded installer to use Bootstrap-Downloader-Selected.ps1
:: ============================================================================
echo [INFO] Preparing installer for execution...
set "BootstrapSelected=%ScriptsFolder%\Bootstrap-Downloader-Selected.ps1"

:: Modify the installer to ensure it uses the correct tag, install path, and pre-downloaded bootstrap
if exist "%ModifyScript%" (
    echo [INFO] Modifying installer to use tag %SelectedTag%, install path %InstallPath%, and pre-downloaded bootstrap...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ModifyScript%" -InstallerPath "%DownloadedInstaller%" -BootstrapSelectedPath "%BootstrapSelected%" -SelectedTag "%SelectedTag%" -InstallPath "%InstallPath%"
    if errorlevel 1 (
        echo [WARNING] Failed to modify installer. It will use its default behavior.
    ) else (
        echo [OK] Installer modified successfully.
    )
) else (
    echo [INFO] Modify script not found. Installer will use its default behavior.
    if exist "%BootstrapSelected%" (
        echo [INFO] Bootstrap-Downloader-Selected.ps1 is available but installer may download its own.
    )
)

:: ============================================================================
:: Step 5: Execute the downloaded installer
:: ============================================================================
echo.
echo ============================================================================
echo [INFO] Launching installer for version %SelectedTag%
echo ============================================================================
echo.

:: Execute the downloaded installer
call "%DownloadedInstaller%"

:: Store the exit code
set "InstallerExitCode=%ERRORLEVEL%"

:: ============================================================================
:: Cleanup (optional - comment out if you want to keep the downloaded installer)
:: ============================================================================
:: Uncomment the following lines if you want to clean up the temp folder
:: echo.
:: echo [INFO] Cleaning up temporary files...
:: if exist "%DownloadedInstaller%" del /q "%DownloadedInstaller%"
:: if exist "%TempFolder%" rmdir /q "%TempFolder%" 2>nul

echo.
if %InstallerExitCode% EQU 0 (
    echo [OK] Installation process completed successfully.
) else (
    echo [WARNING] Installation process exited with code %InstallerExitCode%.
)
echo.
pause

exit /b %InstallerExitCode%

