# Remove the Gen3 link cap: boot entries pointing at \EFI\Gen3\shellx64.efi (and their BootOrder/BootNext
# references), the \EFI\Gen3 folder on the ESP and the logon check. Other boot entries are not touched.
# Run from an elevated PowerShell. The link returns to Gen4 at the next boot.
. (Join-Path $PSScriptRoot 'UefiBoot.ps1')
$DataDir = Join-Path $env:ProgramData 'SN740-Gen3'
$TaskName = 'SN740 Gen3 Link Check'
$esp = $null
try {
  [UefiVar]::EnablePrivilege()
  $boot = Get-BootEntries
  $ours = @($boot.Entries | Where-Object { $_.Parsed.Nodes | Where-Object { $_.Path -eq '\EFI\Gen3\shellx64.efi' } })
  foreach ($e in $ours) {
    $next = [UefiVar]::Get('BootNext', $EfiGlobal)
    if ($next -and [BitConverter]::ToUInt16($next, 0) -eq $e.Number) { [UefiVar]::Set('BootNext', $EfiGlobal, $null, 7) }
    $order = @((Get-BootEntries).BootOrder)
    if ($order -contains $e.Number) { Set-BootOrder @($order | Where-Object { $_ -ne $e.Number }) }
    [UefiVar]::Set($e.Name, $EfiGlobal, $null, 7)
    Write-Host "[*] Removed $($e.Name) ($($e.Parsed.Description))"
  }
  $esp = Mount-Esp
  if (Test-Path "$($esp.Root)\EFI\Gen3") { Remove-Item "$($esp.Root)\EFI\Gen3" -Recurse -Force; Write-Host '[*] Removed \EFI\Gen3 from the ESP' }
  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false; Write-Host "[*] Removed task '$TaskName'" }
  Remove-Item (Join-Path $DataDir 'Check-Gen3.ps1') -ErrorAction SilentlyContinue
  Write-Host ('[*] BootOrder now: ' + (((Get-BootEntries).BootOrder | ForEach-Object { 'Boot{0:X4}' -f $_ }) -join ','))
  Write-Host "[*] Done. The NVRAM backup taken at install time is kept in $DataDir."
} catch {
  Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
  exit 1
} finally {
  Dismount-Esp $esp
}
