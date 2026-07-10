Set-StrictMode -Version Latest

function Log([string]$msg) {
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-Host "[$ts] $msg" -ForegroundColor Cyan
}

function Invoke-Dbt {
    param([string[]]$DbtArgs)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $output = @()
    & ./dbt.exe @DbtArgs 2>&1 | ForEach-Object { $output += $_ }
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $old

    if ($exitCode -ne 0) {
        Write-Host "DBT Error (exit code: $exitCode)" -ForegroundColor Red
        Write-Host "---" -ForegroundColor Red
        $output | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        Write-Host "---" -ForegroundColor Red
        exit $exitCode
    }

    return $output
}

function Write-FileRetry([string]$path, [string]$content, [bool]$force = $false) {
    $absPath = [System.IO.Path]::GetFullPath((Join-Path $PWD $path))

    if ((Test-Path $absPath) -and -not $force) {
        Write-Warning "File already exists, skipping: $path (use --force to overwrite)"
        return
    }

    for ($i = 0; $i -lt 20; $i++) {
        try {
            [System.IO.File]::WriteAllText($absPath, $content, (New-Object System.Text.UTF8Encoding $false))
            Start-Sleep -Milliseconds 100
            Write-Host "[awk] wrote $path" -ForegroundColor Green
            return
        } catch {
            if ($i -eq 0) { Write-Host "LOCK su $path, attendo..." -ForegroundColor Yellow }
            Start-Sleep -Milliseconds 500
        }
    }
    Write-Warning "Could not write $path"
}

function Strip-Timestamp([string]$line) {
    return $line -replace '^\d{2}:\d{2}:\d{2}\s+', ''
}

function Resolve-Mod([string]$mod) {
    if ([string]::IsNullOrEmpty($mod)) { return 'unknown' }
    if ($mod -eq 'con')                { return 'con_'    }
    return $mod
}

# Calcola la directory di output in base a sorgente e modulo.
# OCS: base/OCS/{modulo}   — struttura per moduli
# altri: base/{SORGENTE}   — piatta, senza modulo
function Get-OutputDir([string]$base, [string]$sorgente, [string]$modulo) {
    $s = if ([string]::IsNullOrEmpty($sorgente)) { 'UNKNOWN' } else { $sorgente.ToUpper() }
    if ($s -eq 'OCS') {
        return "$base/$s/$(Resolve-Mod $modulo | ForEach-Object { $_.ToUpper() })"
    }
    return "$base/$s"
}

# ---------------------------------------------------------------------------
# dirs base
# ---------------------------------------------------------------------------
$DirL0Base    = 'models/L0'
$DirL1Base    = 'models/L1'
$DirSnapsBase = 'snapshots/L1'

# ---------------------------------------------------------------------------
# parsing argomenti
# ---------------------------------------------------------------------------
$ModelsCsv   = ''
$ModuloVal   = ''
$SorgenteVal = ''
$OnlyCsv     = ''
$Force       = $false
$DbtArgs     = @()

$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        '--models'   { $ModelsCsv   = $args[$i + 1]; $i += 2 }
        '--modulo'   { $ModuloVal   = $args[$i + 1]; $i += 2 }
        '--sorgente' { $SorgenteVal = $args[$i + 1]; $i += 2 }
        '--only'     { $OnlyCsv     = $args[$i + 1]; $i += 2 }
        '--force'    { $Force       = $true; $i += 1 }
        default      { $i++ }
    }
}

