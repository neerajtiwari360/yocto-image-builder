# No QSPI writes and no FPGA programming in this script.
if test "${card1_name}" != "SCK-KV-G"; then
    echo "This image requires a KV260 carrier (SCK-KV-G)."
    exit
fi
setenv kvdt kv260-revB.dtb
if test "${card1_rev}" = "A" || test "${card1_rev}" = "Z"; then
    setenv kvdt kv260-revA.dtb
fi
if test -z "${devnum}"; then
    setenv devnum 1
fi
if part uuid mmc ${devnum}:2 rootuuid; then
    if fatload mmc ${devnum}:1 0x00200000 Image; then
        if fatload mmc ${devnum}:1 0x00100000 ${kvdt}; then
            setenv bootargs "earlycon console=ttyPS1,115200 root=PARTUUID=${rootuuid} rootwait rw"
            zynqmp pmufw node close
            booti 0x00200000 - 0x00100000
        fi
    fi
fi
echo "KV260 SD boot failed; inspect UART output."
