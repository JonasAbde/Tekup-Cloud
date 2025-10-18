# Tekup Portfolio Comprehensive Audit Script
# Scans all 11 repositories and generates structured analysis
# Output: Detailed markdown reports with actionable insights

param(
    [switch]$QuickScan,  # Skip npm install/build checks
    [switch]$DeepScan    # Include code metrics and security audit
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Repository definitions
$repositories = @(
    @{Name="Tekup-Cloud"; Path="c:\Users\empir\Tekup-Cloud"; Type="Scripts"; Priority="Support"},
    @{Name="RendetaljeOS"; Path="c:\Users\empir\RendetaljeOS"; Type="Monorepo"; Priority="Active"},
    @{Name="Tekup-Billy"; Path="c:\Users\empir\Tekup-Billy"; Type="TypeScript"; Priority="Production"},
    @{Name="tekup-ai-assistant"; Path="c:\Users\empir\tekup-ai-assistant"; Type="TypeScript"; Priority="Active"},
    @{Name="tekup-gmail-automation"; Path="c:\Users\empir\tekup-gmail-automation"; Type="Python"; Priority="Active"},
    @{Name="Agent-Orchestrator"; Path="c:\Users\empir\Agent-Orchestrator"; Type="Electron"; Priority="Active"},
    @{Name="Gmail-PDF-Auto"; Path="c:\Users\empir\Gmail-PDF-Auto"; Type="Utility"; Priority="Support"},
    @{Name="Gmail-PDF-Forwarder"; Path="c:\Users\empir\Gmail-PDF-Forwarder"; Type="Utility"; Priority="Support"},
    @{Name="Tekup Google AI"; Path="c:\Users\empir\Tekup Google AI"; Type="TypeScript"; Priority="Production"},
    @{Name="Tekup-org"; Path="c:\Users\empir\Tekup-org"; Type="Monorepo"; Priority="Paused"},
    @{Name="TekupVault"; Path="c:\Users\empir\TekupVault"; Type="Monorepo"; Priority="Production"}
)

# Results storage
$auditResults = @()
$dependencyMatrix = @{}
$criticalIssues = @()
$quickWins = @()

Write-Host "`n🔍 TEKUP PORTFOLIO AUDIT - Starting scan of 11 repositories" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp`n" -ForegroundColor Gray

# Helper Functions
function Get-GitStatus {
    param($RepoPath)
    
    Push-Location $RepoPath
    try {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        $uncommitted = (git status --porcelain 2>$null | Measure-Object).Count
        $lastCommit = git log -1 --format="%ar" 2>$null
        $remoteUrl = git config --get remote.origin.url 2>$null
        
        return @{
            Branch = $branch
            UncommittedChanges = $uncommitted
            LastCommit = $lastCommit
            RemoteUrl = $remoteUrl
            IsGitRepo = $branch -ne $null
        }
    } finally {
        Pop-Location
    }
}

function Get-PackageInfo {
    param($RepoPath)
    
    $packageJson = Join-Path $RepoPath "package.json"
    if (Test-Path $packageJson) {
        try {
            $pkg = Get-Content $packageJson -Raw | ConvertFrom-Json
            
            $depCount = if ($pkg.dependencies) { ($pkg.dependencies | Get-Member -MemberType NoteProperty).Count } else { 0 }
            $devDepCount = if ($pkg.devDependencies) { ($pkg.devDependencies | Get-Member -MemberType NoteProperty).Count } else { 0 }
            
            $scripts = @()
            if ($pkg.scripts) {
                $scripts = ($pkg.scripts | Get-Member -MemberType NoteProperty).Name
            }
            
            return @{
                Name = $pkg.name
                Version = $pkg.version
                Dependencies = $depCount
                DevDependencies = $devDepCount
                Scripts = $scripts
                HasBuild = $scripts -contains "build"
                HasTest = $scripts -contains "test"
                HasDev = $scripts -contains "dev"
                PackageManager = if (Test-Path (Join-Path $RepoPath "pnpm-lock.yaml")) { "pnpm" } 
                                elseif (Test-Path (Join-Path $RepoPath "package-lock.json")) { "npm" }
                                elseif (Test-Path (Join-Path $RepoPath "yarn.lock")) { "yarn" }
                                else { "none" }
            }
        } catch {
            return $null
        }
    }
    return $null
}

function Get-TypeScriptStatus {
    param($RepoPath)
    
    $tsconfigPath = Join-Path $RepoPath "tsconfig.json"
    if (Test-Path $tsconfigPath) {
        Push-Location $RepoPath
        try {
            # Check if TypeScript is installed
            $hasTsc = Get-Command tsc -ErrorAction SilentlyContinue
            if (-not $hasTsc) {
                return @{
                    HasTypeScript = $true
                    ErrorCount = "N/A (tsc not in PATH)"
                    Config = "Present"
                }
            }
            
            # Run tsc --noEmit and capture output
            $output = npx tsc --noEmit 2>&1
            $errorCount = ($output | Select-String "error TS" | Measure-Object).Count
            
            return @{
                HasTypeScript = $true
                ErrorCount = $errorCount
                Config = "Present"
            }
        } finally {
            Pop-Location
        }
    }
    return @{HasTypeScript = $false}
}

function Get-PythonInfo {
    param($RepoPath)
    
    $requirementsTxt = Join-Path $RepoPath "requirements.txt"
    $pyprojectToml = Join-Path $RepoPath "pyproject.toml"
    
    if ((Test-Path $requirementsTxt) -or (Test-Path $pyprojectToml)) {
        $depCount = 0
        if (Test-Path $requirementsTxt) {
            $depCount = (Get-Content $requirementsTxt | Where-Object { $_ -match "^[a-zA-Z]" } | Measure-Object).Count
        }
        
        return @{
            IsPython = $true
            HasRequirements = Test-Path $requirementsTxt
            HasPyproject = Test-Path $pyprojectToml
            DependencyCount = $depCount
        }
    }
    return @{IsPython = $false}
}

function Get-DockerStatus {
    param($RepoPath)
    
    $dockerfile = Join-Path $RepoPath "Dockerfile"
    $dockerCompose = Join-Path $RepoPath "docker-compose.yml"
    
    return @{
        HasDockerfile = Test-Path $dockerfile
        HasDockerCompose = Test-Path $dockerCompose
        IsContainerized = (Test-Path $dockerfile) -or (Test-Path $dockerCompose)
    }
}

function Get-DocumentationScore {
    param($RepoPath)
    
    $score = 0
    $maxScore = 10
    
    # Check for README
    if (Test-Path (Join-Path $RepoPath "README.md")) { $score += 3 }
    
    # Check for CHANGELOG
    if (Test-Path (Join-Path $RepoPath "CHANGELOG.md")) { $score += 1 }
    
    # Check for docs folder
    if (Test-Path (Join-Path $RepoPath "docs")) { $score += 2 }
    
    # Check for .env.example
    if (Test-Path (Join-Path $RepoPath ".env.example")) { $score += 1 }
    
    # Check for LICENSE
    if (Test-Path (Join-Path $RepoPath "LICENSE")) { $score += 1 }
    
    # Check for copilot instructions
    if (Test-Path (Join-Path $RepoPath ".github\copilot-instructions.md")) { $score += 2 }
    
    return @{
        Score = $score
        MaxScore = $maxScore
        Percentage = [math]::Round(($score / $maxScore) * 100, 0)
    }
}

function Get-CodeMetrics {
    param($RepoPath)
    
    $files = Get-ChildItem -Path $RepoPath -Recurse -File -ErrorAction SilentlyContinue | 
             Where-Object { $_.FullName -notmatch "node_modules|\.git|dist|build|coverage" }
    
    $tsFiles = $files | Where-Object { $_.Extension -in @(".ts", ".tsx") }
    $jsFiles = $files | Where-Object { $_.Extension -in @(".js", ".jsx") }
    $pyFiles = $files | Where-Object { $_.Extension -eq ".py" }
    $mdFiles = $files | Where-Object { $_.Extension -eq ".md" }
    
    return @{
        TotalFiles = $files.Count
        TypeScriptFiles = $tsFiles.Count
        JavaScriptFiles = $jsFiles.Count
        PythonFiles = $pyFiles.Count
        MarkdownFiles = $mdFiles.Count
        TotalSize = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    }
}

function Get-ProductionReadinessScore {
    param($RepoData)
    
    $score = 0
    $issues = @()
    
    # Git health (20 points)
    if ($RepoData.Git.IsGitRepo) { $score += 10 } else { $issues += "Not a Git repository" }
    if ($RepoData.Git.UncommittedChanges -eq 0) { $score += 10 } else { $issues += "$($RepoData.Git.UncommittedChanges) uncommitted changes" }
    
    # Package health (20 points)
    if ($RepoData.Package) {
        if ($RepoData.Package.HasBuild) { $score += 10 } else { $issues += "No build script" }
        if ($RepoData.Package.HasTest) { $score += 5 } else { $issues += "No test script" }
        if ($RepoData.Package.PackageManager -ne "none") { $score += 5 } else { $issues += "No package manager lockfile" }
    }
    
    # TypeScript health (20 points)
    if ($RepoData.TypeScript.HasTypeScript) {
        if ($RepoData.TypeScript.ErrorCount -eq 0) { 
            $score += 20 
        } elseif ($RepoData.TypeScript.ErrorCount -match "^\d+$" -and [int]$RepoData.TypeScript.ErrorCount -lt 10) {
            $score += 10
            $issues += "$($RepoData.TypeScript.ErrorCount) TypeScript errors"
        } elseif ($RepoData.TypeScript.ErrorCount -match "^\d+$") {
            $issues += "$($RepoData.TypeScript.ErrorCount) TypeScript errors"
        }
    }
    
    # Docker/Deployment (20 points)
    if ($RepoData.Docker.IsContainerized) { $score += 20 } else { $issues += "No Docker configuration" }
    
    # Documentation (20 points)
    $score += ($RepoData.Documentation.Score * 2)
    if ($RepoData.Documentation.Score -lt 7) { $issues += "Documentation incomplete" }
    
    return @{
        Score = $score
        Issues = $issues
        Grade = if ($score -ge 90) { "A" } elseif ($score -ge 80) { "B" } elseif ($score -ge 70) { "C" } elseif ($score -ge 60) { "D" } else { "F" }
    }
}

# Main Audit Loop
foreach ($repo in $repositories) {
    Write-Host "`n📦 Analyzing: $($repo.Name)" -ForegroundColor Yellow
    Write-Host "   Path: $($repo.Path)" -ForegroundColor Gray
    
    if (-not (Test-Path $repo.Path)) {
        Write-Host "   ⚠️  Repository path not found!" -ForegroundColor Red
        continue
    }
    
    $repoData = @{
        Name = $repo.Name
        Path = $repo.Path
        Type = $repo.Type
        Priority = $repo.Priority
    }
    
    # Git Analysis
    Write-Host "   → Git status..." -NoNewline
    $repoData.Git = Get-GitStatus -RepoPath $repo.Path
    Write-Host " ✓" -ForegroundColor Green
    
    # Package Analysis
    if ($repo.Type -in @("TypeScript", "Monorepo", "Electron")) {
        Write-Host "   → Package analysis..." -NoNewline
        $repoData.Package = Get-PackageInfo -RepoPath $repo.Path
        Write-Host " ✓" -ForegroundColor Green
        
        # TypeScript Analysis
        Write-Host "   → TypeScript check..." -NoNewline
        $repoData.TypeScript = Get-TypeScriptStatus -RepoPath $repo.Path
        Write-Host " ✓" -ForegroundColor Green
    }
    
    # Python Analysis
    if ($repo.Type -eq "Python") {
        Write-Host "   → Python analysis..." -NoNewline
        $repoData.Python = Get-PythonInfo -RepoPath $repo.Path
        Write-Host " ✓" -ForegroundColor Green
    }
    
    # Docker Analysis
    Write-Host "   → Docker status..." -NoNewline
    $repoData.Docker = Get-DockerStatus -RepoPath $repo.Path
    Write-Host " ✓" -ForegroundColor Green
    
    # Documentation Analysis
    Write-Host "   → Documentation score..." -NoNewline
    $repoData.Documentation = Get-DocumentationScore -RepoPath $repo.Path
    Write-Host " ✓" -ForegroundColor Green
    
    # Code Metrics
    if ($DeepScan) {
        Write-Host "   → Code metrics..." -NoNewline
        $repoData.Metrics = Get-CodeMetrics -RepoPath $repo.Path
        Write-Host " ✓" -ForegroundColor Green
    }
    
    # Production Readiness Score
    Write-Host "   → Production readiness..." -NoNewline
    $repoData.ProductionReadiness = Get-ProductionReadinessScore -RepoData $repoData
    Write-Host " ✓ Score: $($repoData.ProductionReadiness.Score)/100 (Grade: $($repoData.ProductionReadiness.Grade))" -ForegroundColor $(if ($repoData.ProductionReadiness.Score -ge 70) { "Green" } elseif ($repoData.ProductionReadiness.Score -ge 50) { "Yellow" } else { "Red" })
    
    $auditResults += $repoData
    
    # Collect critical issues
    if ($repoData.ProductionReadiness.Score -lt 60 -and $repo.Priority -eq "Production") {
        $criticalIssues += @{
            Repo = $repo.Name
            Issue = "Production repository with readiness score below 60%"
            Score = $repoData.ProductionReadiness.Score
        }
    }
    
    if ($repoData.Git.UncommittedChanges -gt 50) {
        $criticalIssues += @{
            Repo = $repo.Name
            Issue = "$($repoData.Git.UncommittedChanges) uncommitted changes"
        }
    }
}

