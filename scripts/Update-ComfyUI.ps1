#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

# --- Paths and Configuration ---
$InstallPath = (Split-Path -Path $PSScriptRoot -Parent)
$comfyPath = Join-Path $InstallPath "ComfyUI"
$customNodesPath = Join-Path $InstallPath "custom_nodes"
$workflowPath = Join-Path $InstallPath "user\default\workflows\UmeAiRT-Workflow"
$condaPath = Join-Path $env:LOCALAPPDATA "Miniconda3"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "update_log.txt"
$scriptPath = Join-Path $InstallPath "scripts"

# --- Load Dependencies from JSON ---
$dependenciesFile = Join-Path $scriptPath "dependencies.json"
if (-not (Test-Path $dependenciesFile)) {
    Write-Host "FATAL: dependencies.json not found at '$dependenciesFile'. Cannot proceed." -ForegroundColor Red
    Read-Host "Press Enter to exit."
    exit 1
}
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json

if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

# --- Helper Functions ---
Import-Module (Join-Path $PSScriptRoot "UmeAiRTUtils.psm1") -Force
# Set global logFile for utility module
$global:logFile = $logFile
# Set global steps (estimate)
$global:totalSteps = 3
$global:currentStep = 0

#===========================================================================
# SECTION 1.5: ENVIRONMENT DETECTION (ADDED FIX)
#===========================================================================
$installTypeFile = Join-Path $scriptPath "install_type"
$pythonExe = "python" # Default fallback (System Python)

