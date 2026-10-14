# Deterministic PowerCLI install (see #30). Both Install-Module and Install-PSResource resolve a
# dependency declared with a *minimum* version (ModuleVersion) to the newest release in the gallery,
# so even installing the VMware.PowerCLI meta-module at a fixed version pulled 13.5.x sub-modules
# next to 13.3.x ones -- an incompatible mix (Get-EsxCli assembly load failures, empty
# ExtensionData). Here nothing is resolved by the gallery: every module is installed with
# -SkipDependencyCheck at exactly the version its parent manifest names (RequiredVersion, or the
# ModuleVersion minimum itself), walking the RequiredModules tree from the meta-module down.
param([Parameter(Mandatory)][string]$PowerCliVersion, [string]$Repository = 'PSGallery')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$installArgs = @{
    Repository = $Repository; TrustRepository = $true; SkipDependencyCheck = $true
    Scope = 'AllUsers'; Quiet = $true; AcceptLicense = $true
}

function Install-ExactModule([string]$Name, [string]$Version) {
    if (Get-Module -ListAvailable -Name $Name | Where-Object { "$($_.Version)" -eq $Version }) { return }
    Write-Host "Installing $Name $Version"
    Install-PSResource -Name $Name -Version "[$Version]" @installArgs
}

# One version per module: the first requirement reached (breadth-first, so the meta-module's own
# exact pins win) chooses it; later requirements must be satisfied by that choice or the build fails.
$chosen = @{}
$queue = New-Object System.Collections.Generic.Queue[object]
$queue.Enqueue(@{ Name = 'VMware.PowerCLI'; Version = $PowerCliVersion; Exact = $true; By = '(build arg)' })

while ($queue.Count -gt 0) {
    $item = $queue.Dequeue()
    if ($chosen.ContainsKey($item.Name)) {
        $have = [version]$chosen[$item.Name]
        $want = [version]$item.Version
        if (($item.Exact -and $have -ne $want) -or ($have -lt $want)) {
            throw "$($item.By) requires $($item.Name) $(if ($item.Exact) { '==' } else { '>=' }) $($item.Version), but $($chosen[$item.Name]) was already chosen"
        }
        continue
    }
    $chosen[$item.Name] = $item.Version

    Install-ExactModule $item.Name $item.Version
    $module = Get-Module -ListAvailable -Name $item.Name | Where-Object { "$($_.Version)" -eq $item.Version } | Select-Object -First 1
    if (-not $module) { throw "$($item.Name) $($item.Version) not found after install" }

    $manifest = Import-PowerShellDataFile -Path $module.Path
    foreach ($req in @($manifest.RequiredModules)) {
        if ($null -eq $req) { continue }
        if ($req -is [string]) { throw "$($item.Name) requires '$req' without a version -- cannot pin it" }
        $exact = [bool]$req.RequiredVersion
        $version = if ($exact) { $req.RequiredVersion } else { $req.ModuleVersion }
        if (-not $version) { throw "$($item.Name) requires '$($req.ModuleName)' without a version -- cannot pin it" }
        $queue.Enqueue(@{ Name = $req.ModuleName; Version = "$version"; Exact = $exact; By = "$($item.Name) $($item.Version)" })
    }
}
Write-Host "Installed $($chosen.Count) module(s) for VMware.PowerCLI $PowerCliVersion without gallery dependency resolution."
