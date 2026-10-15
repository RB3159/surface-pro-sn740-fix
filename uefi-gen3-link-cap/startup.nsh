@echo -off
# SN740 Gen3 auto-apply on every boot, then hand over to rEFInd (fallback: Windows Boot Manager).
# On any failure, "exit" returns to firmware, which boots the next BootOrder entry (unchanged, at Gen4).
# Installed to the ESP as \EFI\Gen3\startup.nsh by Install-Gen3.ps1. The boot entry passes "-delay 0"
# so the shell skips its 5 s "Press ESC" prompt.
# Addresses assume Surface Pro 8: root port 00:06.0 (8086:9A09, PCIe cap 0x40, AER 0x100), SN740 01:00.0 (AER 0x100).
set -v G3 none
for %a in fs0 fs1 fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9
  if exist %a:\EFI\Gen3\gen3.marker then
    set -v G3 %a
  endif
endfor
if %G3% == none then
  exit
endif
set -v LOG %G3%:\EFI\Gen3\apply\history.txt
# Per boot: date, time, AER status read now (sticky bits: previous session + reset + this boot's firmware phase at Gen4):
# root port uncorrectable, root port correctable, SSD uncorrectable, SSD correctable
echo BOOT >>a %LOG%
date >>a %LOG%
time >>a %LOG%
mm 00600104 -pcie -w 4 -n >>a %LOG%
mm 00600110 -pcie -w 4 -n >>a %LOG%
mm 10000104 -pcie -w 4 -n >>a %LOG%
mm 10000110 -pcie -w 4 -n >>a %LOG%
# Target Link Speed = 8 GT/s (Gen3)
mm 00060070 0003 -pci -w 2 -n
stall 200000
# Retrain Link (LNKCTL 0x0042 | 0x0020). A single directed 16 -> 8 GT/s change failed once in testing,
# so retrain several times. Retraining an already-Gen3 link is harmless.
mm 00060050 0062 -pci -w 2 -n
stall 150000
mm 00060050 0062 -pci -w 2 -n
stall 150000
mm 00060050 0062 -pci -w 2 -n
stall 150000
mm 00060050 0062 -pci -w 2 -n
stall 150000
mm 00060050 0062 -pci -w 2 -n
stall 150000
mm 00060050 0062 -pci -w 2 -n
stall 150000
# Low byte of LNKSTA after retraining: 0x43 = 8 GT/s x4, 0x44 = 16 GT/s x4
mm 00060052 -pci -w 1 -n >>a %LOG%
# Clear AER correctable status (RW1C)
mm 00600110 000031C1 -pcie -w 4 -n
mm 10000110 000031C1 -pcie -w 4 -n
if exist %G3%:\EFI\refind\refind_x64.efi then
  %G3%:\EFI\refind\refind_x64.efi
endif
%G3%:\EFI\Microsoft\Boot\bootmgfw.efi
exit
