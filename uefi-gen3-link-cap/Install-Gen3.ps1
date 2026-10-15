<#
.SYNOPSIS
  Surface Pro 8 + WD SN740: cap the SSD's PCIe link at Gen3 on every boot (Modern Standby crash fix).
.DESCRIPTION
  Copies the UEFI Shell and startup.nsh to \EFI\Gen3 on the EFI System Partition, adds a
  "SN740 Gen3 (UEFI Shell)" boot entry first in the UEFI BootOrder and registers a logon check.
  At every boot the shell sets root port 00:06.0 to 8 GT/s, retrains the link, then starts rEFInd
  if present, otherwise Windows Boot Manager. Existing boot entries are kept in their order.
  Run from an elevated PowerShell. -DryRun runs every check and prints the plan without writing anything.
#>
param([switch]$DryRun, [string]$ShellPath)
. (Join-Path $PSScriptRoot 'UefiBoot.ps1')
$ShellUrl = 'https://github.com/pbatard/UEFI-Shell/releases/download/26H1/shellx64.efi'
$ShellSha256 = '4ea080ddd576117cd04f5c02d16712ea5d9249c0752214d8e4055e460d7b11e0'
$Description = 'SN740 Gen3 (UEFI Shell)'
$ShellFile = '\EFI\Gen3\shellx64.efi'
$DataDir = Join-Path $env:ProgramData 'SN740-Gen3'
$TaskName = 'SN740 Gen3 Link Check'
function Step($Message) { Write-Host "[*] $Message" }

