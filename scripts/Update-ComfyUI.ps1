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

# --- 1. Update Git Repositories ---
Write-Log "Updating all Git repositories..." -Level 0 -Color Green
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
Write-Log "Updating/Installing Custom Nodes & Dependencies..." -Level 0 -Color Green
$csvUrl = $dependencies.files.custom_nodes_csv.url
$csvPath = Join-Path $InstallPath "scripts\custom_nodes.csv"
# Download fresh CSV if needed, or rely on existing logic. Assuming local exists for now or is handled elsewhere.
if (Test-Path $csvPath) {
    $customNodesList = Import-Csv -Path $csvPath
} else {
    Write-Log "WARNING: custom_nodes.csv not found locally. Skipping node checks." -Level 1 -Color Yellow
    $customNodesList = @()
}

if ($customNodesList.Count -gt 0) {
    Write-Log "Checking all nodes based on custom_nodes.csv..." -Level 1
    
    foreach ($node in $customNodesList) {
        $nodeName = $node.Name
        $repoUrl = $node.RepoUrl
        $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }
    
        # Step 1: Update or Install
        if (Test-Path $nodePath) {
            # Node exists -> Update
            Write-Log "Updating $nodeName..." -Level 2 -Color Cyan
            Invoke-AndLog "git" "-C `"$nodePath`" pull"
        } else {
            # Node does not exist -> Install
            Write-Log "New node found: $nodeName. Installing..." -Level 2 -Color Yellow
            Invoke-AndLog "git" "clone $repoUrl `"$nodePath`""
        }
    
        # Step 2: Handle Dependencies
        if (Test-Path $nodePath) {
            if ($node.RequirementsFile) {
                $reqPath = Join-Path $nodePath $node.RequirementsFile
                
                if (Test-Path $reqPath) {
                    Write-Log "Checking requirements for $nodeName (from '$($node.RequirementsFile)')" -Level 2
                    # FIX: Use specific python executable
                    Invoke-AndLog $pythonExe "-m pip install -r `"$reqPath`""
                }
            }
        }
    }
}

# --- 3. Update Python Dependencies ---
Write-Log "Updating all Python dependencies..." -Level 0 -Color Green
Write-Log "Checking main ComfyUI requirements..." -Level 1
$mainReqs = Join-Path $comfyPath "requirements.txt"
# FIX: Use specific python executable
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
            # FIX: Use specific python executable
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