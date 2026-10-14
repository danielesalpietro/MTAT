# MTAT DIGITAL TWIN (#47). Simulates only the PowerCLI calls and object properties MTAT_v3_1.ps1
# actually uses, so the engine can be exercised end-to-end without a lab. Everything comes from the
# JSON scenario named by $env:MTAT_TWIN_SCENARIO; nothing here reaches the network.
#
# Property shapes mirror what MTAT reads (see the inventory in #47). When a recording from a real
# vCenter disagrees with this file, the twin is wrong: fix it here, not in MTAT.

$ErrorActionPreference = 'Stop'

if (-not $env:MTAT_TWIN_SCENARIO -or -not (Test-Path $env:MTAT_TWIN_SCENARIO)) {
    throw "MTAT digital twin: MTAT_TWIN_SCENARIO is not set or the file '$($env:MTAT_TWIN_SCENARIO)' does not exist."
}
$script:Scenario = Get-Content -Raw -Path $env:MTAT_TWIN_SCENARIO | ConvertFrom-Json -AsHashtable
Write-Host "[TWIN] *** MTAT DIGITAL TWIN active: simulated vCenter(s) from scenario '$($script:Scenario.name)' ($env:MTAT_TWIN_SCENARIO). Not a real vSphere environment. ***"

if ($null -eq $global:DefaultVIServers) { $global:DefaultVIServers = @() }

# ---- helpers -------------------------------------------------------------------------------------

function script:New-TwinMoRef([string]$Type, [string]$Value) {
    $m = [pscustomobject]@{ Type = $Type; Value = $Value }
    $m | Add-Member -MemberType ScriptMethod -Name ToString -Value { "$($this.Type)-$($this.Value)" } -Force
    $m
}

function script:Get-TwinVCenter([string]$Name) {
    $vc = $script:Scenario.vcenters | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if (-not $vc) { throw "Could not resolve the requested VC server '$Name' (not in twin scenario '$($script:Scenario.name)')." }
    $vc
}

function script:Get-ServerName($Server) {
    if ($null -eq $Server) {
        if (@($global:DefaultVIServers).Count -eq 0) { throw "You are not currently connected to any servers." }
        return @($global:DefaultVIServers)[0].Name
    }
    if ($Server -is [string]) { return $Server }
    return $Server.Name
}

# Host-level placement: one entry per (vCenter, cluster, host) so lookups by name or id are cheap.
function script:Get-TwinHostIndex {
    foreach ($vc in $script:Scenario.vcenters) {
        foreach ($cl in @($vc.clusters)) {
            foreach ($h in @($cl.hosts)) { [pscustomobject]@{ Vc = $vc; Cluster = $cl; Host = $h } }
        }
    }
}

function script:New-TwinHostObject($vc, $cl, $h) {
    $memMB = if ($h.realtime) { [double]$h.realtime.memUsageMB } else { 0 }
    $cpuMhz = if ($h.realtime) { [double]$h.realtime.cpuUsageMhz } else { 0 }
    [pscustomobject]@{
        Name          = $h.name
        Id            = "HostSystem-host-$($h.name)"
        Version       = $h.version
        Build         = $h.build
        TwinVc        = $vc.name
        TwinCluster   = $cl.name
        ExtensionData = [pscustomobject]@{
            MoRef    = (New-TwinMoRef 'HostSystem' "host-$($h.name)")
            Hardware = [pscustomobject]@{ CpuInfo = [pscustomobject]@{ Hz = [long]$h.cpu.mhz * 1000000; NumCpuCores = [int]$h.cpu.cores } }
            Summary  = [pscustomobject]@{ QuickStats = [pscustomobject]@{ OverallCpuUsage = $cpuMhz; OverallMemoryUsage = $memMB } }
        }
    }
}

