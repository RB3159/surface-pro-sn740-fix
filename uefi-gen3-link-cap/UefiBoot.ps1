# Helpers for UEFI boot variables and the EFI System Partition. Dot-sourced by Install/Uninstall (elevated).
$ErrorActionPreference = 'Stop'
$EfiGlobal = '{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}'

if (-not ('UefiVar' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class UefiVar {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern uint GetFirmwareEnvironmentVariableExW(string name, string guid, byte[] buf, uint size, out uint attr);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern bool SetFirmwareEnvironmentVariableExW(string name, string guid, byte[] buf, uint size, uint attr);
  [DllImport("advapi32.dll", SetLastError=true)]
  static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);
  [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern bool LookupPrivilegeValue(string system, string name, out long luid);
  [DllImport("advapi32.dll", SetLastError=true)]
  static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TokenPrivileges state, uint len, IntPtr prev, IntPtr retLen);
  [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
  [StructLayout(LayoutKind.Sequential, Pack=4)]
  struct TokenPrivileges { public uint Count; public long Luid; public uint Attributes; }

  public static void EnablePrivilege() {
    IntPtr token;
    if (!OpenProcessToken(GetCurrentProcess(), 0x28, out token)) throw new Win32Exception();
    long luid;
    if (!LookupPrivilegeValue(null, "SeSystemEnvironmentPrivilege", out luid)) throw new Win32Exception();
    var tp = new TokenPrivileges { Count = 1, Luid = luid, Attributes = 2 };
    if (!AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero)) throw new Win32Exception();
    int err = Marshal.GetLastWin32Error();
    if (err != 0) throw new Win32Exception(err);
  }
  public static byte[] Get(string name, string guid) {
    var buf = new byte[8192]; uint attr;
    uint n = GetFirmwareEnvironmentVariableExW(name, guid, buf, (uint)buf.Length, out attr);
    if (n == 0) { int e = Marshal.GetLastWin32Error(); if (e == 203) return null; throw new Win32Exception(e); }
    var r = new byte[n]; Array.Copy(buf, r, (int)n); return r;
  }
  public static void Set(string name, string guid, byte[] data, uint attr) {
    if (!SetFirmwareEnvironmentVariableExW(name, guid, data, data == null ? 0u : (uint)data.Length, attr)) throw new Win32Exception();
  }
}
'@
}

function ConvertTo-Hex([byte[]]$Bytes) { if ($null -eq $Bytes) { return $null }; ($Bytes | ForEach-Object { $_.ToString('X2') }) -join '' }

# Parse an EFI_LOAD_OPTION (Boot####) into description and device path nodes.
function Read-LoadOption([byte[]]$Bytes) {
  $fpLen = [BitConverter]::ToUInt16($Bytes, 4)
  $i = 6
  while (-not ($Bytes[$i] -eq 0 -and $Bytes[$i + 1] -eq 0)) { $i += 2 }
  $desc = [Text.Encoding]::Unicode.GetString($Bytes, 6, $i - 6)
  $fpStart = $i + 2
  $nodes = @(); $o = $fpStart
  while ($o -lt $fpStart + $fpLen) {
    $type = $Bytes[$o]; $sub = $Bytes[$o + 1]; $len = [BitConverter]::ToUInt16($Bytes, $o + 2)
    if ($len -lt 4) { throw "Malformed device path node at $o" }
    $raw = New-Object byte[] $len; [Array]::Copy($Bytes, $o, $raw, 0, $len)
    $node = [ordered]@{ Type = $type; SubType = $sub; Raw = $raw }
    if ($type -eq 4 -and $sub -eq 4) { $node.Path = [Text.Encoding]::Unicode.GetString($raw, 4, $len - 6) }
    if ($type -eq 4 -and $sub -eq 1) { $g = New-Object byte[] 16; [Array]::Copy($raw, 24, $g, 0, 16); $node.PartitionGuid = (New-Object Guid (, $g)).ToString() }
    $nodes += [pscustomobject]$node
    if ($type -eq 0x7F -and $sub -eq 0xFF) { break }
    $o += $len
  }
  [pscustomobject]@{ Description = $desc; Nodes = $nodes }
}

# Build an active EFI_LOAD_OPTION: <PrefixNodes>/File(<FilePath>)/End, no optional data.
function New-LoadOption([string]$Description, [object[]]$PrefixNodes, [string]$FilePath) {
  $fp = New-Object IO.MemoryStream
  foreach ($n in $PrefixNodes) { $fp.Write($n.Raw, 0, $n.Raw.Length) }
  $pathBytes = [Text.Encoding]::Unicode.GetBytes($FilePath + [char]0)
  $fp.WriteByte(4); $fp.WriteByte(4)
  $fp.Write([BitConverter]::GetBytes([uint16](4 + $pathBytes.Length)), 0, 2)
  $fp.Write($pathBytes, 0, $pathBytes.Length)
  $fp.Write([byte[]](0x7F, 0xFF, 0x04, 0x00), 0, 4)
  $fpBytes = $fp.ToArray()
  $ms = New-Object IO.MemoryStream
  $ms.Write([BitConverter]::GetBytes([uint32]1), 0, 4)
  $ms.Write([BitConverter]::GetBytes([uint16]$fpBytes.Length), 0, 2)
  $d = [Text.Encoding]::Unicode.GetBytes($Description + [char]0); $ms.Write($d, 0, $d.Length)
  $ms.Write($fpBytes, 0, $fpBytes.Length)
  , $ms.ToArray()
}

function Get-BootEntries {
  $order = [UefiVar]::Get('BootOrder', $EfiGlobal)
  $ids = @(); for ($i = 0; $i -lt $order.Length; $i += 2) { $ids += [BitConverter]::ToUInt16($order, $i) }
  $entries = foreach ($n in 0..0xFF) {
    $name = 'Boot{0:X4}' -f $n
    $b = [UefiVar]::Get($name, $EfiGlobal)
    if ($b) { [pscustomobject]@{ Name = $name; Number = $n; Hex = (ConvertTo-Hex $b); Parsed = (Read-LoadOption $b) } }
  }
  [pscustomobject]@{ BootOrder = $ids; BootOrderHex = (ConvertTo-Hex $order); Entries = @($entries) }
}

function Set-BootOrder([int[]]$Order) {
  $bytes = New-Object byte[] ($Order.Count * 2)
  for ($i = 0; $i -lt $Order.Count; $i++) { [BitConverter]::GetBytes([uint16]$Order[$i]).CopyTo($bytes, $i * 2) }
  [UefiVar]::Set('BootOrder', $EfiGlobal, $bytes, 7)
}

function Mount-Esp {
  $disk = (Get-Partition -DriveLetter $env:SystemDrive.TrimEnd(':')).DiskNumber
  $esp = Get-Partition -DiskNumber $disk | Where-Object GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
  if (@($esp).Count -ne 1) { throw 'Expected exactly one EFI System Partition on the system disk' }
  $used = (Get-PSDrive -PSProvider FileSystem).Name
  $letter = @('S', 'T', 'U', 'V', 'W', 'X', 'Y') | Where-Object { $used -notcontains $_ } | Select-Object -First 1
  if (-not $letter) { throw 'No free drive letter for the ESP' }
  & mountvol.exe "$($letter):" /S | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$($letter):\EFI")) { throw 'Failed to mount the ESP' }
  [pscustomobject]@{ Root = "$($letter):"; PartitionGuid = $esp.Guid.Trim('{}').ToLower() }
}

function Dismount-Esp($Esp) { if ($Esp) { & mountvol.exe $Esp.Root /D | Out-Null } }