# Generate Reports
Write-Host "`n`n📊 Generating audit reports..." -ForegroundColor Cyan

# 1. Executive Summary Report
$executiveSummary = @"
# Tekup Portfolio Executive Summary
**Generated**: $timestamp

## 📈 Portfolio Overview

| Metric | Value |
|--------|-------|
| Total Repositories | $($auditResults.Count) |
| Production Ready (≥70%) | $($auditResults | Where-Object { $_.ProductionReadiness.Score -ge 70 } | Measure-Object | Select-Object -ExpandProperty Count) |
| Active Development | $($repositories | Where-Object { $_.Priority -eq "Active" } | Measure-Object | Select-Object -ExpandProperty Count) |
| Critical Issues | $($criticalIssues.Count) |
| Average Readiness Score | $([math]::Round(($auditResults | Measure-Object -Property {$_.ProductionReadiness.Score} -Average).Average, 1))% |

## 🎯 Priority Classification

| Priority | Count | Repositories |
|----------|-------|--------------|
| Production | $($repositories | Where-Object { $_.Priority -eq "Production" } | Measure-Object | Select-Object -ExpandProperty Count) | $(($repositories | Where-Object { $_.Priority -eq "Production" }).Name -join ", ") |
| Active | $($repositories | Where-Object { $_.Priority -eq "Active" } | Measure-Object | Select-Object -ExpandProperty Count) | $(($repositories | Where-Object { $_.Priority -eq "Active" }).Name -join ", ") |
| Paused | $($repositories | Where-Object { $_.Priority -eq "Paused" } | Measure-Object | Select-Object -ExpandProperty Count) | $(($repositories | Where-Object { $_.Priority -eq "Paused" }).Name -join ", ") |
| Support | $($repositories | Where-Object { $_.Priority -eq "Support" } | Measure-Object | Select-Object -ExpandProperty Count) | $(($repositories | Where-Object { $_.Priority -eq "Support" }).Name -join ", ") |

