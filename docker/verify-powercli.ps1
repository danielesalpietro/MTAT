# Build-time gate for the PowerCLI install (see #30). Install-Module -RequiredVersion pins only the
# module named on the command line and resolves every dependency to the newest version available,
# which once produced Core 13.3 next to Common/Sdk 13.5 and VMware.Vim 9.1: Get-EsxCli then failed
# to load its assemblies and ExtensionData came back empty, silently zeroing the analysis.
# Fails the image build unless exactly one version of each VMware.* module is installed and every
# module pinned by the VMware.PowerCLI manifest is present at exactly the pinned version.
param([Parameter(Mandatory)][string]$ExpectedPowerCliVersion)
$ErrorActionPreference = 'Stop'

$installed = Get-Module -ListAvailable -Name 'VMware.*'
$problems = New-Object System.Collections.Generic.List[string]

foreach ($group in ($installed | Group-Object Name | Where-Object Count -gt 1)) {
    $problems.Add("$($group.Name): multiple versions installed ($(($group.Group.Version | Sort-Object) -join ', '))")
}

$meta = $installed | Where-Object Name -eq 'VMware.PowerCLI' | Select-Object -First 1
if (-not $meta) {
    $problems.Add("VMware.PowerCLI is not installed")
} else {
    if ("$($meta.Version)" -ne $ExpectedPowerCliVersion) {
        $problems.Add("VMware.PowerCLI is $($meta.Version), expected $ExpectedPowerCliVersion")
    }
    $manifest = Import-PowerShellDataFile -Path $meta.Path
    foreach ($req in $manifest.RequiredModules) {
        if ($req -isnot [hashtable]) { continue }
        $pinned = if ($req.RequiredVersion) { $req.RequiredVersion } else { $req.ModuleVersion }
        $have = $installed | Where-Object Name -eq $req.ModuleName
        if (-not $have) { $problems.Add("$($req.ModuleName): required $pinned, not installed"); continue }
        if ($req.RequiredVersion -and -not ($have | Where-Object { "$($_.Version)" -eq "$pinned" })) {
            $problems.Add("$($req.ModuleName): installed $(($have.Version) -join ', '), pinned $pinned")
        }
    }
}

Import-Module VMware.VimAutomation.Core
Get-Module 'VMware.*' | Sort-Object Name | Format-Table Name, Version -AutoSize | Out-String | Write-Host

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "PowerCLI check FAILED: $_" }
    exit 1
}
Write-Host "PowerCLI check passed: VMware.PowerCLI $ExpectedPowerCliVersion, $(@($installed).Count) consistent VMware.* modules."
