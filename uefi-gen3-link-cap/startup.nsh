@echo -off
# SN740 Gen3 auto-apply on every boot, then hand over to rEFInd (fallback: Windows Boot Manager).
# On any failure, "exit" returns to firmware, which boots the next BootOrder entry (unchanged, at Gen4).
# Installed to the ESP as \EFI\Gen3\startup.nsh by Install-Gen3.ps1.
# Addresses assume Surface Pro 8: root port 00:06.0 (8086:9A09, PCIe cap at 0x40), SN740 at 01:00.0.
set -v G3 none
for %a in fs0 fs1 fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9
  if exist %a:\EFI\Gen3\gen3.marker then
    set -v G3 %a
  endif
endfor
if %G3% == none then
  exit
endif
set -v OUT %G3%:\EFI\Gen3\apply
# Errors accumulated during the previous session (AER status bits are sticky across warm reset)
pci 00 06 00 -i >a %OUT%\rp-before.txt
pci 01 00 00 -i >a %OUT%\ssd-before.txt
# Target Link Speed = 8 GT/s (Gen3)
mm 00060070 0003 -pci -w 2 -n
stall 500000
# Retrain Link (LNKCTL 0x0042 | 0x0020). A single directed 16 -> 8 GT/s change failed once in testing
# (link stayed at 16 GT/s), so retrain several times. Retraining an already-Gen3 link is harmless.
mm 00060050 0062 -pci -w 2 -n
stall 300000
mm 00060050 0062 -pci -w 2 -n
stall 300000
mm 00060050 0062 -pci -w 2 -n
stall 300000
mm 00060050 0062 -pci -w 2 -n
stall 300000
mm 00060050 0062 -pci -w 2 -n
stall 300000
mm 00060050 0062 -pci -w 2 -n
stall 500000
# Low byte of LNKSTA: 0x43 = 8 GT/s x4, 0x44 = 16 GT/s x4
mm 00060052 -pci -w 1 -n >a %OUT%\lnksta-low-byte.txt
# Clear AER correctable status (RW1C) after retraining, so the next boot's *-before dumps show only session errors
mm 00600110 000031C1 -pcie -w 4 -n
mm 10000110 000031C1 -pcie -w 4 -n
pci 00 06 00 -i >a %OUT%\rp-after.txt
pci 01 00 00 -i >a %OUT%\ssd-after.txt
echo apply-complete >a %OUT%\apply-complete.txt
if exist %G3%:\EFI\refind\refind_x64.efi then
  %G3%:\EFI\refind\refind_x64.efi
endif
%G3%:\EFI\Microsoft\Boot\bootmgfw.efi
exit
