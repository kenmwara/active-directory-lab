# create-lab-vms.ps1: BUILD.md steps 2-3 plus CLIENT01's VM shell, on the Hyper-V host. Run it in an ADMINISTRATOR
# PowerShell after the Hyper-V restart:   powershell -ExecutionPolicy Bypass -File .\create-lab-vms.ps1
# Creates the LabNet switch, DC01 (2 NICs, Server 2025 ISO) and CLIENT01 (LabNet only, vTPM, Windows 11 ISO).
# Starts nothing: you start DC01 yourself so you can catch "Press any key to boot from CD". Safe to re-run.
$ErrorActionPreference = 'Stop'
$vmPath = 'C:\HyperV'
$dl = Join-Path $env:USERPROFILE 'Downloads'

if ((Get-Service vmms -ErrorAction SilentlyContinue).Status -ne 'Running') { throw 'Hyper-V is not running yet: tick it in Windows features and restart.' }

function Find-Iso($pattern, $what) {
    $hits = @(Get-ChildItem $dl -Filter *.iso | Where-Object Name -like $pattern)
    if ($hits.Count -ne 1) { throw "Expected one $what ISO in Downloads matching '$pattern', found $($hits.Count)." }
    $hits[0].FullName
}
$serverIso = Find-Iso '*SERVER*EVAL*x64FRE*.iso' 'Windows Server 2025'
$clientIso = Find-Iso '*CLIENTENTERPRISE*EVAL*x64FRE*.iso' 'Windows 11 Enterprise'

if (-not (Get-VMSwitch -Name LabNet -ErrorAction SilentlyContinue)) { New-VMSwitch -Name LabNet -SwitchType Private | Out-Null }

if (-not (Get-VM DC01 -ErrorAction SilentlyContinue)) {
    New-VM -Name DC01 -Generation 2 -MemoryStartupBytes 4GB -Path $vmPath `
           -NewVHDPath "$vmPath\DC01\DC01.vhdx" -NewVHDSizeBytes 60GB -SwitchName 'Default Switch' | Out-Null
    Set-VMMemory DC01 -DynamicMemoryEnabled $true -MinimumBytes 2GB -MaximumBytes 4GB
    Set-VMProcessor DC01 -Count 2
    Add-VMNetworkAdapter -VMName DC01 -SwitchName LabNet
    Add-VMDvdDrive -VMName DC01 -Path $serverIso
    Set-VMFirmware DC01 -FirstBootDevice (Get-VMDvdDrive DC01)
    Set-VM DC01 -AutomaticCheckpointsEnabled $false   # we take our own checkpoint after each step
}

if (-not (Get-VM CLIENT01 -ErrorAction SilentlyContinue)) {
    New-VM -Name CLIENT01 -Generation 2 -MemoryStartupBytes 4GB -Path $vmPath `
           -NewVHDPath "$vmPath\CLIENT01\CLIENT01.vhdx" -NewVHDSizeBytes 64GB -SwitchName LabNet | Out-Null
    Set-VMProcessor CLIENT01 -Count 2
    Set-VMKeyProtector -VMName CLIENT01 -NewLocalKeyProtector
    Enable-VMTPM -VMName CLIENT01                      # Windows 11 refuses to install without a TPM
    Add-VMDvdDrive -VMName CLIENT01 -Path $clientIso
    Set-VMFirmware CLIENT01 -FirstBootDevice (Get-VMDvdDrive CLIENT01)
    Set-VM CLIENT01 -AutomaticCheckpointsEnabled $false
}

Get-VM DC01, CLIENT01 | Select-Object Name, State, Generation, @{n='RAM_GB';e={$_.MemoryStartup/1GB}}, ProcessorCount | Format-Table -AutoSize
Get-VMNetworkAdapter -VMName DC01, CLIENT01 | Select-Object VMName, SwitchName | Format-Table -AutoSize
Get-VMDvdDrive -VMName DC01, CLIENT01 | Select-Object VMName, Path | Format-Table -AutoSize
Write-Host 'Done. Next: Hyper-V Manager > DC01 > Connect > Start, and press a key at "Press any key to boot from CD".'
