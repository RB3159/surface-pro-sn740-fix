<# 
.SYNOPSIS
    SN740 PCIe BSOD Fix — powercfg power settings
.DESCRIPTION
    Surface Pro 8 + WD SN740 NVMe: disables PCIe/AHCI power management
    to prevent PCIe Gen 4 link training failure (BSOD / WHEA_UNCORRECTABLE_ERROR).
    
    Designed to be re-run after Windows Update resets power settings.
.NOTES
    Run as Administrator.
#>

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir    = if ($scriptDir) { $scriptDir } else { "$env:SystemRoot\System32\SN740Fix" }
$logFile   = Join-Path $logDir "fix-pcie-power.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Ensure log directory exists
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

Add-Content $logFile "$timestamp - SN740 PCIe fix starting..."

try {
    # 1. AHCI Link Power Management (HIPM/DIPM) = OFF
    #    SubGroup: 0012ee47-9041-4b5d-9b77-535fba8b1442 (Disk)
    #    Setting:  0b2d69d7-a2a1-449c-9680-f91c70521c60 (AHCI Link Power)
    powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 0b2d69d7-a2a1-449c-9680-f91c70521c60 0
    powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 0b2d69d7-a2a1-449c-9680-f91c70521c60 0

    # 2. PCIe Link State Power Management = OFF
    #    SubGroup: 501a4d13-42af-4429-9fd1-a8218c268e20 (PCI Express)
    #    Setting:  ee12f906-d277-404b-b6da-e5fa1a576df5 (Link State PM)
    powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
    powercfg /setdcvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0

    # 3. NVMe Idle Timeout = 0 (disable)
    #    Setting:  d639518a-e56d-4345-8af2-b9f32fb26109
    powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0
    powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0

    # 4. NVMe NOPPME = OFF
    #    Setting:  fc7372b6-ab2d-43ee-8797-15e9841f2cca
    powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0
    powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0

    # 5. Apply active scheme
    powercfg /setactive SCHEME_CURRENT

    # 6. Unhide AHCI Link Power option in advanced power settings
    powercfg -attributes 0012ee47-9041-4b5d-9b77-535fba8b1442 0b2d69d7-a2a1-449c-9680-f91c70521c60 -ATTRIB_HIDE

    Add-Content $logFile "$timestamp - SN740 PCIe fix applied successfully"
    Write-Host "[OK] PCIe power settings applied." -ForegroundColor Green
}
catch {
    Add-Content $logFile "$timestamp - ERROR: $_"
    Write-Host "[ERROR] $_" -ForegroundColor Red
    exit 1
}
