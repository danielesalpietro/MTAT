@{
    RootModule        = 'VMware.VimAutomation.Core.psm1'
    ModuleVersion     = '99.0.0'
    GUID              = '5d1d6a43-8c3b-4f5e-9e43-6d7f0b2a9a47'
    Author            = 'MTAT project'
    Description       = 'MTAT DIGITAL TWIN: simulates the subset of the VMware PowerCLI surface used by MTAT, driven by a JSON scenario (MTAT_TWIN_SCENARIO). This is NOT VMware PowerCLI and never talks to a real vCenter.'
    FunctionsToExport = @('Connect-VIServer', 'Disconnect-VIServer', 'Set-PowerCLIConfiguration', 'Get-View', 'Get-Cluster', 'Get-VMHost', 'Get-VM', 'Get-Stat', 'Get-EsxCli')
    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()
}
