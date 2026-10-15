# Show the current SN740 PCIe link speed. With -Popup (used by the logon task), only warn when it is not Gen3.
param([switch]$Popup)
$nvme = Get-PnpDevice -PresentOnly | Where-Object InstanceId -like 'PCI\VEN_15B7&DEV_5015*' | Select-Object -First 1
if (-not $nvme) { if (-not $Popup) { 'WD SN740 (15B7:5015) not found.' }; exit }
$speed = (Get-PnpDeviceProperty -InstanceId $nvme.InstanceId -KeyName DEVPKEY_PciDevice_CurrentLinkSpeed).Data
$names = @{ 1 = 'Gen1 (2.5 GT/s)'; 2 = 'Gen2 (5 GT/s)'; 3 = 'Gen3 (8 GT/s)'; 4 = 'Gen4 (16 GT/s)' }
if ($Popup) {
  if ($speed -ne 3) {
    (New-Object -ComObject WScript.Shell).Popup("SN740 PCIe link is $($names[[int]$speed]), not Gen3. The Gen3 cap did not take effect at boot, so Modern Standby may crash. Do not close the cover on battery; restart once. If it repeats, check that 'SN740 Gen3 (UEFI Shell)' is first in the UEFI boot order and that Secure Boot is still off.", 0, 'SN740 Gen3 cap NOT active', 48) | Out-Null
  }
} else {
  "SN740 link: $($names[[int]$speed])" + $(if ($speed -eq 3) { ' - Gen3 cap active' } else { ' - Gen3 cap NOT active' })
}
