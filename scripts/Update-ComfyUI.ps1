
#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

# --- Paths and Configuration ---
$InstallPath = (Split-Path -Path $PSScriptRoot -Parent)
$comfyPath = Join-Path $InstallPath "ComfyUI"
$customNodesPath = Join-Path $InstallPath "custom_nodes"
$workflowPath = Join-Path $InstallPath "user\default\workflows\UmeAiRT-Workflow"
$condaPath = Join-Path $InstallPath "Miniconda3"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "update_log.txt"

# --- Load Dependencies from JSON ---
$dependenciesFile = Join-Path $InstallPath "scripts\dependencies.json"
if (-not (Test-Path $dependenciesFile)) {
    Write-Host "FATAL: dependencies.json not found at '$dependenciesFile'. Cannot proceed." -ForegroundColor Red
    Read-Host "Press Enter to exit."
    exit 1
}
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json

if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

# --- Helper Functions ---
Import-Module (Join-Path $PSScriptRoot "UmeAiRTUtils.psm1") -Force

#===========================================================================
# SECTION 2: UPDATE PROCESS
#===========================================================================
Clear-Host
Write-Log "==============================================================================="
Write-Log "             Starting UmeAiRT ComfyUI Update Process" -Color Yellow
Write-Log "==============================================================================="

# --- 1. Update Git Repositories ---
Write-Log "`n[1/3] Updating all Git repositories..." -Color Green
Write-Log "  - Updating ComfyUI Core..."
Invoke-Git-Pull -DirectoryPath $comfyPath
Write-Log "  - Updating UmeAiRT Workflows..."
Invoke-Git-Pull -DirectoryPath $workflowPath

# --- 2. Update and Install Custom Nodes & Dependencies ---
Write-Log "`n[2/3] Updating/Installing Custom Nodes & Dependencies..." -Color Green
$csvUrl = $dependencies.files.custom_nodes_csv.url
$csvPath = Join-Path $InstallPath "scripts\custom_nodes.csv"
$customNodesList = Import-Csv -Path $csvPath

Write-Log "  - Checking all nodes based on custom_nodes.csv..."

foreach ($node in $customNodesList) {
    $nodeName = $node.Name
    $repoUrl = $node.RepoUrl
    $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }

    # Étape 1 : Mettre à jour ou Installer
    if (Test-Path $nodePath) {
        # Le nœud existe -> Mise à jour
        Write-Log "    - Updating $nodeName..." -Color Cyan
        Invoke-Git-Pull -DirectoryPath $nodePath
    } else {
        # Le nœud n'existe pas -> Installation
        Write-Log "    - New node found: $nodeName. Installing..." -Color Yellow
        Invoke-AndLog "git" "clone $repoUrl `"$nodePath`""
    }

    # Étape 2 : Gérer les dépendances
    if (Test-Path $nodePath) {
        if ($node.RequirementsFile) {
            $reqPath = Join-Path $nodePath $node.RequirementsFile
            
            if (Test-Path $reqPath) {
                Write-Log "    - Checking requirements for $nodeName (from '$($node.RequirementsFile)')"
                
                # Le hack 'cupy' est supprimé, comme vous l'avez dit.
                
                Invoke-Pip-Install -RequirementsPath $reqPath
            }
        }
    }
}

# --- 3. Update Python Dependencies ---
Write-Log "`n[3/3] Updating all Python dependencies..." -Color Green
Write-Log "  - Checking main ComfyUI requirements..."
Invoke-Pip-Install -RequirementsPath (Join-Path $comfyPath "requirements.txt")

# Reinstall wheel packages to ensure correct versions from JSON
Write-Log "  - Ensuring wheel packages are at the correct version..."
foreach ($wheel in $dependencies.pip_packages.wheels) {
    $wheelName = $wheel.name
    $wheelUrl = $wheel.url
    $localWheelPath = Join-Path $env:TEMP $wheelName

    Write-Log "    - Processing wheel: $wheelName" -Color Cyan

    try {
        # Download the wheel file
        Download-File -Uri $wheelUrl -OutFile $localWheelPath

        # Force reinstall the downloaded wheel
        if (Test-Path $localWheelPath) {
            Invoke-Conda-Command "python" "-m pip install --upgrade --force-reinstall `"$localWheelPath`""
        } else {
            Write-Log "      - ERROR: Failed to download $wheelName" -Color Red
        }
    } catch {
        # On récupère le message d'erreur sur une ligne séparée pour éviter les erreurs de syntaxe
        $errorMessage = $_.Exception.Message
        Write-Log "      - FATAL ERROR during processing of $wheelName : $errorMessage" -Color Red
    } finally {
        # Clean up the downloaded wheel file
        if (Test-Path $localWheelPath) {
            Remove-Item $localWheelPath -Force
        }
    }
}

Write-Log "==============================================================================="
Write-Log "Update process complete!" -Color Yellow
Write-Log "==============================================================================="
Read-Host "Press Enter to exit."