## 🚨 Critical Issues

$(if ($criticalIssues.Count -gt 0) {
    $criticalIssues | ForEach-Object { "- **$($_.Repo)**: $($_.Issue)" }
} else {
    "✅ No critical issues detected"
})

## 📊 Repository Health Scores

| Repository | Type | Priority | Score | Grade | Git Status |
|------------|------|----------|-------|-------|------------|
$(foreach ($result in $auditResults | Sort-Object -Property {$_.ProductionReadiness.Score} -Descending) {
"| $($result.Name) | $($result.Type) | $($result.Priority) | $($result.ProductionReadiness.Score)/100 | $($result.ProductionReadiness.Grade) | $($result.Git.Branch) ($($result.Git.UncommittedChanges) uncommitted) |"
})

## 🎯 Recommended Focus Areas

### Immediate (This Week)
$(
$productionLowScore = $auditResults | Where-Object { $_.Priority -eq "Production" -and $_.ProductionReadiness.Score -lt 70 }
if ($productionLowScore) {
    $productionLowScore | ForEach-Object { "- **$($_.Name)**: Improve production readiness from $($_.ProductionReadiness.Score)%" }
}

$highUncommitted = $auditResults | Where-Object { $_.Git.UncommittedChanges -gt 20 }
if ($highUncommitted) {
    $highUncommitted | ForEach-Object { "- **$($_.Name)**: Commit or stash $($_.Git.UncommittedChanges) changes" }
}
)