function script:New-TwinVmObject($vc, $cl, $h, $vm) {
    $extra = @()
    if ($vm.extraConfig) { foreach ($k in $vm.extraConfig.Keys) { $extra += [pscustomobject]@{ Key = $k; Value = "$($vm.extraConfig[$k])" } } }
    $activeMB = if ($vm.realtime) { [double]$vm.realtime.activeMB } else { 0 }
    [pscustomobject]@{
        Name          = $vm.name
        Id            = "VirtualMachine-vm-$($vm.name)"
        MemoryGB      = [double]$vm.memoryGB
        NumCpu        = [int]$vm.vcpu
        PowerState    = if ($vm.powerState) { $vm.powerState } else { 'poweredOn' }
        VMHost        = [pscustomobject]@{ Name = $h.name }
        ExtensionData = [pscustomobject]@{
            Summary = [pscustomobject]@{ QuickStats = [pscustomobject]@{ GuestMemoryUsage = $activeMB } }
            Config  = [pscustomobject]@{
                MemoryReservationLockedToMax = [bool]$vm.pinned
                ExtraConfig                  = $extra
                LatencySensitivity           = [pscustomobject]@{ Level = $(if ($vm.latencySensitivity) { $vm.latencySensitivity } else { 'normal' }) }
            }
        }
    }
}

# Deterministic series: exactly one sample at the peak, all others equal, so that Average == avg and
# Maximum == peak exactly -- which makes the expected MTAT numbers computable by hand.
function script:New-TwinSeries([double]$Avg, [double]$Peak, [int]$Count) {
    if ($Count -le 1) { return ,@($Peak) }
    if ($Peak -lt $Avg) { $Peak = $Avg }
    $rest = (($Avg * $Count) - $Peak) / ($Count - 1)
    if ($rest -lt 0) { $rest = 0 }
    $values = New-Object double[] $Count
    for ($i = 0; $i -lt $Count; $i++) { $values[$i] = $rest }
    $values[[int]($Count / 2)] = $Peak
    ,$values
}

# ---- cmdlets used by MTAT ------------------------------------------------------------------------

function Set-PowerCLIConfiguration { [CmdletBinding()] param([Parameter(ValueFromRemainingArguments)]$Rest) }

function Connect-VIServer {
    [CmdletBinding()]
    param([string]$Server, [string]$User, [string]$Password, [Parameter(ValueFromRemainingArguments)]$Rest)
    $vc = Get-TwinVCenter $Server
    if ($vc.login -and $vc.login.error) { throw $vc.login.error }
    if ($vc.login -and $vc.login.allowedUsers -and ($vc.login.allowedUsers -notcontains $User)) {
        throw "Cannot complete login due to an incorrect user name or password."
    }
    $session = [pscustomobject]@{ Name = $vc.name; Version = $vc.version; User = $User; IsConnected = $true }
    $global:DefaultVIServers = @(@($global:DefaultVIServers) | Where-Object { $_.Name -ne $vc.name }) + $session
    $session
}

function Disconnect-VIServer {
    [CmdletBinding()]
    param($Server, [switch]$Force, [Parameter(ValueFromRemainingArguments)]$Rest)
    $name = Get-ServerName $Server
    $global:DefaultVIServers = @(@($global:DefaultVIServers) | Where-Object { $_.Name -ne $name })
}

function Get-Cluster {
    [CmdletBinding()]
    param([Parameter(Position = 0)][string]$Name, $Server, [Parameter(ValueFromRemainingArguments)]$Rest)
    $vc = Get-TwinVCenter (Get-ServerName $Server)
    foreach ($cl in @($vc.clusters)) {
        if ($Name -and $cl.name -ne $Name) { continue }
        [pscustomobject]@{
            Name          = $cl.name
            TwinVc        = $vc.name
            ExtensionData = [pscustomobject]@{ MoRef = (New-TwinMoRef 'ClusterComputeResource' "cl-$($vc.name)-$($cl.name)") }
        }
    }
}

function Get-VMHost {
    [CmdletBinding()]
    param($Location, $Server, [Parameter(ValueFromRemainingArguments)]$Rest)
    foreach ($e in (Get-TwinHostIndex)) {
        if ($Location -and ($e.Cluster.name -ne $Location.Name -or $e.Vc.name -ne $Location.TwinVc)) { continue }
        New-TwinHostObject $e.Vc $e.Cluster $e.Host
    }
}

