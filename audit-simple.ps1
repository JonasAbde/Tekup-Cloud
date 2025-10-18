# Tekup Technical Audit Script - Simplified Version
# Generates comprehensive audit report for all Tekup repos

$ErrorActionPreference = "SilentlyContinue"
$repos = @("RendetaljeOS", "Tekup-Billy", "tekup-ai-assistant", "tekup-gmail-automation", "Agent-Orchestrator", "Tekup Google AI", "Tekup-org")
$auditData = @()
$date = Get-Date -Format "yyyyMMdd"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n====================" -ForegroundColor Cyan
Write-Host "TEKUP TECHNICAL AUDIT" -ForegroundColor Cyan
Write-Host "====================`n" -ForegroundColor Cyan

foreach ($repo in $repos) {
    $basePath = "c:\Users\empir\$repo"
    Write-Host "Analyzing: $repo" -ForegroundColor Yellow
    
    $repoInfo = @{
        name = $repo
        language = "Unknown"
        runtime = "Not specified"
        packageManager = "None detected"
        frameworks = @()
        scripts = @{}
        ciCd = @()
        docker = @{
            hasDockerfile = $false
            hasCompose = $false
            baseImage = ""
        }
        infrastructure = @{
            terraform = $false
            bicep = $false
        }
        env = @{
            files = @()
            requiredVars = @()
        }
        ports = @()
        externalDeps = @()
        securityFindings = @()
        quickWins = @()
    }
    
    # PACKAGE.JSON ANALYSIS
    if (Test-Path "$basePath\package.json") {
        $repoInfo.language = "JavaScript/TypeScript"
        try {
            $pkg = Get-Content "$basePath\package.json" -Raw | ConvertFrom-Json
            
            if ($pkg.engines.node) {
                $repoInfo.runtime = "Node.js $($pkg.engines.node)"
            } else {
                $repoInfo.runtime = "Node.js (version not specified)"
            }
            
            if (Test-Path "$basePath\pnpm-lock.yaml") { $repoInfo.packageManager = "pnpm" }
            elseif (Test-Path "$basePath\yarn.lock") { $repoInfo.packageManager = "yarn" }
            elseif (Test-Path "$basePath\package-lock.json") { $repoInfo.packageManager = "npm" }
            else { $repoInfo.packageManager = "npm (no lockfile)" }
            
            if ($pkg.scripts) {
                $repoInfo.scripts = @{
                    dev = $pkg.scripts.dev
                    build = $pkg.scripts.build
                    start = $pkg.scripts.start
                    test = $pkg.scripts.test
                }
            }
            
            $allDeps = @()
            if ($pkg.dependencies) { $allDeps += $pkg.dependencies.PSObject.Properties.Name }
            if ($pkg.devDependencies) { $allDeps += $pkg.devDependencies.PSObject.Properties.Name }
            
            if ($allDeps -contains "next") { $repoInfo.frameworks += "Next.js" }
            if ($allDeps -contains "@nestjs/core") { $repoInfo.frameworks += "NestJS" }
            if ($allDeps -contains "express") { $repoInfo.frameworks += "Express" }
            if ($allDeps -contains "vite") { $repoInfo.frameworks += "Vite" }
            if ($allDeps -contains "react") { $repoInfo.frameworks += "React" }
            if ($allDeps -contains "electron") { $repoInfo.frameworks += "Electron" }
            
            if ($allDeps -match "supabase") { $repoInfo.externalDeps += "Supabase" }
            if ($allDeps -match "google") { $repoInfo.externalDeps += "Google APIs" }
            if ($allDeps -match "openai") { $repoInfo.externalDeps += "OpenAI" }
            if ($allDeps -match "anthropic") { $repoInfo.externalDeps += "Anthropic" }
            if ($allDeps -match "gmail|@googleapis") { $repoInfo.externalDeps += "Gmail API" }
            
            $scriptStr = ($pkg.scripts.PSObject.Properties.Value | Out-String)
            $portMatches = [regex]::Matches($scriptStr, '(?:PORT=|port |:)(\d{4,5})')
            foreach ($match in $portMatches) {
                if ($match.Groups[1].Value -notin $repoInfo.ports) {
                    $repoInfo.ports += [int]$match.Groups[1].Value
                }
            }
        } catch {}
    }
    
    # PYTHON ANALYSIS
    if (Test-Path "$basePath\requirements.txt") {
        $repoInfo.language = "Python"
        $reqs = Get-Content "$basePath\requirements.txt"
        
        if ($reqs -match "fastapi") { $repoInfo.frameworks += "FastAPI" }
        if ($reqs -match "flask") { $repoInfo.frameworks += "Flask" }
        
        if (Test-Path "$basePath\poetry.lock") { $repoInfo.packageManager = "poetry" }
        else { $repoInfo.packageManager = "pip" }
        
        $repoInfo.runtime = "Python 3.x"
    }
    
    if (Test-Path "$basePath\pyproject.toml") {
        $repoInfo.language = "Python"
        $repoInfo.packageManager = "poetry"
    }
    
    # DOCKER ANALYSIS
    if (Test-Path "$basePath\Dockerfile") {
        $repoInfo.docker.hasDockerfile = $true
        try {
            $dockerfile = Get-Content "$basePath\Dockerfile" -Raw
            
            if ($dockerfile -match "FROM\s+([\w\-\./:@]+)") {
                $repoInfo.docker.baseImage = $matches[1]
            }
            
            $exposeMatches = [regex]::Matches($dockerfile, 'EXPOSE\s+(\d+)')
            foreach ($match in $exposeMatches) {
                if ([int]$match.Groups[1].Value -notin $repoInfo.ports) {
                    $repoInfo.ports += [int]$match.Groups[1].Value
                }
            }
        } catch {}
    }
    
    $composeFiles = @("docker-compose.yml", "docker-compose.yaml")
    foreach ($composeFile in $composeFiles) {
        if (Test-Path "$basePath\$composeFile") {
            $repoInfo.docker.hasCompose = $true
            break
        }
    }
    
    # ENV FILES
    $envFiles = @(".env.example", ".env.template")
    foreach ($envFile in $envFiles) {
        if (Test-Path "$basePath\$envFile") {
            $repoInfo.env.files += $envFile
            try {
                $envContent = Get-Content "$basePath\$envFile"
                $envVars = $envContent | Where-Object { $_ -match "^[A-Z_][A-Z0-9_]*=" } | ForEach-Object {
                    if ($_ -match "^([A-Z_][A-Z0-9_]*)=") {
                        $matches[1]
                    }
                }
                $repoInfo.env.requiredVars = ($repoInfo.env.requiredVars + $envVars) | Select-Object -Unique
            } catch {}
        }
    }
    
    # CI/CD
    if (Test-Path "$basePath\.github\workflows") {
        $workflows = Get-ChildItem "$basePath\.github\workflows\*.yml" -ErrorAction SilentlyContinue
        $repoInfo.ciCd += $workflows | ForEach-Object { "GitHub Actions: $($_.BaseName)" }
    }
    
    if (Test-Path "$basePath\render.yaml") {
        $repoInfo.ciCd += "Render"
    }
    
    # INFRASTRUCTURE
    if (Get-ChildItem "$basePath\*.tf" -ErrorAction SilentlyContinue) {
        $repoInfo.infrastructure.terraform = $true
    }
    
    if (Get-ChildItem "$basePath\*.bicep" -ErrorAction SilentlyContinue) {
        $repoInfo.infrastructure.bicep = $true
    }
    
    # SECURITY FINDINGS
    if ($repoInfo.docker.hasDockerfile -and $repoInfo.env.files.Count -eq 0) {
        $repoInfo.securityFindings += @{
            id = "ENV_EXAMPLE_MISSING"
            severity = "medium"
            summary = "Docker setup uden .env.example"
        }
    }
    
    if ($repoInfo.packageManager -match "no lockfile") {
        $repoInfo.securityFindings += @{
            id = "NO_LOCKFILE"
            severity = "medium"
            summary = "Ingen lockfile - versions ikke låst"
        }
    }
    
    # QUICK WINS
    if ($repoInfo.env.files.Count -eq 0 -and $repoInfo.language -ne "Unknown") {
        $repoInfo.quickWins += "Opret .env.example"
    }
    
    if (!$repoInfo.docker.hasDockerfile -and $repoInfo.language -ne "Unknown") {
        $repoInfo.quickWins += "Opret Dockerfile"
    }
    
    if ($repoInfo.ciCd.Count -eq 0) {
        $repoInfo.quickWins += "Setup CI/CD"
    }
    
    $auditData += New-Object PSObject -Property $repoInfo
    Write-Host "  Completed" -ForegroundColor Green
}

