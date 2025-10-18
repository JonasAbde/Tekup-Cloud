# Tekup Portfolio Audit Script - Simplified Version
# Scans all repositories and generates health reports

param(
    [string]$WorkspacePath = "C:\Users\empir",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Continue"

$repos = @(
    "Tekup-Cloud", "RendetaljeOS", "Tekup-Billy", "tekup-ai-assistant",
    "tekup-gmail-automation", "Agent-Orchestrator", "Gmail-PDF-Auto",
    "Gmail-PDF-Forwarder", "Tekup Google AI", "Tekup-org", "TekupVault"
)

$results = @()
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TEKUP PORTFOLIO AUDIT" -ForegroundColor Cyan
Write-Host "  Scanning $($repos.Count) repositories" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

foreach ($repo in $repos) {
    $repoPath = Join-Path $WorkspacePath $repo
    Write-Host "Analyzing: $repo" -ForegroundColor Yellow
    
    $data = @{
        Name = $repo
        Path = $repoPath
        Exists = Test-Path $repoPath
        PackageManager = "none"
        HasPackageJson = $false
        HasTsConfig = $false
        GitBranch = ""
        UncommittedFiles = 0
        TotalFiles = 0
        TSFiles = 0
        JSFiles = 0
        PyFiles = 0
        MDFiles = 0
        Dependencies = 0
        DevDependencies = 0
        Score = 0
        Issues = @()
    }
    
    if (-not $data.Exists) {
        $data.Issues += "Path not found"
        $results += $data
        continue
    }
    
    Push-Location $repoPath
    
    # File count
    $files = Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch '\\node_modules\\|\\dist\\|\\build\\|\\.next\\|\\.git\\|\\venv\\|\\__pycache__\\'
    }
    
    $data.TotalFiles = ($files | Measure-Object).Count
    $data.TSFiles = ($files | Where-Object Extension -in '.ts','.tsx' | Measure-Object).Count
    $data.JSFiles = ($files | Where-Object Extension -in '.js','.jsx' | Measure-Object).Count
    $data.PyFiles = ($files | Where-Object Extension -eq '.py' | Measure-Object).Count
    $data.MDFiles = ($files | Where-Object Extension -eq '.md' | Measure-Object).Count
    
    # Package detection
    $data.HasPackageJson = Test-Path "package.json"
    $data.HasTsConfig = Test-Path "tsconfig.json"
    
    if (Test-Path "pnpm-lock.yaml") { $data.PackageManager = "pnpm" }
    elseif (Test-Path "package-lock.json") { $data.PackageManager = "npm" }
    elseif (Test-Path "yarn.lock") { $data.PackageManager = "yarn" }
    elseif (Test-Path "requirements.txt") { $data.PackageManager = "pip" }
    
    # Git info
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $data.GitBranch = (git rev-parse --abbrev-ref HEAD 2>$null) -replace "`n",""
        $data.UncommittedFiles = (git status --porcelain 2>$null | Measure-Object -Line).Lines
    }
    
    # Package.json parsing
    if ($data.HasPackageJson) {
        $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($pkg) {
            $data.Dependencies = ($pkg.dependencies.PSObject.Properties | Measure-Object).Count
            $data.DevDependencies = ($pkg.devDependencies.PSObject.Properties | Measure-Object).Count
        }
    }
    
    # Health scoring
    if ($data.TotalFiles -gt 0) { $data.Score += 20 }
    if ($data.HasPackageJson) { $data.Score += 20 }
    if ($data.HasTsConfig) { $data.Score += 15 }
    if ($data.UncommittedFiles -eq 0) { $data.Score += 15 }
    if (Test-Path "README.md") { $data.Score += 10 }
    if (Test-Path "Dockerfile") { $data.Score += 10 }
    if ($data.GitBranch -eq "main" -or $data.GitBranch -eq "master") { $data.Score += 10 }
    
    # Issues
    if ($data.UncommittedFiles -gt 5) {
        $data.Issues += "$($data.UncommittedFiles) uncommitted files"
    }
    if ($data.HasPackageJson -and $data.Dependencies -eq 0 -and $data.DevDependencies -eq 0) {
        $data.Issues += "No dependencies found"
    }
    
    Pop-Location
    $results += $data
    
    $color = if ($data.Score -ge 70) { "Green" } elseif ($data.Score -ge 50) { "Yellow" } else { "Red" }
    Write-Host "  Score: $($data.Score)/100" -ForegroundColor $color
    Write-Host ""
}

# Generate Markdown Report
$report = @"
# Tekup Portfolio Audit Report
**Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Repositories**: $($results.Count)

## Executive Summary

"@

$avgScore = ($results | Measure-Object -Property Score -Average).Average
$highScore = ($results | Where-Object Score -ge 70).Count
$medScore = ($results | Where-Object { $_.Score -ge 50 -and $_.Score -lt 70 }).Count
$lowScore = ($results | Where-Object Score -lt 50).Count

$report += @"
- **Average Health Score**: $([math]::Round($avgScore, 1))/100
- **Healthy Repos** (70+): $highScore
- **Moderate Health** (50-69): $medScore
- **Needs Attention** (<50): $lowScore

---

## Repository Details

"@

foreach ($r in ($results | Sort-Object Score -Descending)) {
    $status = if ($r.Score -ge 70) { "[GREEN]" } elseif ($r.Score -ge 50) { "[YELLOW]" } else { "[RED]" }
    
    $report += @"

### $status $($r.Name) - $($r.Score)/100

**Path**: ``$($r.Path)``  
**Package Manager**: $($r.PackageManager)  
**Git Branch**: $($r.GitBranch)  
**Uncommitted Files**: $($r.UncommittedFiles)

**File Stats**:
- Total: $($r.TotalFiles) | TS: $($r.TSFiles) | JS: $($r.JSFiles) | Python: $($r.PyFiles) | MD: $($r.MDFiles)
- Dependencies: $($r.Dependencies) | Dev: $($r.DevDependencies)

"@
    
    if ($r.Issues.Count -gt 0) {
        $report += "**Issues**:`n"
        foreach ($issue in $r.Issues) {
            $report += "- $issue`n"
        }
    }
    
    $report += "`n---`n"
}

# Save Report
$reportPath = Join-Path $WorkspacePath "Tekup-Cloud\PORTFOLIO_AUDIT_$timestamp.md"
$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AUDIT COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Portfolio Health: $([math]::Round($avgScore, 1))/100" -ForegroundColor $(if ($avgScore -ge 70) {"Green"} else {"Yellow"})
Write-Host "Report saved to: $reportPath" -ForegroundColor Green
Write-Host ""

# Return results for further processing
return $results