function Get-VM {
    [CmdletBinding()]
    param([string]$Id, $Server, [Parameter(ValueFromRemainingArguments)]$Rest)
    foreach ($e in (Get-TwinHostIndex)) {
        foreach ($vm in @($e.Host.vms)) {
            if ($Id -and "VirtualMachine-vm-$($vm.name)" -ne $Id) { continue }
            # Reproduces the PowerCLI failure mode MTAT isolates per VM (malformed config data).
            if ($vm.unresolvable) { throw "Sequence contains no elements" }
            New-TwinVmObject $e.Vc $e.Cluster $e.Host $vm
        }
    }
}

function Get-View {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]$VIObject, [string]$ViewType, $SearchRoot, [string[]]$Property,
        $Id, $Server, [Parameter(ValueFromRemainingArguments)]$Rest
    )
    $serverName = Get-ServerName $Server
    if ($VIObject -is [string] -and $VIObject -eq 'ServiceInstance') {
        return [pscustomobject]@{ Content = [pscustomobject]@{ PerfManager = [pscustomobject]@{ TwinType = 'PerfManager'; TwinVc = $serverName } } }
    }
    if ($VIObject -and $VIObject.TwinType -eq 'PerfManager') {
        $vc = Get-TwinVCenter $VIObject.TwinVc
        $intervals = foreach ($i in @($vc.statsIntervals)) {
            [pscustomobject]@{ Key = [int]$i.key; Name = $i.name; SamplingPeriod = [int]$i.samplingPeriod; Level = [int]$i.level; Enabled = [bool]$i.enabled }
        }
        return [pscustomobject]@{ HistoricalInterval = @($intervals) }
    }
    if ($ViewType -eq 'VirtualMachine') {
        foreach ($e in (Get-TwinHostIndex)) {
            if ($SearchRoot -and "cl-$($e.Vc.name)-$($e.Cluster.name)" -ne $SearchRoot.Value) { continue }
            foreach ($vm in @($e.Host.vms)) {
                [pscustomobject]@{
                    Name    = $vm.name
                    Runtime = [pscustomobject]@{ PowerState = $(if ($vm.powerState) { $vm.powerState } else { 'poweredOn' }) }
                    MoRef   = (New-TwinMoRef 'VirtualMachine' "vm-$($vm.name)")
                }
            }
        }
        return
    }
    if ($Id) {
        $e = Get-TwinHostIndex | Where-Object { "HostSystem-host-$($_.Host.name)" -eq "$Id" } | Select-Object -First 1
        if (-not $e) { throw "Twin: no host with id '$Id'." }
        $options = @()
        if ($e.Host.advancedOptions) { foreach ($k in $e.Host.advancedOptions.Keys) { $options += [pscustomobject]@{ Key = $k; Value = $e.Host.advancedOptions[$k] } } }
        return [pscustomobject]@{
            Hardware = [pscustomobject]@{ MemorySize = [long]([double]$e.Host.memoryGB * 1GB) }
            Config   = [pscustomobject]@{ Option = $options }
        }
    }
    throw "Twin: unsupported Get-View call (VIObject='$VIObject', ViewType='$ViewType')."
}

