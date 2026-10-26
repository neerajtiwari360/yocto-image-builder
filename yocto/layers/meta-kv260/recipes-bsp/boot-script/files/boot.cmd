# No QSPI writes and no FPGA programming in this script.
# Legacy FRU firmware pads card1_name with spaces. Accept one exact token,
# rejecting missing names, other carriers and names with extra non-space text.
setenv kvcarrier invalid
setenv kvcarrier_seen
for kvword in ${card1_name}; do
    if test -n "${kvcarrier_seen}"; then
        setenv kvcarrier invalid
    else
        setenv kvcarrier "${kvword}"
        setenv kvcarrier_seen 1
    fi
done
if test "${kvcarrier}" != "SCK-KV-G"; then
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