Write-Host "`nGenerating reports..." -ForegroundColor Cyan

# GENERATE MARKDOWN REPORT
$md = @()
$md += "# Tekup Audit $date"
$md += ""
$md += "**Genereret:** $timestamp"
$md += "**Scope:** $($repos.Count) repositories"
$md += ""
$md += "---"
$md += ""
$md += "## Executive Summary"
$md += ""
$md += "Denne audit dakker $($repos.Count) repositories i Tekup-okosystemet."
$md += ""
$nodeCount = @($auditData | Where-Object { $_.language -match "JavaScript" }).Count
$pythonCount = @($auditData | Where-Object { $_.language -match "Python" }).Count
$dockerCount = @($auditData | Where-Object { $_.docker.hasDockerfile }).Count
$cicdCount = @($auditData | Where-Object { $_.ciCd.Count -gt 0 }).Count

$md += "### Overordnede fund"
$md += "- **Node.js projekter:** $nodeCount"
$md += "- **Python projekter:** $pythonCount"
$md += "- **Med Docker:** $dockerCount repos"
$md += "- **Med CI/CD:** $cicdCount repos"
$md += ""
$md += "---"
$md += ""
$md += "## Repository Oversigt"
$md += ""
$md += "| Repo | Runtime | Framework | PM | Docker | CI/CD | Ports |"
$md += "|------|---------|-----------|----| -------|-------|-------|"

