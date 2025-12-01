@echo off
set "PYTHONPATH="
set "PYTHONNOUSERSITE=1"
set "InstallPath=%~dp0"
REM Remove trailing backslash
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

echo Checking installation type...
set "InstallTypeFile=%InstallPath%\install_type"
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
    call "%LOCALAPPDATA%\Miniconda3\Scripts\activate.bat"
    call conda activate UmeAiRT
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to activate Conda environment 'UmeAiRT'.
        pause
        exit /b %errorlevel%
    )
)

echo Starting ComfyUI with custom arguments...

REM Moves to the ComfyUI folder.
cd /d "%InstallPath%\ComfyUI"

REM Prepares the base path, ensuring it is correctly formatted.
set "RAW_BASE_DIR=%InstallPath%"
if "%RAW_BASE_DIR:~-1%"=="\" set "RAW_BASE_DIR=%RAW_BASE_DIR:~0,-1%"

set "BASE_DIR="%RAW_BASE_DIR%""
set "TMP_DIR="%RAW_BASE_DIR%\ComfyUI\temp""

echo Launching Python script...
python main.py --use-sage-attention --disable-smart-memory --base-directory %BASE_DIR% --auto-launch --temp-directory %TMP_DIR%

pause