function Get-Stat {
    [CmdletBinding()]
    param($Entity, [string[]]$Stat, [datetime]$Start, $Server, [Parameter(ValueFromRemainingArguments)]$Rest)
    # Sampling follows the vCenter rollup intervals MTAT's ranges map to.
    $days = ((Get-Date) - $Start).TotalDays
    $period = if ($days -le 1.01) { 300 } elseif ($days -le 7.01) { 1800 } elseif ($days -le 30.01) { 7200 } else { 86400 }
    $count = [math]::Max(1, [int][math]::Round($days * 86400 / $period))
    $index = @(Get-TwinHostIndex)
    # MTAT passes a System.Collections.Generic.List[object] for VMs; enumerate it explicitly (wrapping it
    # in @() hands the binder an argument shape it rejects with "Argument types do not match").
    $entities = foreach ($x in $Entity) { $x }
    foreach ($ent in $entities) {
        $hostEntry = $index | Where-Object { $_.Host.name -eq $ent.Name } | Select-Object -First 1
        $vmSpec = $null; $vmHost = $null
        if (-not $hostEntry) {
            foreach ($e in $index) { foreach ($vm in @($e.Host.vms)) { if ($vm.name -eq $ent.Name) { $vmSpec = $vm; $vmHost = $e.Host } } }
        }
        foreach ($metric in $Stat) {
            $avg = $null; $peak = $null
            if ($hostEntry) {
                $s = $hostEntry.Host.stats
                if (-not $s) { continue }
                $dramKB = [double]$hostEntry.Host.memoryGB * 1048576
                switch ($metric) {
                    'cpu.usage.average'    { if ($s.cpuPct) { $avg = $s.cpuPct.avg; $peak = $s.cpuPct.peak } }
                    'mem.active.average'   { if ($s.activePctOfDram) { $avg = $s.activePctOfDram.avg / 100 * $dramKB; $peak = $s.activePctOfDram.peak / 100 * $dramKB } }
                    'mem.consumed.average' { if ($s.consumedPctOfDram) { $avg = $s.consumedPctOfDram.avg / 100 * $dramKB; $peak = $s.consumedPctOfDram.peak / 100 * $dramKB } }
                }
            } elseif ($vmSpec -and $vmSpec.stats -and $metric -eq 'mem.active.average') {
                $memKB = [double]$vmSpec.memoryGB * 1048576
                $avg = $vmSpec.stats.activePct.avg / 100 * $memKB; $peak = $vmSpec.stats.activePct.peak / 100 * $memKB
            }
            if ($null -eq $avg) { continue }
            $values = New-TwinSeries $avg $peak $count
            $entityRef = [pscustomobject]@{ Name = $ent.Name }
            for ($i = 0; $i -lt $count; $i++) {
                [pscustomobject]@{ Entity = $entityRef; MetricId = $metric; Value = $values[$i]; Timestamp = $Start.AddSeconds($period * ($i + 1)); IntervalSecs = $period }
            }
        }
    }
}

function Get-EsxCli {
    [CmdletBinding()]
    param($VMHost, [switch]$V2, [Parameter(ValueFromRemainingArguments)]$Rest)
    $e = Get-TwinHostIndex | Where-Object { $_.Host.name -eq $VMHost.Name } | Select-Object -First 1
    if (-not $e) { throw "Twin: unknown host '$($VMHost.Name)'." }
    $t = $e.Host.tiering
    $mode = if ($t -and $t.esxcli) { $t.esxcli } else { 'memtier' }
    if ($mode -eq 'error') { throw $(if ($t.error) { $t.error } else { "Could not load file or assembly 'VMware.System.Private.ServiceModel, Version=4.5.0.0'." }) }
    if ($t -and $t.delaySeconds) { Start-Sleep -Seconds ([int]$t.delaySeconds) }

    $versionObj = [pscustomobject]@{}
    $versionObj | Add-Member -MemberType ScriptMethod -Name Invoke -Value ([scriptblock]::Create("[pscustomobject]@{ Product = 'VMware ESXi'; Version = '$($e.Host.version)'; Build = 'Releasebuild-$($e.Host.build)' }"))
    $esxcli = [pscustomobject]@{ system = [pscustomobject]@{ version = [pscustomobject]@{ get = $versionObj } } }

    if ($mode -eq 'memtier') {
        $status = if ($t -and $t.status) { $t.status } else { 'Disabled' }
        $ratio = if ($t -and $null -ne $t.ratio) { "$($t.ratio)" } else { '$null' }
        $get = [pscustomobject]@{}
        $get | Add-Member -MemberType ScriptMethod -Name Invoke -Value ([scriptblock]::Create("[pscustomobject]@{ Status = '$status'; Ratio = $ratio }"))
        $esxcli | Add-Member -MemberType NoteProperty -Name memtier -Value ([pscustomobject]@{ status = [pscustomobject]@{ get = $get } })
    } elseif ($mode -eq 'kernel') {
        $runtime = if ($t -and $t.runtime) { $t.runtime } else { 'FALSE' }
        $list = [pscustomobject]@{}
        $list | Add-Member -MemberType ScriptMethod -Name Invoke -Value ([scriptblock]::Create("@([pscustomobject]@{ Name = 'MemoryTiering'; Runtime = '$runtime'; Configured = '$runtime' })"))
        $esxcli.system | Add-Member -MemberType NoteProperty -Name settings -Value ([pscustomobject]@{ kernel = [pscustomobject]@{ list = $list } })
    }
    # mode 'none': neither namespace is exposed.
    $esxcli
}