### Short Term (This Month)
- Standardize documentation across all repositories (current avg: $([math]::Round(($auditResults.Documentation.Percentage | Measure-Object -Average).Average, 0))%)
- Implement Docker for non-containerized repos: $(($auditResults | Where-Object { -not $_.Docker.IsContainerized }).Name -join ", ")
- Address TypeScript errors in projects with issues

### Medium Term (This Quarter)
- Consider monorepo consolidation for related projects
- Implement shared configuration packages
- Set up cross-repo CI/CD pipeline

## 📈 Technology Stack Distribution

| Technology | Count |
|------------|-------|
| TypeScript/Node.js | $($repositories | Where-Object { $_.Type -in @("TypeScript", "Monorepo", "Electron") } | Measure-Object | Select-Object -ExpandProperty Count) |
| Python | $($repositories | Where-Object { $_.Type -eq "Python" } | Measure-Object | Select-Object -ExpandProperty Count) |
| Scripts/Utilities | $($repositories | Where-Object { $_.Type -in @("Scripts", "Utility") } | Measure-Object | Select-Object -ExpandProperty Count) |

## 🐳 Containerization Status

| Status | Count | Percentage |
|--------|-------|------------|
| Dockerized | $(($auditResults | Where-Object { $_.Docker.IsContainerized }).Count) | $([math]::Round((($auditResults | Where-Object { $_.Docker.IsContainerized }).Count / $auditResults.Count) * 100, 0))% |
| Not Dockerized | $(($auditResults | Where-Object { -not $_.Docker.IsContainerized }).Count) | $([math]::Round((($auditResults | Where-Object { -not $_.Docker.IsContainerized }).Count / $auditResults.Count) * 100, 0))% |

