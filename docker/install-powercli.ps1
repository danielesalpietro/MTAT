# Deterministic PowerCLI install (see #30). Install-Module / Install-PSResource resolve dependencies
# declared with a *minimum* version (ModuleVersion) to the newest release in the gallery, which mixed
# PowerCLI 13.3 and 13.5 sub-modules in the image (Get-EsxCli assembly load failures, empty
# ExtensionData). And installing the whole VMware.PowerCLI meta-module drags in dozens of SDKs MTAT
# never uses, some with minimum versions the gallery no longer serves.
#
# So: read the exact sub-module versions from the VMware.PowerCLI manifest only (it is never
# installed), then install just VMware.VimAutomation.Core and its RequiredModules closure, each with
# -SkipDependencyCheck at the version the meta-module pins (or, for a module it doesn't list, the
# version the requiring manifest names). One version per module; conflicts fail the build. The
# chosen set is written to a pins file that verify-powercli.ps1 checks.
param(
    [Parameter(Mandatory)][string]$PowerCliVersion,
    [string]$Repository = 'PSGallery',
    [string]$RootModule = 'VMware.VimAutomation.Core',
    [string]$PinsFile = '/opt/mtat-build/powercli-pins.json'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$commonArgs = @{ Repository = $Repository; TrustRepository = $true; SkipDependencyCheck = $true }

# 1. The meta-module's manifest, downloaded to a temp folder only for its version pins.
$metaDir = Join-Path ([IO.Path]::GetTempPath()) "powercli-meta-$PID"
New-Item -ItemType Directory -Path $metaDir -Force | Out-Null
Save-PSResource -Name 'VMware.PowerCLI' -Version "[$PowerCliVersion]" -Path $metaDir @commonArgs
$metaManifestPath = Get-ChildItem -Path $metaDir -Recurse -Filter 'VMware.PowerCLI.psd1' | Select-Object -First 1
if (-not $metaManifestPath) { throw "VMware.PowerCLI $PowerCliVersion manifest not found after download" }
$metaPins = @{}
foreach ($req in @((Import-PowerShellDataFile -Path $metaManifestPath.FullName).RequiredModules)) {
    if ($req -is [hashtable]) {
        $v = if ($req.RequiredVersion) { $req.RequiredVersion } else { $req.ModuleVersion }
        if ($v) { $metaPins[$req.ModuleName] = "$v" }
    }
}
Remove-Item -Recurse -Force $metaDir
if (-not $metaPins.ContainsKey($RootModule)) { throw "VMware.PowerCLI $PowerCliVersion does not pin $RootModule" }
Write-Host "VMware.PowerCLI $PowerCliVersion pins $($metaPins.Count) module(s); installing the $RootModule closure only."

function Install-ExactModule([string]$Name, [string]$Version) {
    if (Get-Module -ListAvailable -Name $Name | Where-Object { "$($_.Version)" -eq $Version }) { return }
    Write-Host "Installing $Name $Version"
    Install-PSResource -Name $Name -Version "[$Version]" -Scope AllUsers -Quiet -AcceptLicense @commonArgs
}

# 2. Breadth-first walk of RequiredModules from the root module.
$chosen = @{}
$unversioned = New-Object System.Collections.Generic.List[object]
$queue = New-Object System.Collections.Generic.Queue[object]
$queue.Enqueue(@{ Name = $RootModule; Version = $metaPins[$RootModule]; Exact = $true; By = "VMware.PowerCLI $PowerCliVersion" })

while ($queue.Count -gt 0) {
    $item = $queue.Dequeue()
    # A bare-name requirement (no version at all) is satisfied by whatever the walk pins elsewhere.
    if (-not $item.Version) { $unversioned.Add($item); continue }
    if ($chosen.ContainsKey($item.Name)) {
        $have = [version]$chosen[$item.Name]; $want = [version]$item.Version
        if (($item.Exact -and $have -ne $want) -or ($have -lt $want)) {
            throw "$($item.By) requires $($item.Name) $(if ($item.Exact) { '==' } else { '>=' }) $($item.Version), but $($chosen[$item.Name]) was already chosen"
        }
        continue
    }
    $chosen[$item.Name] = $item.Version

    Install-ExactModule $item.Name $item.Version
    $module = Get-Module -ListAvailable -Name $item.Name | Where-Object { "$($_.Version)" -eq $item.Version } | Select-Object -First 1
    if (-not $module) { throw "$($item.Name) $($item.Version) not found after install" }

    foreach ($req in @((Import-PowerShellDataFile -Path $module.Path).RequiredModules)) {
        if ($null -eq $req) { continue }
        $by = "$($item.Name) $($item.Version)"
        $name = if ($req -is [string]) { $req } else { $req.ModuleName }
        $declared = if ($req -is [string]) { $null } elseif ($req.RequiredVersion) { "$($req.RequiredVersion)" } elseif ($req.ModuleVersion) { "$($req.ModuleVersion)" } else { $null }
        $exact = ($req -isnot [string]) -and [bool]$req.RequiredVersion
        if ($metaPins.ContainsKey($name)) {
            # The meta-module's pin wins, as long as it honours what this manifest declares.
            if ($declared -and (($exact -and [version]$metaPins[$name] -ne [version]$declared) -or ([version]$metaPins[$name] -lt [version]$declared))) {
                throw "$by requires $name $declared but VMware.PowerCLI $PowerCliVersion pins $($metaPins[$name])"
            }
            $queue.Enqueue(@{ Name = $name; Version = $metaPins[$name]; Exact = $true; By = $by })
        } else {
            $queue.Enqueue(@{ Name = $name; Version = $declared; Exact = $exact; By = $by })
        }
    }
}
foreach ($item in $unversioned) {
    if (-not $chosen.ContainsKey($item.Name)) {
        throw "$($item.By) requires '$($item.Name)' without a version and nothing pins it"
    }
}

$chosen | ConvertTo-Json | Set-Content -Path $PinsFile -Encoding utf8
Write-Host "Installed $($chosen.Count) module(s) for $RootModule from VMware.PowerCLI ${PowerCliVersion}: $(($chosen.Keys | Sort-Object | ForEach-Object { "$_ $($chosen[$_])" }) -join ', ')"
