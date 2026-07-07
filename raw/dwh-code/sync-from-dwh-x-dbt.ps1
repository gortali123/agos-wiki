<#
.SYNOPSIS
    Allinea questa repo (my_dwh-x-dbt, copia curata pubblicata su GitHub) con un sottoinsieme
    del contenuto della repo sorgente dwh-x-dbt (clone locale del progetto GitLab).

.DESCRIPTION
    Va lanciato DENTRO my_dwh-x-dbt. Si aspetta che dwh-x-dbt sia una cartella sibling
    (stessa cartella padre di my_dwh-x-dbt).

    Copia:
      - macros/, templates/, tests/            -> intere cartelle (mirror)
      - *.yml, *.py, *.md, *.ps1 a livello radice della repo sorgente
      - models/L2, models/L3                    -> intere cartelle (mirror)
      - models/L0/ADOBE, models/L1/ADOBE        -> intere cartelle (mirror)
      - models/L0/OCS/AIN, models/L1/OCS/AIN    -> intere cartelle (mirror)
      - snapshots/L1/OCS/AIN                    -> intera cartella (mirror)

    Usa robocopy /MIR per le cartelle intere, cosi' facendo rimuove anche i file
    cancellati a monte. Non tocca nient'altro nella destinazione.
#>

[CmdletBinding()]
param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$Dest = $PSScriptRoot
$Source = Resolve-Path (Join-Path $Dest "..\dwh-x-dbt") -ErrorAction Stop

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
Write-Host "Allineamento completato." -ForegroundColor Green