foreach ($r in $auditData) {
    $frameworks = if ($r.frameworks.Count -gt 0) { $r.frameworks -join ", " } else { "N/A" }
    $ports = if ($r.ports.Count -gt 0) { $r.ports -join ", " } else { "N/A" }
    $dockerIcon = if ($r.docker.hasDockerfile) { "Yes" } else { "No" }
    $cicdIcon = if ($r.ciCd.Count -gt 0) { "Yes" } else { "No" }
    
    $md += "| $($r.name) | $($r.runtime) | $frameworks | $($r.packageManager) | $dockerIcon | $cicdIcon | $ports |"
}

$md += ""
$md += "---"
$md += ""
$md += "## Detaljerede Fund"
$md += ""

foreach ($r in $auditData) {
    $md += "### $($r.name)"
    $md += ""
    $md += "**Teknisk Stack:**"
    $md += "- Sprog: $($r.language)"
    $md += "- Runtime: $($r.runtime)"
    $md += "- Package Manager: $($r.packageManager)"
    $md += "- Frameworks: $($r.frameworks -join ', ')"
    $md += ""
    $md += "**Kommandoer:**"
    $md += "- Dev: $($r.scripts.dev)"
    $md += "- Build: $($r.scripts.build)"
    $md += "- Start: $($r.scripts.start)"
    $md += ""
    $md += "**Docker:**"
    $md += "- Dockerfile: $(if ($r.docker.hasDockerfile) { 'Ja' } else { 'Nej' })"
    if ($r.docker.baseImage) { $md += "- Base Image: $($r.docker.baseImage)" }
    $md += "- Docker Compose: $(if ($r.docker.hasCompose) { 'Ja' } else { 'Nej' })"
    $md += ""
    $md += "**CI/CD:**"
    if ($r.ciCd.Count -gt 0) {
        foreach ($ci in $r.ciCd) {
            $md += "- $ci"
        }
    } else {
        $md += "- Ingen CI/CD konfiguration"
    }
    $md += ""
    $md += "**Miljovariabler:**"
    $md += "- Config filer: $($r.env.files -join ', ')"
    $md += "- Kravede variabler: $($r.env.requiredVars -join ', ')"
    $md += ""
    $md += "**Netvaerk:**"
    $md += "- Porte: $($r.ports -join ', ')"
    $md += "- Eksterne deps: $($r.externalDeps -join ', ')"
    $md += ""
    $md += "**Sikkerhedsfund:**"
    if ($r.securityFindings.Count -gt 0) {
        foreach ($finding in $r.securityFindings) {
            $md += "- [$($finding.severity.ToUpper())] $($finding.id): $($finding.summary)"
        }
    } else {
        $md += "- Ingen kritiske fund"
    }
    $md += ""
    $md += "**Quick Wins:**"
    if ($r.quickWins.Count -gt 0) {
        foreach ($win in $r.quickWins) {
            $md += "- $win"
        }
    } else {
        $md += "- Ingen umiddelbare quick wins"
    }
    $md += ""
    $md += "---"
    $md += ""
}

$md += "## Azure Migration Plan"
$md += ""
$md += "### Anbefalet Azure-arkitektur:"
$md += ""
$md += "- **Compute:** Azure Container Apps eller App Service"
$md += "- **Database:** Azure Database for PostgreSQL (for Supabase-apps)"
$md += "- **Storage:** Azure Blob Storage"
$md += "- **Secrets:** Azure Key Vault"
$md += "- **Monitoring:** Azure Monitor + Application Insights"
$md += "- **CI/CD:** GitHub Actions med Azure"
$md += ""
$md += "---"
$md += ""
$md += "**Rapport genereret:** $timestamp"

# Save Markdown
$mdPath = "c:\Users\empir\Tekup-org\reports\TEKUP_AUDIT_$date.md"
$md | Out-File $mdPath -Encoding UTF8
Write-Host "Markdown rapport: $mdPath" -ForegroundColor Green

# GENERATE JSON
$jsonReport = @{
    meta = @{
        generated = $timestamp
        auditVersion = "1.0"
        totalRepos = $auditData.Count
    }
    repositories = $auditData
}

$jsonPath = "c:\Users\empir\Tekup-org\reports\TEKUP_AUDIT_$date.json"
$jsonReport | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8
Write-Host "JSON rapport: $jsonPath" -ForegroundColor Green

Write-Host "`n==================" -ForegroundColor Green
Write-Host "AUDIT KOMPLET" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green
Write-Host "`nRapporter:" -ForegroundColor Cyan
Write-Host "  MD:  $mdPath"
Write-Host "  JSON: $jsonPath"
Write-Host ""
