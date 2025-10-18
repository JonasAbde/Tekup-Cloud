$repos = @("RendetaljeOS", "Tekup-Billy", "tekup-ai-assistant", "tekup-gmail-automation", "Agent-Orchestrator", "Tekup Google AI", "Tekup-org")
$results = @()

foreach ($repo in $repos) {
    $basePath = "c:\Users\empir\$repo"
    $obj = [PSCustomObject]@{
        Name = $repo
        HasPackageJson = Test-Path "$basePath\package.json"
        HasPythonReqs = Test-Path "$basePath\requirements.txt"
        HasPyproject = Test-Path "$basePath\pyproject.toml"
        HasDockerfile = Test-Path "$basePath\Dockerfile"
        HasDockerCompose = (Test-Path "$basePath\docker-compose.yml") -or (Test-Path "$basePath\docker-compose.yaml")
        HasGithubActions = Test-Path "$basePath\.github\workflows"
        HasEnvExample = Test-Path "$basePath\.env.example"
        HasEnvTemplate = Test-Path "$basePath\.env.template"
    }
    $results += $obj
}

$results | Format-Table -AutoSize
