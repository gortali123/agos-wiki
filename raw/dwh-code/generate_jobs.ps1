Set-StrictMode -Version Latest

# Valori hardcodati
$AccountId = $env:DBT_ACCOUNT_ID
$ProjectId = $env:DBT_PROJECT_ID
$EnvironmentId = $env:DBT_ENVIRONMENT_ID
$Threads = 2
$TargetName = "default"
$Cron = "0 * * * *"

# Parsing argomenti
$InputDir = ''
$OutputFile = 'jobs.yml'
$WithPlus = $false
$FullRefresh = $false

$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        '--input-dir'    { $InputDir = $args[$i + 1]; $i += 2 }
        '--output-file'  { $OutputFile = $args[$i + 1]; $i += 2 }
        '--with-plus'    { $WithPlus = $true; $i += 1 }
        '--full-refresh' { $FullRefresh = $true; $i += 1 }
        default          { $i++ }
    }
}

if ([string]::IsNullOrWhiteSpace($AccountId)) {
    Write-Error "Errore: variabile d'ambiente DBT_ACCOUNT_ID non è impostata"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    Write-Error "Errore: variabile d'ambiente DBT_PROJECT_ID non è impostata"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($EnvironmentId)) {
    Write-Error "Errore: variabile d'ambiente DBT_ENVIRONMENT_ID non è impostata"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($InputDir)) {
    Write-Error "Errore: --input-dir è obbligatorio"
    exit 1
}

if (-not (Test-Path $InputDir -PathType Container)) {
    Write-Error "Errore: cartella '$InputDir' non esiste"
    exit 1
}

Write-Host "[jobs] scanning '$InputDir' ricorsivo..." -ForegroundColor Cyan

# Trova tutti i .sql ricorsivamente
$sqlFiles = Get-ChildItem -Path $InputDir -Filter "*.sql" -Recurse -ErrorAction SilentlyContinue

if ($sqlFiles.Count -eq 0) {
    Write-Warning "Nessun file .sql trovato in '$InputDir'"
    exit 0
}

Write-Host "[jobs] trovati $($sqlFiles.Count) modelli" -ForegroundColor Cyan

# Costruisci job entries
$jobs = @{}

foreach ($file in $sqlFiles) {
    $modelName = $file.BaseName

    # Se inizia con stg_, estrai la parte dopo
    if ($modelName -match '^stg_(.+)$') {
        $modelName = $matches[1]
    }

    # Estrai il livello e la gerarchia dalla path
    $pathParts = $file.DirectoryName -split '\\'
    $level = ''
    $levelIndex = -1
    $source = ''
    $category = ''

    # Trova il livello (L1, L2, etc)
    for ($j = 0; $j -lt $pathParts.Count; $j++) {
        if ($pathParts[$j] -match '^L\d+$') {
            $level = $pathParts[$j]
            $levelIndex = $j
            break
        }
    }

    # Estrai source (prima cartella dopo il livello) e category (seconda cartella dopo il livello)
    if ($levelIndex -ge 0 -and $levelIndex + 1 -lt $pathParts.Count) {
        $source = $pathParts[$levelIndex + 1]
        if ($levelIndex + 2 -lt $pathParts.Count) {
            $category = $pathParts[$levelIndex + 2]
        }
    }

    # Costruisci select clause
    $selectClause = if ($WithPlus) { "+$modelName" } else { $modelName }
    if ($FullRefresh) {
        $selectClause += " --full-refresh"
    }

    # Costruisci job key in base alla regola
    $jobKey = "AGOS_"

    if ($level) {
        $jobKey += "$($level.ToUpper())_"

        if ($level -eq "L1") {
            # In L1: OCS → O, altrimenti → E
            if ($source -eq "OCS") {
                $jobKey += "O"
            } else {
                $jobKey += "E"
            }

            # Aggiungi category se esiste
            if ($category) {
                $categoryName = $category -replace '_$', ''
                $jobKey += "_$($categoryName.ToUpper())"
            } else {
                # Se non c'è category, ripeti la source
                $jobKey += "_$($source.ToUpper())"
            }
        } else {
            # Non L1: usa source intero
            $jobKey += "$($source.ToUpper())"

            # Aggiungi category se esiste
            if ($category) {
                $jobKey += "_$($category.ToUpper())"
            }
        }
    }

    $jobKey += "_$($modelName.ToUpper())"

    # Metadati per description (nomi minuscoli, valori maiuscoli)
    $layerVal = if ($level) { $level.ToUpper() } else { "" }
    $modelVal = $modelName.ToUpper()

    if ($level -eq "L1") {
        $sourceVal = if ($source -eq "OCS") { "OCS" } else { $source.ToUpper() }
        $moduloVal = if ($source -eq "OCS" -and $category) { ($category -replace '_$', '').ToUpper() } else { "" }
        $metadata = @{
            'layer'  = $layerVal
            'source' = $sourceVal
            'modulo' = $moduloVal
            'model'  = $modelVal
        } | ConvertTo-Json -Compress
    } else {
        $subjectAreaVal = if ($source) { $source.ToUpper() } else { "" }
        $metadata = @{
            'layer'         = $layerVal
            'subject_area'  = $subjectAreaVal
            'model'         = $modelVal
        } | ConvertTo-Json -Compress
    }

    $jobs[$jobKey] = @{
        'account_id'          = $AccountId
        'project_id'          = $ProjectId
        'environment_id'      = $EnvironmentId
        'name'                = $jobKey
        'description'         = $metadata
        'execute_steps'       = @("dbt build --select $selectClause")
        'settings'            = @{
            'threads'      = $Threads
            'target_name'  = $TargetName
        }
        'generate_docs'       = $false
        'run_generate_sources' = $false
        'triggers'            = @{
            'schedule'           = $false
            'github_webhook'     = $false
            'git_provider_webhook' = $false
            'on_merge'           = $false
        }
        'schedule'            = @{
            'cron' = $Cron
        }
    }
}

# Converti a YAML con defaults anchor
$yaml = "_defaults: &job_defaults`n"
$yaml += "  account_id: $AccountId`n"
$yaml += "  project_id: $ProjectId`n"
$yaml += "  environment_id: $EnvironmentId`n"
$yaml += "  job_type: `"other`"`n"
$yaml += "  settings:`n"
$yaml += "    threads: $Threads`n"
$yaml += "    target_name: `"$TargetName`"`n"
$yaml += "  generate_docs: false`n"
$yaml += "  run_generate_sources: false`n"
$yaml += "  triggers:`n"
$yaml += "    schedule: false`n"
$yaml += "    github_webhook: false`n"
$yaml += "    git_provider_webhook: false`n"
$yaml += "    on_merge: false`n"
$yaml += "  schedule:`n"
$yaml += "    cron: `"$Cron`"`n"
$yaml += "`njobs:`n"

foreach ($key in $jobs.Keys | Sort-Object) {
    $job = $jobs[$key]
    $yaml += "  $($key):`n"
    $yaml += "    <<: *job_defaults`n"
    $yaml += "    name: `"$($key)`"`n"
    $yaml += "    description: '$($job.description)'`n"
    $yaml += "    execute_steps:`n"
    foreach ($step in $job.execute_steps) {
        $yaml += "      - `"$step`"`n"
    }
}

try {
    Set-Content -Path $OutputFile -Value $yaml -Encoding UTF8
    Write-Host "[jobs] scritto $($jobs.Count) job in '$OutputFile'" -ForegroundColor Green
} catch {
    Write-Error "Errore nella scrittura di '$OutputFile': $_"
    exit 1
}