$esp = $null
try {
  if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) { throw 'Run from an elevated PowerShell (Run as administrator).' }

  # 1. Hardware: startup.nsh writes fixed PCI addresses that are only valid for this topology.
  $nvme = @(Get-PnpDevice -PresentOnly | Where-Object InstanceId -like 'PCI\VEN_15B7&DEV_5015*')
  if ($nvme.Count -ne 1) { throw 'WD SN740 (PCI 15B7:5015) not found.' }
  $id = $nvme[0].InstanceId
  $parent = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_Parent).Data
  $paths = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_LocationPaths).Data
  $bus = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_BusNumber).Data
  if ($parent -notlike 'PCI\VEN_8086&DEV_9A09*' -or $paths -notcontains 'PCIROOT(0)#PCI(0600)#PCI(0000)' -or $bus -ne 1) {
    throw "Unexpected PCIe topology (parent $parent, bus $bus). This fix is only for Surface Pro 8 (Tiger Lake root port 00:06.0)."
  }
  $speed = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_PciDevice_CurrentLinkSpeed).Data
  Step "SN740 at root port 00:06.0 (8086:9A09), bus 1. Current link speed code: $speed (3 = Gen3, 4 = Gen4)"

  # 2. Firmware prerequisites
  if (Confirm-SecureBootUEFI) { throw 'Secure Boot is ON, so the unsigned UEFI Shell cannot run. Turn Secure Boot off in Surface UEFI first (see README).' }
  $bl = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftVolumeEncryption -ClassName Win32_EncryptableVolume -Filter "DriveLetter='$env:SystemDrive'" -ErrorAction SilentlyContinue
  if ($bl -and $bl.ProtectionStatus -ne 0) { throw "BitLocker / Device Encryption is ON. Changing the boot path would ask for the recovery key. Suspend it first: manage-bde -protectors -disable $env:SystemDrive -RebootCount 2" }
  if (Get-ScheduledTask -TaskName 'SN740-PCIe-Fix' -ErrorAction SilentlyContinue) { Write-Warning 'The legacy SN740-PCIe-Fix task is installed. It is not needed with the Gen3 cap; remove it with windows\auto\uninstall.cmd.' }

  # 3. UEFI Shell binary (pinned release, verified by SHA256)
  $shellTmp = Join-Path $env:TEMP 'sn740-gen3-shellx64.efi'
  if ($ShellPath) { Copy-Item $ShellPath $shellTmp -Force } else { Invoke-WebRequest -UseBasicParsing $ShellUrl -OutFile $shellTmp }
  if ((Get-FileHash $shellTmp -Algorithm SHA256).Hash.ToLower() -ne $ShellSha256) { throw 'UEFI Shell SHA256 mismatch.' }
  Step 'UEFI Shell 26H1 (pbatard/UEFI-Shell, edk2-stable202602) SHA256 verified.'

  # 4. Boot entry plan
  [UefiVar]::EnablePrivilege()
  $boot = Get-BootEntries
  $esp = Mount-Esp
  if (-not (Test-Path "$($esp.Root)\EFI\Microsoft\Boot\bootmgfw.efi")) { throw 'Windows Boot Manager not found on the ESP.' }
  $handoff = if (Test-Path "$($esp.Root)\EFI\refind\refind_x64.efi") { 'rEFInd' } else { 'Windows Boot Manager' }
  $existing = @($boot.Entries | Where-Object { $_.Parsed.Nodes | Where-Object { $_.Path -eq $ShellFile } })
  if ($existing.Count -gt 1) { throw 'More than one boot entry already points at the Gen3 shell. Run Uninstall-Gen3.ps1 first.' }
  if ($existing.Count -eq 1) {
    $num = $existing[0].Number; $nodes = $existing[0].Parsed.Nodes; $desc = $existing[0].Parsed.Description
    $source = 'existing entry'
  } else {
    $template = $boot.Entries | Where-Object {
      ($_.Parsed.Nodes | Where-Object { $_.PartitionGuid -eq $esp.PartitionGuid }) -and ($_.Parsed.Nodes | Where-Object { $_.Path })
    } | Select-Object -First 1
    if (-not $template) { throw 'No existing boot entry on the ESP to copy the device path from.' }
    $num = 0x20..0xFF | Where-Object { $boot.Entries.Number -notcontains $_ } | Select-Object -First 1
    $nodes = $template.Parsed.Nodes; $desc = $Description
    $source = "new, device path copied from $($template.Name)"
  }
  $fileIdx = [array]::IndexOf($nodes, ($nodes | Where-Object { $_.Path } | Select-Object -First 1))
  if ($fileIdx -lt 1) { throw 'Unexpected device path in the boot entry.' }
  # OptionalData "-delay 0": the shell skips its 5 s "Press ESC" prompt and still runs startup.nsh
  $option = New-LoadOption $desc $nodes[0..($fileIdx - 1)] $ShellFile ([Text.Encoding]::Unicode.GetBytes('-delay 0' + [char]0))
  if ($existing.Count -eq 1 -and $existing[0].Hex -eq (ConvertTo-Hex $option)) { $option = $null }
  $newOrder = @($num) + @($boot.BootOrder | Where-Object { $_ -ne $num })
  Step ("Boot entry: Boot{0:X4} ({1}) - {2}" -f $num, $source, $(if ($option) { 'will be written' } else { 'already up to date' }))
  Step ('BootOrder: ' + (($boot.BootOrder | ForEach-Object { 'Boot{0:X4}' -f $_ }) -join ',') + ' -> ' + (($newOrder | ForEach-Object { 'Boot{0:X4}' -f $_ }) -join ','))
  Step "After the Gen3 cap the shell starts: $handoff"
  if ($DryRun) { Step 'Dry run: nothing was written.'; return }

  # 5. Apply
  New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
  $backup = Join-Path $DataDir 'nvram-backup.json'
  if (-not (Test-Path $backup)) { $boot | ConvertTo-Json -Depth 6 | Set-Content $backup -Encoding UTF8 }
  $g3 = "$($esp.Root)\EFI\Gen3"
  New-Item -ItemType Directory -Force -Path "$g3\apply" | Out-Null
  Copy-Item $shellTmp "$g3\shellx64.efi" -Force
  Copy-Item (Join-Path $PSScriptRoot 'startup.nsh') "$g3\startup.nsh" -Force
  Set-Content "$g3\gen3.marker" -Value 'SN740 Gen3 link cap' -Encoding ASCII
  if ($option) {
    [UefiVar]::Set(('Boot{0:X4}' -f $num), $EfiGlobal, $option, 7)
    if ((ConvertTo-Hex ([UefiVar]::Get(('Boot{0:X4}' -f $num), $EfiGlobal))) -ne (ConvertTo-Hex $option)) { throw 'Boot entry readback mismatch.' }
  }
  Set-BootOrder $newOrder
  if ((Get-BootEntries).BootOrder[0] -ne $num) { throw 'BootOrder readback mismatch.' }
  Step 'ESP files, boot entry and BootOrder written.'

  Copy-Item (Join-Path $PSScriptRoot 'Check-Gen3.ps1') (Join-Path $DataDir 'Check-Gen3.ps1') -Force
  $user = "$env:USERDOMAIN\$env:USERNAME"
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $DataDir 'Check-Gen3.ps1') + '" -Popup')
  $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
  $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
  Step "Logon check task '$TaskName' registered."
  Step 'Done. Restart once; if no warning appears after logon, the link is at Gen3 (check: Check-Gen3.ps1).'
} catch {
  Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
  exit 1
} finally {
  Dismount-Esp $esp
}
