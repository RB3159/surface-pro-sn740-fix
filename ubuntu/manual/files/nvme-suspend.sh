#!/bin/bash
# NVMe SN740 suspend/resume hook — prevents D3cold PCIe link failure
# Install: sudo cp nvme-suspend.sh /usr/lib/systemd/system-sleep/ && sudo chmod +x /usr/lib/systemd/system-sleep/nvme-suspend.sh
#
# NOTE: Change NVME_PCI below if your NVMe is at a different PCI address.
#       Check with: lspci -nn | grep -i 'non-volatile'

NVME_PCI="0000:01:00.0"
NVME_POWER="/sys/bus/pci/devices/$NVME_PCI/power/control"
NVME_D3COLD="/sys/bus/pci/devices/$NVME_PCI/d3cold_allowed"

case "$1" in
    pre)
        echo "on" > "$NVME_POWER" 2>/dev/null
        echo 0 > "$NVME_D3COLD" 2>/dev/null
        logger "nvme-suspend: pre-sleep — D3cold disabled"
        ;;
    post)
        echo "on" > "$NVME_POWER" 2>/dev/null
        echo 0 > "$NVME_D3COLD" 2>/dev/null
        logger "nvme-suspend: post-sleep — power restored"
        ;;
esac