if ($ModelsCsv) {
    $modelsArr  = $ModelsCsv -split ',' | ForEach-Object { ($_ -replace '"','').ToUpper() }
    $modelsYaml = '[' + (($modelsArr | ForEach-Object { "`"$_`"" }) -join ',') + ']'
    $DbtArgs    = @('--args', "{model_names: $modelsYaml}")
} elseif ($ModuloVal -or $SorgenteVal) {
    $argsStr = '{model_names: []'
    if ($ModuloVal)   { $argsStr += ", modulo: `"$ModuloVal`"" }
    if ($SorgenteVal) { $argsStr += ", sorgente: `"$(($SorgenteVal -split ',' | ForEach-Object { $_.Trim().ToUpper() }) -join ',')`"" }
    $argsStr += '}'
    $DbtArgs = @('--args', $argsStr)
}

Write-Host "DBT_ARGS: $DbtArgs"

# ---------------------------------------------------------------------------
# --only flag
# ---------------------------------------------------------------------------
$runSources   = $true
$runYaml      = $true
$runModels    = $true
$runSnapshots = $true

if ($OnlyCsv) {
    $runSources = $runYaml = $runModels = $runSnapshots = $false
    foreach ($x in ($OnlyCsv -split ',')) {
        switch ($x.Trim().ToLower()) {
            { $_ -in 'sources','source' }               { $runSources   = $true }
            'yaml'                                       { $runYaml      = $true }
            { $_ -in 'models','model' }                 { $runModels    = $true }
            { $_ -in 'snapshots','snapshot','snaps' }   { $runSnapshots = $true }
            ''                                           { }
            default {
                Write-Error "Unknown --only item: $x (use sources,yaml,models,snapshots)"
                exit 2
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Step 1 – generate_source
# ---------------------------------------------------------------------------
if ($runSources) {
    Log 'Step 1/4: generate_source'

    $lines = Invoke-Dbt (@('run-operation', 'generate_source') + $DbtArgs)

    $script:fileContent = @{}
    $start    = $false
    $tables   = $false
    $hdr      = ''
    $sorgente = ''
    $mod      = ''
    $inTbl    = $false
    $blk      = ''
    $tbl      = ''
    $n        = 0

    function Flush-Source {
        if (-not $script:inTbl) { return }
        $dir = Get-OutputDir $script:DirL0Base $script:sorgente $script:mod
        $null = New-Item -ItemType Directory -Force -Path $dir
        $base = $script:tbl -replace '_deleted$',''
        $out  = "$dir/${base}_source.yml"
        if (-not $script:fileContent.ContainsKey($out)) {
            $script:fileContent[$out] = $script:hdr
        }
        $script:fileContent[$out] += $script:blk
        $script:n++
        $script:inTbl = $false
        $script:blk   = ''
        $script:tbl   = ''
    }

    Write-Host '[awk][source] parsing...' -ForegroundColor DarkGray

    foreach ($rawLine in $lines) {
        if ($rawLine -match '^(Downloading artifacts|Invocation has finished)') { continue }
        $line = Strip-Timestamp $rawLine

        if (-not $start) {
            if ($line -notmatch 'version:\s*2') { continue }
            $start = $true
            $line  = $line -replace '^.*?(version:\s*2)', '$1'
        }

        if (-not $tables) {
            $hdr += $line + "`n"
            if ($line -match '^\s*tables:\s*$') { $tables = $true }
            continue
        }

        if ($line -match '###\s*sorgente:\s*') {
            Flush-Source
            $sorgente = ($line -replace '^.*###\s*sorgente:\s*','') -replace "[`"']",''
            $sorgente = $sorgente.Trim().ToLower()
            continue
        }

        if ($line -match '###\s*modulo:\s*') {
            Flush-Source
            $mod = ($line -replace '^.*###\s*modulo:\s*','') -replace "[`"']",''
            $mod = $mod.Trim().ToLower()
            continue
        }

        if ($line -match '^      - name:\s*') {
            Flush-Source
            $inTbl = $true
            $blk   = $line + "`n"
            $tbl   = ($line -replace '^      - name:\s*','').TrimEnd()
            continue
        }

        if ($inTbl) { $blk += $line + "`n" }
    }
    Flush-Source

    Write-Host "[awk][source] preparing $($script:fileContent.Count) files..." -ForegroundColor DarkGray
    foreach ($path in @($script:fileContent.Keys)) {
        Write-FileRetry $path $script:fileContent[$path] $Force
    }
    Write-Host "[awk][source] total: $n" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Step 2 – generate_yaml
# ---------------------------------------------------------------------------
if ($runYaml) {
    Log 'Step 2/4: generate_yaml'

    $lines = Invoke-Dbt (@('run-operation', 'generate_yaml') + $DbtArgs)

    $script:fileContent = @{}
    $start         = $false
    $inM           = $false
    $blk           = ''
    $name          = ''
    $blockSorgente = ''
    $blockMod      = ''
    $n             = 0

    function Flush-Yaml {
        if (-not $script:inM) { return }
        $dir = Get-OutputDir $script:DirL1Base $script:blockSorgente $script:blockMod
        $null = New-Item -ItemType Directory -Force -Path $dir
        $file = "$dir/$($script:name).yml"
        $script:fileContent[$file] = "version: 2`n`nmodels:`n" + $script:blk
        $script:n++
        $script:inM           = $false
        $script:blk           = ''
        $script:name          = ''
        $script:blockSorgente = ''
        $script:blockMod      = ''
    }

    Write-Host '[awk][yaml] parsing...' -ForegroundColor DarkGray

    foreach ($rawLine in $lines) {
        if ($rawLine -match '^(Downloading artifacts|Invocation has finished)') { continue }
        $line = Strip-Timestamp $rawLine

        if (-not $start) {
            if ($line -notmatch 'version:\s*2') { continue }
            $start = $true
            continue
        }

        # generate_yaml non emette un separatore '---' tra un modello e il successivo
        # (a differenza di generate_model, Step 3): il flush avviene solo qui, quando
        # inizia il blocco del modello successivo (o alla fine, fuori dal loop).
        # - name apre il blocco; ### sorgente e ### modulo seguono e impostano il path
        if ($line -match '^  - name:\s+') {
            Flush-Yaml
            $inM           = $true
            $name          = ($line.Trim() -split '\s+')[2] -replace '"',''
            $name          = $name.ToLower()
            $blk           = $line + "`n"
            $blockSorgente = ''
            $blockMod      = ''
            continue
        }

        if ($line -match '###\s*sorgente:\s*') {
            $blockSorgente = ($line -replace '^.*###\s*sorgente:\s*','') -replace "[`"']",''
            $blockSorgente = $blockSorgente.Trim().ToLower()
            continue
        }

        if ($line -match '###\s*modulo:\s*') {
            $blockMod = ($line -replace '^.*###\s*modulo:\s*','') -replace "[`"']",''
            $blockMod = $blockMod.Trim().ToLower()
            continue
        }

        if ($inM) { $blk += $line + "`n" }
    }
    Flush-Yaml

    Write-Host "[awk][yaml] preparing $($script:fileContent.Count) files..." -ForegroundColor DarkGray
    foreach ($path in @($script:fileContent.Keys)) {
        Write-FileRetry $path $script:fileContent[$path] $Force
    }
    Write-Host "[awk][yaml] total: $n" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Step 3 – generate_model
# ---------------------------------------------------------------------------
if ($runModels) {
    Log 'Step 3/4: generate_model'

    $lines = Invoke-Dbt (@('run-operation', 'generate_model') + $DbtArgs)

    $script:fileContent = @{}
    $sorgente = ''
    $mod      = ''
    $inM      = $false
    $blk      = ''
    $mdl      = ''
    $n        = 0

    function Flush-Model {
        if (-not $script:inM) { return }
        $dir = Get-OutputDir $script:DirL1Base $script:sorgente $script:mod
        $null = New-Item -ItemType Directory -Force -Path $dir
        $file = "$dir/$($script:mdl).sql"
        $script:fileContent[$file] = $script:blk
        $script:n++
        $script:inM = $false
        $script:blk = ''
        $script:mdl = ''
    }

    Write-Host '[awk][model] parsing...' -ForegroundColor DarkGray

    foreach ($rawLine in $lines) {
        if ($rawLine -match '^(Downloading artifacts|Invocation has finished)') { continue }
        $line = Strip-Timestamp $rawLine

        if ($line -match '###\s*sorgente:\s*') {
            $sorgente = ($line -replace '^.*###\s*sorgente:\s*','') -replace "[`"']",''
            $sorgente = $sorgente.Trim().ToLower()
            continue
        }
        if ($line -match '###\s*modulo:\s*') {
            $mod = ($line -replace '^.*###\s*modulo:\s*','') -replace "[`"']",''
            $mod = $mod.Trim().ToLower()
            continue
        }
        if ($line -match '###\s*model:\s*') {
            Flush-Model
            $mdl = ($line -replace '^.*###\s*model:\s*','') -replace "[`"']",''
            $mdl = $mdl.TrimEnd().ToLower()
            $inM = $true
            $blk = ''
            continue
        }
        if ($line -eq '---') {
            Flush-Model
            continue
        }
        if ($inM) { $blk += $line + "`n" }
    }
    Flush-Model

    Write-Host "[awk][model] preparing $($script:fileContent.Count) files..." -ForegroundColor DarkGray
    foreach ($path in @($script:fileContent.Keys)) {
        Write-FileRetry $path $script:fileContent[$path] $Force
    }
    Write-Host "[awk][model] total: $n" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Step 4 – generate_snapshots
# ---------------------------------------------------------------------------
if ($runSnapshots) {
    Log 'Step 4/4: generate_snapshots'

    $lines = Invoke-Dbt (@('run-operation', 'generate_snapshots') + $DbtArgs)

    $script:fileContent = @{}
    $start        = $false
    $inS          = $false
    $blk          = ''
    $name         = ''
    $snapSorgente = ''
    $snapMod      = ''
    $n            = 0

    function Flush-Snap {
        if (-not $script:inS) { return }
        $dir = Get-OutputDir $script:DirSnapsBase $script:snapSorgente $script:snapMod
        $null = New-Item -ItemType Directory -Force -Path $dir
        $file = "$dir/$($script:name).yml"
        $script:fileContent[$file] = "version: 2`n`nsnapshots:`n" + $script:blk
        $script:n++
        $script:inS          = $false
        $script:blk          = ''
        $script:name         = ''
        $script:snapSorgente = ''
        $script:snapMod      = ''
    }

    Write-Host '[awk][snap] parsing...' -ForegroundColor DarkGray

    foreach ($rawLine in $lines) {
        if ($rawLine -match '^(Downloading artifacts|Invocation has finished)') { continue }
        $line = Strip-Timestamp $rawLine

        if (-not $start) {
            if ($line -notmatch 'version:\s*2') { continue }
            $start = $true
            continue
        }

        # generate_snapshots non emette un separatore '---' tra uno snapshot e il
        # successivo (a differenza di generate_model, Step 3): il flush avviene solo
        # qui, quando inizia il blocco dello snapshot successivo (o alla fine, fuori dal loop).
        if ($line -match '^  - name:\s+') {
            Flush-Snap
            $inS          = $true
            $snapSorgente = ''
            $snapMod      = ''
            $name         = ($line.Trim() -split '\s+')[2] -replace '"',''
            $name         = $name.ToLower()
            $blk          = $line + "`n"
            continue
        }

        if ($line -match '###\s*sorgente:\s*') {
            $snapSorgente = ($line -replace '^.*###\s*sorgente:\s*','') -replace "[`"']",''
            $snapSorgente = $snapSorgente.Trim().ToLower()
            continue
        }

        if ($line -match '###\s*modulo:\s*') {
            $snapMod = ($line -replace '^.*###\s*modulo:\s*','') -replace "[`"']",''
            $snapMod = $snapMod.Trim().ToLower()
            continue
        }

        if ($inS) { $blk += $line + "`n" }
    }
    Flush-Snap

    Write-Host "[awk][snap] preparing $($script:fileContent.Count) files..." -ForegroundColor DarkGray
    foreach ($path in @($script:fileContent.Keys)) {
        Write-FileRetry $path $script:fileContent[$path] $Force
    }
    Write-Host "[awk][snap] total: $n" -ForegroundColor DarkGray
}

Log 'All done.'