if (Test-Path $installTypeFile) {
    $installType = Get-Content -Path $installTypeFile -Raw
    $installType = $installType.Trim()
    
    if ($installType -eq "venv") {
        # Path to VENV Python
        $venvPython = Join-Path $scriptPath "venv\Scripts\python.exe"
        if (Test-Path $venvPython) {
            $pythonExe = $venvPython
            Write-Host "[INIT] Detected VENV installation. Using: $pythonExe" -ForegroundColor Cyan
        } else {
            Write-Host "[WARN] Install type is 'venv' but python.exe not found. Falling back to system python." -ForegroundColor Yellow
        }
    } elseif ($installType -eq "conda") {
        # Path to CONDA Python (UmeAiRT env)
        $condaEnvPython = Join-Path $env:LOCALAPPDATA "Miniconda3\envs\UmeAiRT\python.exe"
        if (Test-Path $condaEnvPython) {
            $pythonExe = $condaEnvPython
            Write-Host "[INIT] Detected CONDA installation. Using: $pythonExe" -ForegroundColor Cyan
        } else {
            Write-Host "[WARN] Install type is 'conda' but python.exe not found in UmeAiRT env. Falling back to system python." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "[WARN] 'install_type' file not found. Assuming System Python." -ForegroundColor Yellow
}

#===========================================================================
# SECTION 2: UPDATE PROCESS
#===========================================================================
Clear-Host
Write-Log "===============================================================================" -Level -2
Write-Log "             Starting UmeAiRT ComfyUI Update Process" -Level -2 -Color Yellow
Write-Log "===============================================================================" -Level -2
Write-Log "Python Executable used: $pythonExe" -Level 1

# --- 1. Update Git Repositories (Core & Workflows) ---
Write-Log "Updating Core Git repositories..." -Level 0 -Color Green
Write-Log "Updating ComfyUI Core..." -Level 1
Invoke-AndLog "git" "-C `"$comfyPath`" pull"

Write-Log "Updating UmeAiRT Workflows (Forcing)..." -Level 1
Write-Log "  WARNING: Forced reset. Local workflow changes will be overwritten." -Level 2 -Color Red

Write-Log "  Step 1/3: Resetting local changes (reset)..." -Level 2
Invoke-AndLog "git" "-C `"$workflowPath`" reset --hard HEAD"

Write-Log "  Step 2/3: Removing untracked local files (clean)..." -Level 2
Invoke-AndLog "git" "-C `"$workflowPath`" clean -fd"

Write-Log "  Step 3/3: Pulling updates (pull)..." -Level 2
Invoke-AndLog "git" "-C `"$workflowPath`" pull"

# --- 2. Update and Install Custom Nodes & Dependencies ---
Write-Log "Updating/Installing Custom Nodes..." -Level 0 -Color Green

# --- A. Update ComfyUI-Manager FIRST (Critical for cm-cli) ---
$managerPath = Join-Path $customNodesPath "ComfyUI-Manager"
Write-Log "Updating ComfyUI-Manager..." -Level 1
if (Test-Path $managerPath) {
    Invoke-AndLog "git" "-C `"$managerPath`" pull"
} else {
    Write-Log "ComfyUI-Manager missing. Installing..." -Level 2
    Invoke-AndLog "git" "clone https://github.com/ltdrdata/ComfyUI-Manager.git `"$managerPath`""
}
$cmCliScript = Join-Path $managerPath "cm-cli.py"

# --- B. Snapshot vs CSV Logic ---
$snapshotFile = Join-Path $scriptPath "snapshot.json"

if (Test-Path $snapshotFile) {
    # --- METHOD 1: Snapshot (Preferred) ---
    Write-Log "SNAPSHOT DETECTED: Using ComfyUI-Manager to sync nodes..." -Level 1 -Color Cyan
    Write-Log "This will update existing nodes and install missing ones defined in snapshot.json." -Level 2
    
    try {
        # 'restore' creates missing nodes AND updates existing ones to the snapshot commit
        Invoke-AndLog $pythonExe "`"$cmCliScript`" restore `"$snapshotFile`""
        Write-Log "Snapshot sync complete!" -Level 1 -Color Green
    } catch {
        Write-Log "ERROR: Snapshot sync failed. Check logs." -Level 1 -Color Red
    }

} else {
    # --- METHOD 2: CSV Fallback ---
    Write-Log "No snapshot.json found. Falling back to custom_nodes.csv..." -Level 1 -Color Yellow
    
    $csvPath = Join-Path $InstallPath "scripts\custom_nodes.csv"
    if (Test-Path $csvPath) {
        $customNodesList = Import-Csv -Path $csvPath
        
        foreach ($node in $customNodesList) {
            $nodeName = $node.Name
            $repoUrl = $node.RepoUrl
            $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }
        
            # Update or Install
            if (Test-Path $nodePath) {
                Write-Log "Updating $nodeName..." -Level 2 -Color Cyan
                Invoke-AndLog "git" "-C `"$nodePath`" pull"
            } else {
                Write-Log "New node found: $nodeName. Installing..." -Level 2 -Color Yellow
                Invoke-AndLog "git" "clone $repoUrl `"$nodePath`""
            }
        
            # Handle Dependencies
            if (Test-Path $nodePath) {
                if ($node.RequirementsFile) {
                    $reqPath = Join-Path $nodePath $node.RequirementsFile
                    if (Test-Path $reqPath) {
                        Write-Log "Checking requirements for $nodeName..." -Level 2
                        Invoke-AndLog $pythonExe "-m pip install -r `"$reqPath`""
                    }
                }
            }
        }
    } else {
        Write-Log "WARNING: custom_nodes.csv not found locally either." -Level 1 -Color Yellow
    }
}

# --- 3. Update Python Dependencies ---
Write-Log "Updating all Python dependencies..." -Level 0 -Color Green
Write-Log "Checking main ComfyUI requirements..." -Level 1
$mainReqs = Join-Path $comfyPath "requirements.txt"
Invoke-AndLog $pythonExe "-m pip install -r `"$mainReqs`""

# Reinstall wheel packages to ensure correct versions from JSON
Write-Log "Update wheel packages..." -Level 1
foreach ($wheel in $dependencies.pip_packages.wheels) {
    $wheelName = $wheel.name
    $wheelUrl = $wheel.url
    $localWheelPath = Join-Path $env:TEMP "$($wheelName).whl"

    Write-Log "Processing wheel: $wheelName" -Level 2 -Color Cyan

    try {
        # Download the wheel file (uses UmeAiRTUtils.psm1 function)
        Download-File -Uri $wheelUrl -OutFile $localWheelPath

        if (Test-Path $localWheelPath) {
            Invoke-AndLog $pythonExe "-m pip install `"$localWheelPath`""
        } else {
            Write-Log "ERROR: Failed to download $wheelName" -Level 2 -Color Red
        }
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "FATAL ERROR during processing of $wheelName : $errorMessage" -Level 2 -Color Red
    } finally {
        # Clean up the downloaded wheel file
        if (Test-Path $localWheelPath) {
            Remove-Item $localWheelPath -Force
        }
    }
}

Write-Log "===============================================================================" -Level -2
Write-Log "Update process complete!" -Level -2 -Color Yellow
Write-Log "===============================================================================" -Level -2