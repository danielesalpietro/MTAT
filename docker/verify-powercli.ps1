# Build-time gate for the PowerCLI install (see #30): fails the image build unless every installed
# VMware.* module exists in exactly one version and that version is the one install-powercli.ps1
# chose (pins file). An inconsistent mix of PowerCLI releases once made Get-EsxCli fail to load its
# assemblies and returned empty ExtensionData, silently zeroing the analysis.
param([string]$PinsFile = '/opt/mtat-build/powercli-pins.json')
$ErrorActionPreference = 'Stop'

$pins = Get-Content -Raw -Path $PinsFile | ConvertFrom-Json -AsHashtable
$installed = Get-Module -ListAvailable -Name 'VMware.*'
$problems = New-Object System.Collections.Generic.List[string]

foreach ($group in ($installed | Group-Object Name)) {
    if ($group.Count -gt 1) {
        $problems.Add("$($group.Name): multiple versions installed ($(($group.Group.Version | Sort-Object) -join ', '))")
    } elseif (-not $pins.ContainsKey($group.Name)) {
        $problems.Add("$($group.Name) $($group.Group[0].Version): installed but not in the pinned set")
    } elseif ("$($group.Group[0].Version)" -ne $pins[$group.Name]) {
        $problems.Add("$($group.Name): installed $($group.Group[0].Version), pinned $($pins[$group.Name])")
    }
}
foreach ($name in $pins.Keys) {
    if (-not ($installed | Where-Object Name -eq $name)) { $problems.Add("$name $($pins[$name]): pinned but not installed") }
}

if ($problems.Count -eq 0) {
    # Load the module set the engine uses, so a broken mix fails here rather than at runtime.
    Import-Module VMware.VimAutomation.Core
    Get-Module 'VMware.*' | Sort-Object Name | Format-Table Name, Version -AutoSize | Out-String | Write-Host
    # The assembly Get-EsxCli failed to load with the mixed set; it must resolve from this set.
    $sm = Get-ChildItem -Path ($installed | ForEach-Object { $_.ModuleBase }) -Recurse -Filter 'VMware.System.Private.ServiceModel.dll' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sm) {
        $asm = [System.Reflection.Assembly]::LoadFrom($sm.FullName)
        Write-Host "Loaded $($asm.FullName)"
    } else {
        Write-Host "Note: VMware.System.Private.ServiceModel.dll not shipped in this module set."
    }
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "PowerCLI check FAILED: $_" }
    exit 1
}
Write-Host "PowerCLI check passed: $($pins.Count) consistent VMware.* module(s)."
