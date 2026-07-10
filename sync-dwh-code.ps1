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
      - models/L0/ADOBE, models/L1/ADOBE        -> intere cartelle (mirror)
      - models/L0/OCS/AIN, models/L1/OCS/AIN    -> intere cartelle (mirror)
      - snapshots/L1/OCS/AIN                    -> intera cartella (mirror)

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
Copy-RootFilesByExtension -Extensions @(".yml", ".py", ".md", ".ps1")

# --- Models: L2 e L3 completi ---
Mirror-Folder "models\L2"
Mirror-Folder "models\L3"

# --- Models: solo i sample richiesti per L0/L1 ---
Mirror-Folder "models\L0\ADOBE"
Mirror-Folder "models\L1\ADOBE"
Mirror-Folder "models\L0\OCS\AIN"
Mirror-Folder "models\L1\OCS\AIN"

# --- Snapshots: solo il sample richiesto ---
Mirror-Folder "snapshots\L1\OCS\AIN"

Write-Host ""
Write-Host "Sync di raw/dwh-code completato." -ForegroundColor Green
