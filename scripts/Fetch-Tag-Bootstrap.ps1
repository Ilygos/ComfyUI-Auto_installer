param(
    [string]$BaseUrl = "https://github.com/UmeAiRT/ComfyUI-Auto_installer",
    [string]$OutputPath = ".",
    [string]$TagFilter = "*",
    [switch]$NonInteractive,
    [string]$SelectedTagFile = ""
)

# Set TLS protocol for compatibility
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Extract repository owner and name from base URL
if ($BaseUrl -match "github\.com/([^/]+)/([^/]+)") {
    $repoOwner = $matches[1]
    $repoName = $matches[2]
} else {
    Write-Host "[ERROR] Invalid GitHub URL format. Expected: https://github.com/owner/repo" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Fetching tags from repository: $repoOwner/$repoName" -ForegroundColor Cyan

# Fetch tags from GitHub API
$apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/tags"
try {
    $tags = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
} catch {
    Write-Host "[ERROR] Failed to fetch tags from GitHub API: $_" -ForegroundColor Red
    exit 1
}

if ($tags.Count -eq 0) {
    Write-Host "[WARNING] No tags found in the repository." -ForegroundColor Yellow
    exit 0
}

Write-Host "[INFO] Found $($tags.Count) tag(s)" -ForegroundColor Green

# Filter tags if needed
$filteredTags = $tags | Where-Object { $_.name -like $TagFilter }

if ($filteredTags.Count -eq 0) {
    Write-Host "[WARNING] No tags match the filter: $TagFilter" -ForegroundColor Yellow
    exit 0
}

# Interactive tag selection
$selectedTags = @()

if (-not $NonInteractive) {
    Write-Host "`n[INFO] Available tags:" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Gray
    
    $tagList = @()
    for ($i = 0; $i -lt $filteredTags.Count; $i++) {
        $tagName = $filteredTags[$i].name
        $tagList += $tagName
        Write-Host "  [$($i + 1)] $tagName" -ForegroundColor White
    }
    
    Write-Host ("=" * 60) -ForegroundColor Gray
    Write-Host "  [0] Download all tags" -ForegroundColor Yellow
    Write-Host "  [Q] Quit" -ForegroundColor Yellow
    Write-Host ""
    
    do {
        $selection = Read-Host "Select tag(s) to download (comma-separated numbers, 0 for all, Q to quit)"
        $selection = $selection.Trim()
        
        if ($selection -eq "Q" -or $selection -eq "q") {
            Write-Host "[INFO] Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
        
        if ($selection -eq "0") {
            $selectedTags = $filteredTags
            break
        }
        
        # Parse comma-separated numbers
        $numbers = $selection -split ',' | ForEach-Object { $_.Trim() }
        $validSelection = $true
        
        foreach ($num in $numbers) {
            $numInt = 0
            if ([int]::TryParse($num, [ref]$numInt)) {
                if ($numInt -ge 1 -and $numInt -le $filteredTags.Count) {
                    $selectedTags += $filteredTags[$numInt - 1]
                } else {
                    Write-Host "[ERROR] Invalid number: $num (must be between 1 and $($filteredTags.Count))" -ForegroundColor Red
                    $validSelection = $false
                    break
                }
            } else {
                Write-Host "[ERROR] Invalid input: $num (must be a number)" -ForegroundColor Red
                $validSelection = $false
                break
            }
        }
        
        if ($validSelection -and $selectedTags.Count -gt 0) {
            break
        } else {
            $selectedTags = @()
        }
    } while ($true)
    
    # Remove duplicates by tag name
    $uniqueTagNames = $selectedTags | ForEach-Object { $_.name } | Select-Object -Unique
    $selectedTags = $filteredTags | Where-Object { $uniqueTagNames -contains $_.name }
    
    Write-Host "`n[INFO] Selected $($selectedTags.Count) tag(s) to download:" -ForegroundColor Green
    foreach ($tag in $selectedTags) {
        Write-Host "  - $($tag.name)" -ForegroundColor Cyan
    }
} else {
    # Non-interactive mode: download all filtered tags
    $selectedTags = $filteredTags
    Write-Host "[INFO] Non-interactive mode: Processing $($selectedTags.Count) tag(s) matching filter: $TagFilter" -ForegroundColor Green
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "[INFO] Created output directory: $OutputPath" -ForegroundColor Cyan
}

# Save first selected tag name to file if specified (for batch file integration)
$firstSelectedTag = $null
if ($selectedTags.Count -gt 0) {
    $firstSelectedTag = $selectedTags[0].name
    
    if ($SelectedTagFile -ne "") {
        $firstSelectedTag | Out-File -FilePath $SelectedTagFile -Encoding UTF8 -Force -NoNewline
        Write-Host "[INFO] Selected tag saved to: $SelectedTagFile" -ForegroundColor Cyan
    }
    
    # Also save as Bootstrap-Downloader-Selected.ps1 for batch file convenience
    $selectedBootstrapFile = Join-Path $OutputPath "Bootstrap-Downloader-Selected.ps1"
}

# Process each selected tag
foreach ($tag in $selectedTags) {
    $tagName = $tag.name
    Write-Host "`n[INFO] Processing tag: $tagName" -ForegroundColor Yellow
    
    # Download Bootstrap-Downloader.ps1 from the tag
    $bootstrapUrl = "$BaseUrl/raw/$tagName/scripts/Bootstrap-Downloader.ps1"
    $outputFile = Join-Path $OutputPath "Bootstrap-Downloader-Selected.ps1"
    
    Write-Host "  - Downloading from: $bootstrapUrl" -ForegroundColor Cyan
    
    try {
        $content = Invoke-WebRequest -Uri $bootstrapUrl -ErrorAction Stop
        $scriptContent = $content.Content
        
        # Replace baseUrl to point to the tag instead of "main"
        # Pattern: $baseUrl = "https://github.com/.../raw/main/"
        # Replace with: $baseUrl = "https://github.com/.../raw/$tagName/"
        $oldPattern = '\$baseUrl\s*=\s*"https://github\.com/[^/]+/[^/]+/raw/[^"]+/"'
        $newBaseUrl = "$BaseUrl/raw/$tagName/"
        $scriptContent = $scriptContent -replace $oldPattern, "`$baseUrl = `"$newBaseUrl`""
        
        # Save the modified script
        $scriptContent | Out-File -FilePath $outputFile -Encoding UTF8 -Force
        Write-Host "  - Saved to: $outputFile" -ForegroundColor Green
        
        # If this is the first selected tag, also save as Bootstrap-Downloader-Selected.ps1
        if ($tagName -eq $firstSelectedTag -and $selectedBootstrapFile) {
            $scriptContent | Out-File -FilePath $selectedBootstrapFile -Encoding UTF8 -Force
            Write-Host "  - Also saved as: $selectedBootstrapFile" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "  [ERROR] Failed to download Bootstrap-Downloader.ps1 for tag '$tagName': $_" -ForegroundColor Red
        continue
    }
}

Write-Host "`n[OK] All tags processed successfully." -ForegroundColor Green
Write-Host "[INFO] Output directory: $OutputPath" -ForegroundColor Cyan

# Exit with error if no tags were successfully processed
if ($selectedTags.Count -eq 0) {
    exit 1
}

