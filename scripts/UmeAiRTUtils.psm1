# --- Fonctions utilitaires partagées pour UmeAiRT ---

function Write-Log {
    param([string]$Message, [int]$Level = 1, [string]$Color = "Default")
    
    # Assure que $logFile est défini, sinon utilise un fallback
    if (-not $global:logFile) {
        $global:logFile = Join-Path $PSScriptRoot "default_module_log.txt"
    }

    $prefix = ""
    $defaultColor = "White"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    try {
        switch ($Level) {
            -2 { $prefix = "" }
            0 {
                $global:currentStep++
                $stepStr = "[Step $($global:currentStep)/$($global:totalSteps)]"
                $wrappedMessage = "| $stepStr $Message |"
                $separator = "=" * ($wrappedMessage.Length)
                $consoleMessage = "`n$separator`n$wrappedMessage`n$separator"
                $logMessage = "[$timestamp] $stepStr $Message"
                $defaultColor = "Yellow"
            }
            1 { $prefix = "  - " }
            2 { $prefix = "    -> " }
            3 { $prefix = "      [INFO] " }
        }
        if ($Color -eq "Default") { $Color = $defaultColor }
        if ($Level -ne 0) {
            $logMessage = "[$timestamp] $($prefix.Trim()) $Message"
            $consoleMessage = "$prefix$Message"
        }
        Write-Host $consoleMessage -ForegroundColor $Color
        Add-Content -Path $global:logFile -Value $logMessage -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Erreur interne dans Write-Log: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-AndLog {
    param( [string]$File, [string]$Arguments, [switch]$IgnoreErrors )
    
    # Assure que $logFile est défini
    if (-not $global:logFile) {
        $global:logFile = Join-Path $PSScriptRoot "default_module_log.txt"
    }
    
    $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")
    try {
        Write-Log "Executing: $File $Arguments" -Level 3 -Color DarkGray
        $CommandToRun = "& `"$File`" $Arguments *>&1 | Out-File -FilePath `"$tempLogFile`" -Encoding utf8"
        Invoke-Expression $CommandToRun
        $output = if (Test-Path $tempLogFile) { Get-Content $tempLogFile } else { @() }
        if ($LASTEXITCODE -ne 0 -and -not $IgnoreErrors) {
            Write-Log "ERREUR: La commande a échoué avec le code $LASTEXITCODE." -Color Red
            Write-Log "Commande: $File $Arguments" -Color Red
            Write-Log "Sortie de l'erreur:" -Color Red
            $output | ForEach-Object { Write-Host $_ -ForegroundColor Red; Add-Content -Path $global:logFile -Value $_ -ErrorAction SilentlyContinue }
            throw "L'exécution de la commande a échoué. Vérifiez les logs."
        } else { Add-Content -Path $global:logFile -Value $output -ErrorAction SilentlyContinue }
    } catch {
        $errMsg = "ERREUR FATALE lors de la tentative d'exécution: $File $Arguments. Erreur: $($_.Exception.Message)"
        Write-Log $errMsg -Color Red
        Add-Content -Path $global:logFile -Value $errMsg -ErrorAction SilentlyContinue
        Read-Host "Une erreur fatale est survenue. Appuyez sur Entrée pour quitter."
        exit 1
    } finally { if (Test-Path $tempLogFile) { Remove-Item $tempLogFile -ErrorAction SilentlyContinue } }
}

function Download-File {
    param([string]$Uri, [string]$OutFile)
    
    Write-Log "Downloading `"$($Uri.Split('/')[-1])`"" -Level 2 -Color DarkGray
    
    # Vérifie si aria2c est disponible (il devrait être dans le PATH de Conda)
    $aria2 = Get-Command aria2c -ErrorAction SilentlyContinue
    
    if ($null -ne $aria2) {
        # --- Solution Rapide : Utiliser Aria2 ---
        Write-Log "Using aria2c for accelerated download..." -Level 3
        $OutDir = Split-Path -Path $OutFile -Parent
        $OutName = Split-Path -Path $OutFile -Leaf
        
        # Arguments Aria2 optimisés
        $aria2Args = "--console-log-level=warn --quiet=true -x 16 -s 16 -k 1M --dir=`"$OutDir`" --out=`"$OutName`" `"$Uri`""
        
        # Appelle aria2c directement (il est dans le PATH)
        Invoke-AndLog "aria2c" $aria2Args
    }
    else {
        # --- Solution Lente (Fallback) : Utiliser PowerShell ---
        Write-Log "aria2c not found, using slower Invoke-WebRequest..." -Level 3
        # Utilise Invoke-WebRequest direct pour éviter la boucle avec Invoke-AndLog
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            Write-Log "Download successful." -Level 3
        } catch {
            Write-Log "ERREUR: Download failed for '$Uri'. Error: $($_.Exception.Message)" -Color Red
            throw "Download failed."
        }
    }
}
function Ask-Question {
    param([string]$Prompt, [string[]]$Choices, [string[]]$ValidAnswers)
    $choice = ''
    while ($choice -notin $ValidAnswers) {
        Write-Log "`n$Prompt" -Color Yellow
        foreach ($line in $Choices) {
            Write-Host "  $line" -ForegroundColor Green
        }
        $choice = (Read-Host "Enter your choice and press Enter").ToUpper()
        if ($choice -notin $ValidAnswers) {
            Write-Log "Invalid choice. Please try again." -Color Red
        }
    }
    return $choice
}
# --- FIN DU FICHIER ---
# Exporte les fonctions pour les rendre disponibles à l'importation
Export-ModuleMember -Function Write-Log, Invoke-AndLog, Download-File