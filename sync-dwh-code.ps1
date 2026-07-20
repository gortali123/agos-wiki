<#
.SYNOPSIS
    Sincronizza raw/dwh-code/ (vendored snapshot in questa wiki) direttamente dalla repo
    sorgente dwh-x-dbt (clone locale del progetto GitLab), senza passare dalla repo
    intermedia my_dwh-x-dbt.

.DESCRIPTION
    Va lanciato DENTRO agos-wiki (stessa cartella di CLAUDE.md). Si aspetta che dwh-x-dbt
    sia una cartella sibling di agos-wiki (stessa cartella padre).

    Copia dentro raw/dwh-code/:
      - macros/, templates/, tests/            -> intere cartelle (mirror)
      - *.yml, *.py, *.md, *.ps1 a livello radice della repo sorgente
      - models/L2, models/L3                    -> intere cartelle (mirror)
      - models/L0/<tutte le sorgenti tranne OCS> -> intere cartelle (mirror, enumerate dinamicamente)
      - models/L0/OCS/AIN                       -> intera cartella (mirror, sample)
      - models/L1/<tutte le sorgenti tranne OCS> -> intere cartelle (mirror, enumerate dinamicamente)
      - models/L1/OCS/AIN                       -> intera cartella (mirror, sample)
      - snapshots/L1/<tutte le sorgenti tranne OCS> -> intere cartelle (mirror, enumerate dinamicamente)
      - snapshots/L1/OCS/AIN                    -> intera cartella (mirror, sample)

    Usa robocopy /MIR per le cartelle intere, cosi' facendo rimuove anche i file
    cancellati a monte nel sottoinsieme sincronizzato. Non tocca nient'altro nella
    destinazione (es. non tocca altre sottocartelle di models/L0, models/L1, snapshots/L1
    che non fanno parte del campione scelto).
#>

[CmdletBinding()]
param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$WikiRoot = $PSScriptRoot
$Dest = Join-Path $WikiRoot "raw\dwh-code"
$Source = Resolve-Path (Join-Path $WikiRoot "..\dwh-x-dbt") -ErrorAction Stop

Write-Host "Sorgente:      $Source"
Write-Host "Destinazione:  $Dest"
if ($WhatIf) { Write-Host "Modalita' WhatIf: nessuna modifica verra' scritta." -ForegroundColor Yellow }
Write-Host ""

function Mirror-Folder {
    param([string]$RelativePath)

    $src = Join-Path $Source $RelativePath
    $dst = Join-Path $Dest $RelativePath

    if (-not (Test-Path $src)) {
        Write-Warning "Skip (non trovato in sorgente): $RelativePath"
        return
    }

    Write-Host "Mirror: $RelativePath"
    $robocopyArgs = @($src, $dst, "/MIR", "/NFL", "/NDL", "/NJH", "/NJS", "/NP")
    if ($WhatIf) { $robocopyArgs += "/L" }

    robocopy @robocopyArgs | Out-Null
    # Robocopy exit codes 0-7 sono successo; >=8 e' errore.
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy ha fallito su '$RelativePath' (exit code $LASTEXITCODE)"
    }
}

function Copy-RootFilesByExtension {
    param([string[]]$Extensions)

    Get-ChildItem -Path $Source -File | Where-Object {
        $Extensions -contains $_.Extension.ToLowerInvariant()
    } | ForEach-Object {
        Write-Host "Copia file radice: $($_.Name)"
        if (-not $WhatIf) {
            Copy-Item -Path $_.FullName -Destination (Join-Path $Dest $_.Name) -Force
        }
    }
}

if (-not $WhatIf -and -not (Test-Path $Dest)) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
}

# --- Cartelle intere ---
Mirror-Folder "macros"
Mirror-Folder "templates"
Mirror-Folder "tests"

# --- File sciolti nella root della repo sorgente ---
Copy-RootFilesByExtension -Extensions @(".yml", ".py", ".md", ".ps1", ".csv")

# --- Models: L2 e L3 completi ---
Mirror-Folder "models\L2"
Mirror-Folder "models\L3"

# --- Models: L0 completo per tutte le sorgenti tranne OCS; di OCS solo AIN ---
$L0Source = Join-Path $Source "models\L0"
if (Test-Path $L0Source) {
    Get-ChildItem -Path $L0Source -Directory | ForEach-Object {
        if ($_.Name -eq "OCS") {
            Mirror-Folder "models\L0\OCS\AIN"
        } else {
            Mirror-Folder "models\L0\$($_.Name)"
        }
    }
} else {
    Write-Warning "Skip (non trovato in sorgente): models\L0"
}

# --- Models: L1 completo per tutte le sorgenti tranne OCS; di OCS solo AIN ---
$L1Source = Join-Path $Source "models\L1"
if (Test-Path $L1Source) {
    Get-ChildItem -Path $L1Source -Directory | ForEach-Object {
        if ($_.Name -eq "OCS") {
            Mirror-Folder "models\L1\OCS\AIN"
        } else {
            Mirror-Folder "models\L1\$($_.Name)"
        }
    }
} else {
    Write-Warning "Skip (non trovato in sorgente): models\L1"
}

# --- Snapshots: L1 completo per tutte le sorgenti tranne OCS; di OCS solo AIN ---
$SnapshotsSource = Join-Path $Source "snapshots\L1"
if (Test-Path $SnapshotsSource) {
    Get-ChildItem -Path $SnapshotsSource -Directory | ForEach-Object {
        if ($_.Name -eq "OCS") {
            Mirror-Folder "snapshots\L1\OCS\AIN"
        } else {
            Mirror-Folder "snapshots\L1\$($_.Name)"
        }
    }
} else {
    Write-Warning "Skip (non trovato in sorgente): snapshots\L1"
}

Write-Host ""
Write-Host "Sync di raw/dwh-code completato." -ForegroundColor Green
