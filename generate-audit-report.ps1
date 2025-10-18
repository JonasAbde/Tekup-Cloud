# Tekup Technical Audit Script
# Genererer omfattende audit-rapport for alle Tekup repos

$ErrorActionPreference = "SilentlyContinue"
$repos = @("RendetaljeOS", "Tekup-Billy", "tekup-ai-assistant", "tekup-gmail-automation", "Agent-Orchestrator", "Tekup Google AI", "Tekup-org")
$auditData = @()
$date = Get-Date -Format "yyyyMMdd"

Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  TEKUP TECHNICAL AUDIT - $(Get-Date -Format 'yyyy-MM-dd')        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

foreach ($repo in $repos) {
    $basePath = "c:\Users\empir\$repo"
    Write-Host "🔍 Analyzing: $repo" -ForegroundColor Yellow
    
    $repoInfo = [PSCustomObject]@{
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
    
    # ===== PACKAGE.JSON ANALYSIS =====
    if (Test-Path "$basePath\package.json") {
        $repoInfo.language = "JavaScript/TypeScript"
        try {
            $pkg = Get-Content "$basePath\package.json" -Raw | ConvertFrom-Json
            
            # Runtime
            if ($pkg.engines.node) {
                $repoInfo.runtime = "Node.js $($pkg.engines.node)"
            } else {
                $repoInfo.runtime = "Node.js (version not specified)"
            }
            
            # Package Manager
            if (Test-Path "$basePath\pnpm-lock.yaml") { $repoInfo.packageManager = "pnpm" }
            elseif (Test-Path "$basePath\yarn.lock") { $repoInfo.packageManager = "yarn" }
            elseif (Test-Path "$basePath\package-lock.json") { $repoInfo.packageManager = "npm" }
            else { $repoInfo.packageManager = "npm (no lockfile found)" }
            
            # Scripts
            if ($pkg.scripts) {
                $repoInfo.scripts = @{
                    dev = $pkg.scripts.dev
                    build = $pkg.scripts.build
                    start = $pkg.scripts.start
                    test = $pkg.scripts.test
                }
            }
            
            # Framework Detection
            $allDeps = @()
            if ($pkg.dependencies) { $allDeps += $pkg.dependencies.PSObject.Properties.Name }
            if ($pkg.devDependencies) { $allDeps += $pkg.devDependencies.PSObject.Properties.Name }
            
            if ($allDeps -contains "next") { $repoInfo.frameworks += "Next.js" }
            if ($allDeps -contains "@nestjs/core") { $repoInfo.frameworks += "NestJS" }
            if ($allDeps -contains "express") { $repoInfo.frameworks += "Express" }
            if ($allDeps -contains "vite") { $repoInfo.frameworks += "Vite" }
            if ($allDeps -contains "react") { $repoInfo.frameworks += "React" }
            if ($allDeps -contains "electron") { $repoInfo.frameworks += "Electron" }
            if ($allDeps -contains "socket.io") { $repoInfo.frameworks += "Socket.IO" }
            
            # External Dependencies
            if ($allDeps -match "supabase") { $repoInfo.externalDeps += "Supabase" }
            if ($allDeps -match "google") { $repoInfo.externalDeps += "Google APIs" }
            if ($allDeps -match "openai") { $repoInfo.externalDeps += "OpenAI" }
            if ($allDeps -match "anthropic") { $repoInfo.externalDeps += "Anthropic" }
            if ($allDeps -match "billy") { $repoInfo.externalDeps += "Billy API" }
            if ($allDeps -match "gmail|@googleapis") { $repoInfo.externalDeps += "Gmail/Google API" }
            
            # Port detection from scripts
            $scriptStr = ($pkg.scripts.PSObject.Properties.Value | Out-String)
            $portMatches = [regex]::Matches($scriptStr, '(?:PORT=|port |:)(\d{4,5})')
            foreach ($match in $portMatches) {
                if ($match.Groups[1].Value -notin $repoInfo.ports) {
                    $repoInfo.ports += [int]$match.Groups[1].Value
                }
            }
        } catch {
            Write-Host "  ⚠️  Error parsing package.json" -ForegroundColor Red
        }
    }
    
    # ===== PYTHON ANALYSIS =====
    if (Test-Path "$basePath\requirements.txt") {
        $repoInfo.language = "Python"
        $reqs = Get-Content "$basePath\requirements.txt"
        
        if ($reqs -match "fastapi") { $repoInfo.frameworks += "FastAPI" }
        if ($reqs -match "flask") { $repoInfo.frameworks += "Flask" }
        if ($reqs -match "django") { $repoInfo.frameworks += "Django" }
        
        if (Test-Path "$basePath\poetry.lock") { $repoInfo.packageManager = "poetry" }
        else { $repoInfo.packageManager = "pip" }
        
        $repoInfo.runtime = "Python 3.x"
    }
    
    if (Test-Path "$basePath\pyproject.toml") {
        $repoInfo.language = "Python"
        $repoInfo.packageManager = "poetry"
    }
    
    # ===== DOCKER ANALYSIS =====
    if (Test-Path "$basePath\Dockerfile") {
        $repoInfo.docker.hasDockerfile = $true
        try {
            $dockerfile = Get-Content "$basePath\Dockerfile" -Raw
            
            if ($dockerfile -match "FROM\s+([\w\-\./:@]+)") {
                $repoInfo.docker.baseImage = $matches[1]
            }
            
            # Extract EXPOSE ports
            $exposeMatches = [regex]::Matches($dockerfile, 'EXPOSE\s+(\d+)')
            foreach ($match in $exposeMatches) {
                if ([int]$match.Groups[1].Value -notin $repoInfo.ports) {
                    $repoInfo.ports += [int]$match.Groups[1].Value
                }
            }
        } catch {}
    }
    
    $composeFiles = @("docker-compose.yml", "docker-compose.yaml", "docker-compose.dev.yml")
    foreach ($composeFile in $composeFiles) {
        if (Test-Path "$basePath\$composeFile") {
            $repoInfo.docker.hasCompose = $true
            try {
                $compose = Get-Content "$basePath\$composeFile" -Raw
                
                # Extract ports
                $portMatches = [regex]::Matches($compose, '[\s-]"?(\d{4,5}):\d{4,5}"?')
                foreach ($match in $portMatches) {
                    if ([int]$match.Groups[1].Value -notin $repoInfo.ports) {
                        $repoInfo.ports += [int]$match.Groups[1].Value
                    }
                }
            } catch {}
            break
        }
    }
    
    # ===== ENV FILES ANALYSIS =====
    $envFiles = @(".env.example", ".env.template", ".env.sample")
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
    
    # ===== CI/CD ANALYSIS =====
    if (Test-Path "$basePath\.github\workflows") {
        $workflows = Get-ChildItem "$basePath\.github\workflows\*.yml", "$basePath\.github\workflows\*.yaml" -ErrorAction SilentlyContinue
        $repoInfo.ciCd += $workflows | ForEach-Object { "GitHub Actions: $($_.BaseName)" }
    }
    
    if (Test-Path "$basePath\render.yaml") {
        $repoInfo.ciCd += "Render"
    }
    
    if (Test-Path "$basePath\azure-pipelines.yml") {
        $repoInfo.ciCd += "Azure Pipelines"
    }
    
    # ===== INFRASTRUCTURE ANALYSIS =====
    if (Get-ChildItem "$basePath\*.tf" -ErrorAction SilentlyContinue) {
        $repoInfo.infrastructure.terraform = $true
    }
    
    if (Get-ChildItem "$basePath\*.bicep" -ErrorAction SilentlyContinue) {
        $repoInfo.infrastructure.bicep = $true
    }
    
    # ===== SECURITY FINDINGS =====
    # Check for missing .env.example
    if ($repoInfo.docker.hasDockerfile -and $repoInfo.env.files.Count -eq 0) {
        $repoInfo.securityFindings += @{
            id = "ENV_EXAMPLE_MISSING"
            severity = "medium"
            summary = "Docker setup without .env.example - unclear miljøkrav"
        }
    }
    
    # Check for CORS if Express detected
    if ($repoInfo.frameworks -contains "Express") {
        $repoInfo.securityFindings += @{
            id = "CORS_CHECK_NEEDED"
            severity = "low"
            summary = "Verificér CORS konfiguration i Express app"
        }
    }
    
    # No lockfile
    if ($repoInfo.packageManager -match "no lockfile") {
        $repoInfo.securityFindings += @{
            id = "NO_LOCKFILE"
            severity = "medium"
            summary = "Ingen package lockfile - dependency versioner ikke låst"
        }
    }
    
    # ===== QUICK WINS =====
    if ($repoInfo.env.files.Count -eq 0 -and $repoInfo.language -ne "Unknown") {
        $repoInfo.quickWins += "Opret .env.example med alle nødvendige miljøvariabler"
    }
    
    if (!$repoInfo.docker.hasDockerfile -and $repoInfo.language -ne "Unknown") {
        $repoInfo.quickWins += "Opret Dockerfile for containerization"
    }
    
    if ($repoInfo.ciCd.Count -eq 0) {
        $repoInfo.quickWins += "Opsæt GitHub Actions CI/CD pipeline"
    }
    
    if (!$repoInfo.scripts.test) {
        $repoInfo.quickWins += "Tilføj test script til package.json"
    }
    
    $auditData += $repoInfo
    Write-Host "  ✅ Completed" -ForegroundColor Green
}

Write-Host "`n📝 Generating reports..." -ForegroundColor Cyan

# ===== GENERATE MARKDOWN REPORT =====
$mdReport = @'
# Tekup Audit {0}
**Genereret:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Auditor:** Technical Assessment Agent  
**Scope:** 7 Tekup repositories

---

## Executive Summary

Denne audit dækker $($repos.Count) repositories i Tekup-økosystemet. Rapporten identificerer teknisk stack, deployment-status, sikkerhedsfund og Azure-parathed.

### Overordnede fund
- **Node.js projekter:** $(@($auditData | Where-Object { $_.language -match "JavaScript" }).Count)
- **Python projekter:** $(@($auditData | Where-Object { $_.language -match "Python" }).Count)
- **Med Docker:** $(@($auditData | Where-Object { $_.docker.hasDockerfile }).Count) repos
- **Med CI/CD:** $(@($auditData | Where-Object { $_.ciCd.Count -gt 0 }).Count) repos
- **Totale sikkerhedsfund:** $(@($auditData | ForEach-Object { $_.securityFindings }).Count)

---

## Repository Oversigt

| Repo | Runtime | Framework | PM | Start cmd | Docker | CI/CD | Infra | Env files | Ports |
|------|---------|-----------|----|-----------| -------|-------|-------|-----------|-------|
"@

foreach ($r in $auditData) {
    $frameworks = if ($r.frameworks.Count -gt 0) { $r.frameworks -join ", " } else { "N/A" }
    $ports = if ($r.ports.Count -gt 0) { $r.ports -join ", " } else { "N/A" }
    $envFiles = if ($r.env.files.Count -gt 0) { $r.env.files.Count } else { "0" }
    $cicd = if ($r.ciCd.Count -gt 0) { "✅" } else { "❌" }
    $docker = if ($r.docker.hasDockerfile) { "✅" } else { "❌" }
    $infra = if ($r.infrastructure.terraform -or $r.infrastructure.bicep) { "✅" } else { "❌" }
    
    $mdReport += "`n| $($r.name) | $($r.runtime) | $frameworks | $($r.packageManager) | $($r.scripts.start) | $docker | $cicd | $infra | $envFiles | $ports |"
}

$mdReport += @"


---

## Detaljerede Fund pr. Repo

"@

foreach ($r in $auditData) {
    $mdReport += @"

### $($r.name)

**Teknisk Stack:**
- **Sprog:** $($r.language)
- **Runtime:** $($r.runtime)
- **Package Manager:** $($r.packageManager)
- **Frameworks:** $($r.frameworks -join ', ')

**Kommandoer:**
- **Dev:** ``$($r.scripts.dev)``
- **Build:** ``$($r.scripts.build)``
- **Start:** ``$($r.scripts.start)``

**Docker:**
- **Dockerfile:** $(if ($r.docker.hasDockerfile) { "✅ Ja" } else { "❌ Nej" })
$(if ($r.docker.baseImage) { "- **Base Image:** ``$($r.docker.baseImage)``" })
- **Docker Compose:** $(if ($r.docker.hasCompose) { "✅ Ja" } else { "❌ Nej" })

**CI/CD:**
$(if ($r.ciCd.Count -gt 0) {
    foreach ($ci in $r.ciCd) {
        "- $ci"
    }
} else {
    "- ❌ Ingen CI/CD konfiguration fundet"
})

**Infrastruktur:**
- **Terraform:** $(if ($r.infrastructure.terraform) { "✅" } else { "❌" })
- **Bicep:** $(if ($r.infrastructure.bicep) { "✅" } else { "❌" })

**Miljøvariabler:**
- **Config filer:** $($r.env.files -join ', ')
- **Krævede variabler:** $($r.env.requiredVars -join ', ')

**Netværk:**
- **Porte:** $($r.ports -join ', ')
- **Eksterne dependencies:** $($r.externalDeps -join ', ')

**Sikkerhedsfund:**
$(if ($r.securityFindings.Count -gt 0) {
    foreach ($finding in $r.securityFindings) {
        "- **[$($finding.severity.ToUpper())]** $($finding.id): $($finding.summary)"
    }
} else {
    "- ✅ Ingen kritiske fund"
})

**Quick Wins (24-72h):**
$(if ($r.quickWins.Count -gt 0) {
    foreach ($win in $r.quickWins) {
        "- $win"
    }
} else {
    "- ✅ Ingen umiddelbare quick wins identificeret"
})

---

"@
}

$mdReport += @"

## Azure Migration Plan

### Anbefalet Azure-arkitektur pr. repo:

"@

foreach ($r in $auditData) {
    if ($r.language -ne "Unknown") {
        $mdReport += @"

#### $($r.name)
- **Compute:** 
$(if ($r.docker.hasDockerfile) {
    "  - Azure Container Apps (anbefalet - har Dockerfile)"
} else {
    "  - Azure App Service (Node.js/Python runtime)"
})
- **Database:** $(if ($r.externalDeps -contains "Supabase") { "Azure Database for PostgreSQL" } else { "Ingen DB påkrævet" })
- **Storage:** Azure Blob Storage (for filer/assets)
- **Secrets:** Azure Key Vault (migrér env variabler)
- **Monitoring:** Azure Monitor + Application Insights
- **CI/CD:** Azure DevOps Pipelines eller GitHub Actions → Azure

"@
    }
}

$mdReport += @"

### Generel Azure Migration Checklist:
1. **Opret Azure Resource Group** for Tekup-økosystem
2. **Opsæt Azure Key Vault** og migrér alle secrets fra .env filer
3. **Konfigurér Azure Container Registry** for Docker images
4. **Deploy Container Apps** eller App Services pr. repo
5. **Opsæt Azure Front Door** for routing og SSL
6. **Implementér Azure Monitor** dashboards
7. **Konfigurér Azure AD** for authentication
8. **Opsæt backup policies** for databaser og storage

---

## Hurtige Gevinster (24-72h)

### Kritiske:
1. **Manglende .env.example filer** - dokumentér miljøkrav
2. **Ingen CI/CD** - opsæt GitHub Actions workflows
3. **Missing lockfiles** - commit package-lock.json/pnpm-lock.yaml

### Medium prioritet:
1. **Docker standardisering** - ensartet Dockerfile struktur
2. **Test coverage** - tilføj test scripts
3. **Dependency audit** - ``npm audit`` / ``safety check``

---

## 30-dages Roadmap

### Uge 1: Stabilisering
- [ ] Opret manglende .env.example filer
- [ ] Opsæt CI/CD for alle repos
- [ ] Kør security audit på dependencies
- [ ] Dokumentér start-procedurer

### Uge 2: Containerization
- [ ] Standardisér Dockerfiles
- [ ] Opret docker-compose for lokal udvikling
- [ ] Test multi-container setup

### Uge 3: Azure Foundation
- [ ] Opret Azure subscription og resource groups
- [ ] Opsæt Azure Key Vault
- [ ] Konfigurér Container Registry
- [ ] Pilot deploy én service

### Uge 4: Full Migration
- [ ] Deploy alle services til Azure
- [ ] Opsæt monitoring og alerts
- [ ] Implementér backup strategi
- [ ] Dokumentér Azure-arkitektur

---

**Rapport genereret:** {1}  
**Næste audit anbefales:** {2}
'@

# Format and Save Markdown Report
$mdPath = "c:\Users\empir\Tekup-org\reports\TEKUP_AUDIT_$date.md"
$mdFormatted = $mdReport -f $date, (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), ((Get-Date).AddMonths(1).ToString("yyyy-MM-dd"))
$mdFormatted | Out-File $mdPath -Encoding UTF8
Write-Host "✅ Markdown rapport: $mdPath" -ForegroundColor Green

# ===== GENERATE JSON REPORT =====
$jsonReport = @{
    meta = @{
        generated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        auditVersion = "1.0"
        totalRepos = $auditData.Count
    }
    repositories = $auditData
}

$jsonPath = "c:\Users\empir\Tekup-org\reports\TEKUP_AUDIT_$date.json"
$jsonReport | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8
Write-Host "✅ JSON rapport: $jsonPath" -ForegroundColor Green

Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  AUDIT KOMPLET                                   ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "`nRapporter genereret i:" -ForegroundColor Cyan
Write-Host "  📄 $mdPath"
Write-Host "  📊 $jsonPath"
Write-Host ""
