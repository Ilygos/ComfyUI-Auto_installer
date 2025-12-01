@echo off
setlocal
set "PYTHONPATH="
set "PYTHONNOUSERSITE=1"
set "InstallPath=%~dp0"
REM Remove trailing backslash
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

:: ================================================================
:: 1. ENVIRONMENT DETECTION & ACTIVATION
:: ================================================================
echo Checking installation type...
set "InstallTypeFile=%InstallPath%\scripts\install_type"
set "InstallType=conda"

if exist "%InstallTypeFile%" (
    set /p InstallType=<"%InstallTypeFile%"
) else (
    REM Fallback detection
    if exist "%InstallPath%\scripts\venv" (
        set "InstallType=venv"
    )
)

if "%InstallType%"=="venv" (
    echo [INFO] Activating venv environment...
    call "%InstallPath%\scripts\venv\Scripts\activate.bat"
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to activate venv environment.
        pause
        exit /b %errorlevel%
    )
) else (
    echo [INFO] Activating Conda environment...
    REM On suppose une installation standard Miniconda
    call "%LOCALAPPDATA%\Miniconda3\Scripts\activate.bat"
    call conda activate UmeAiRT
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to activate Conda environment 'UmeAiRT'.
        pause
        exit /b %errorlevel%
    )
)

:: ================================================================
:: 2. LAUNCH COMFIYUI
:: ================================================================
echo Starting ComfyUI...

REM Move to the internal ComfyUI folder
cd /d "%InstallPath%\ComfyUI"

echo Launching Python main.py...
REM Note: --listen for external uses
REM Note: --auto-launch opens the browser automatically
REM Note: --disable-smart-memory is optional, use only if needed for specific VRAM management
python main.py --use-sage-attention --listen --disable-smart-memory --auto-launch

pause