---
*Next Steps*: Review detailed repository reports in `PORTFOLIO_AUDIT_DETAILED_$timestamp.md`
"@

# 2. Detailed Repository Reports
$detailedReport = @"
# Tekup Portfolio Detailed Analysis
**Generated**: $timestamp

---

$(foreach ($result in $auditResults | Sort-Object -Property Priority, Name) {
@"

## 📦 $($result.Name)

**Type**: $($result.Type) | **Priority**: $($result.Priority) | **Overall Score**: $($result.ProductionReadiness.Score)/100 ⭐ Grade $($result.ProductionReadiness.Grade)

### Git Status
- **Branch**: $($result.Git.Branch)
- **Uncommitted Changes**: $($result.Git.UncommittedChanges)
- **Last Commit**: $($result.Git.LastCommit)
- **Remote**: $($result.Git.RemoteUrl)

$(if ($result.Package) {@"
### Package Configuration
- **Name**: $($result.Package.Name)
- **Version**: $($result.Package.Version)
- **Package Manager**: $($result.Package.PackageManager)
- **Dependencies**: $($result.Package.Dependencies) runtime, $($result.Package.DevDependencies) dev
- **Scripts**: $(if ($result.Package.Scripts.Count -gt 0) { $result.Package.Scripts -join ", " } else { "None" })

**Available Commands**:
$(if ($result.Package.HasBuild) { "- ✅ `npm run build`" } else { "- ❌ No build script" })
$(if ($result.Package.HasTest) { "- ✅ `npm run test`" } else { "- ⚠️ No test script" })
$(if ($result.Package.HasDev) { "- ✅ `npm run dev`" } else { "- ⚠️ No dev script" })
"@})

$(if ($result.TypeScript.HasTypeScript) {@"
### TypeScript Status
- **Errors**: $($result.TypeScript.ErrorCount)
- **Config**: $($result.TypeScript.Config)
"@})

$(if ($result.Python) {@"
### Python Configuration
- **Has requirements.txt**: $($result.Python.HasRequirements)
- **Has pyproject.toml**: $($result.Python.HasPyproject)
- **Dependencies**: $($result.Python.DependencyCount)
"@})

### Docker Configuration
- **Dockerfile**: $(if ($result.Docker.HasDockerfile) { "✅ Present" } else { "❌ Missing" })
- **Docker Compose**: $(if ($result.Docker.HasDockerCompose) { "✅ Present" } else { "❌ Missing" })
- **Containerized**: $(if ($result.Docker.IsContainerized) { "✅ Yes" } else { "⚠️ No" })

### Documentation Score
**Score**: $($result.Documentation.Score)/$($result.Documentation.MaxScore) ($($result.Documentation.Percentage)%)

$(if ($result.Metrics) {@"
### Code Metrics
- **Total Files**: $($result.Metrics.TotalFiles)
- **TypeScript Files**: $($result.Metrics.TypeScriptFiles)
- **JavaScript Files**: $($result.Metrics.JavaScriptFiles)
- **Python Files**: $($result.Metrics.PythonFiles)
- **Markdown Files**: $($result.Metrics.MarkdownFiles)
- **Total Size**: $($result.Metrics.TotalSize) MB
"@})

### Production Readiness Issues
$(if ($result.ProductionReadiness.Issues.Count -gt 0) {
    $result.ProductionReadiness.Issues | ForEach-Object { "- ⚠️ $_" }
} else {
    "✅ No major issues detected"
})

### Recommended Actions
$(
# Generate specific recommendations based on issues
$actions = @()

if ($result.Git.UncommittedChanges -gt 10) {
    $actions += "1. Commit or stash $($result.Git.UncommittedChanges) uncommitted changes"
}

if ($result.Package -and -not $result.Package.HasBuild) {
    $actions += "2. Add build script to package.json"
}

if ($result.Package -and -not $result.Package.HasTest) {
    $actions += "3. Set up testing framework"
}

if (-not $result.Docker.IsContainerized -and $result.Priority -in @("Production", "Active")) {
    $actions += "4. Add Dockerfile and docker-compose.yml for deployment"
}

if ($result.TypeScript.HasTypeScript -and $result.TypeScript.ErrorCount -match "^\d+$" -and [int]$result.TypeScript.ErrorCount -gt 0) {
    $actions += "5. Fix $($result.TypeScript.ErrorCount) TypeScript errors"
}

if ($result.Documentation.Percentage -lt 70) {
    $actions += "6. Improve documentation (currently $($result.Documentation.Percentage)%)"
}

if ($actions.Count -gt 0) {
    $actions -join "`n"
} else {
    "✅ Repository is in good shape. Focus on feature development."
}
)

---
"@
})
"@

# Save reports
$outputPath = "c:\Users\empir\Tekup-Cloud"
$executiveSummaryPath = Join-Path $outputPath "PORTFOLIO_EXECUTIVE_SUMMARY_$timestamp.md"
$detailedReportPath = Join-Path $outputPath "PORTFOLIO_AUDIT_DETAILED_$timestamp.md"

$executiveSummary | Out-File -FilePath $executiveSummaryPath -Encoding UTF8
$detailedReport | Out-File -FilePath $detailedReportPath -Encoding UTF8

# Also create latest versions without timestamp
$executiveSummary | Out-File -FilePath (Join-Path $outputPath "PORTFOLIO_EXECUTIVE_SUMMARY.md") -Encoding UTF8
$detailedReport | Out-File -FilePath (Join-Path $outputPath "PORTFOLIO_AUDIT_DETAILED.md") -Encoding UTF8

Write-Host "`n`n✅ Audit Complete!" -ForegroundColor Green
Write-Host "`n📄 Reports generated:" -ForegroundColor Cyan
Write-Host "   - Executive Summary: $executiveSummaryPath" -ForegroundColor White
Write-Host "   - Detailed Analysis: $detailedReportPath" -ForegroundColor White
Write-Host "`n💡 Review the executive summary first, then dive into detailed analysis as needed." -ForegroundColor Yellow
Write-Host "`nPortfolio Health: $([math]::Round(($auditResults | Measure-Object -Property {$_.ProductionReadiness.Score} -Average).Average, 1))/100" -ForegroundColor $(if ($([math]::Round(($auditResults | Measure-Object -Property {$_.ProductionReadiness.Score} -Average).Average, 1)) -ge 70) { "Green" } else { "Yellow" })
