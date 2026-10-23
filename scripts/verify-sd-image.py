"""Inspect an SD image without mounting it or requiring privileged Docker."""
import pathlib
import struct
import sys

path = pathlib.Path(sys.argv[1])
size = path.stat().st_size
with path.open("rb") as disk:
    def read_at(offset, length):
        disk.seek(offset)
        data = disk.read(length)
        if len(data) != length:
            raise ValueError("Image is truncated")
        return data

    mbr = read_at(0, 512)
    assert mbr[510:512] == b"\x55\xaa", "Missing MBR signature"
    partitions = []
    for i in range(4):
        record = mbr[446 + i * 16:462 + i * 16]
        kind = record[4]
        start, sectors = struct.unpack_from("<II", record, 8)
        if kind:
            assert start > 0 and sectors > 0
            assert (start + sectors) * 512 <= size, "Partition exceeds image"
            partitions.append((kind, start, sectors))
    assert len(partitions) == 2, "Expected boot and root partitions"
    assert partitions[0][0] in (6, 11, 12, 14), "Boot partition is not FAT"
    assert partitions[1][0] == 131, "Root partition is not Linux"
    assert partitions[0][1] + partitions[0][2] <= partitions[1][1], "Partitions overlap"
    boot_offset = partitions[0][1] * 512
    boot = read_at(boot_offset, 512)
    assert boot[510:512] == b"\x55\xaa", "Invalid FAT boot sector"
    sector_size = struct.unpack_from("<H", boot, 11)[0]
    sectors_per_cluster = boot[13]
    reserved = struct.unpack_from("<H", boot, 14)[0]
    fat_count = boot[16]
    root_entries = struct.unpack_from("<H", boot, 17)[0]
    fat_size = struct.unpack_from("<H", boot, 22)[0]
    if fat_size:
        root_offset = boot_offset + (reserved + fat_count * fat_size) * sector_size
        directory = read_at(root_offset, root_entries * 32)
    else:
        fat_size = struct.unpack_from("<I", boot, 36)[0]
        cluster = struct.unpack_from("<I", boot, 44)[0]
        data_offset = boot_offset + (reserved + fat_count * fat_size) * sector_size
        chunks = []
        visited = set()
        while 2 <= cluster < 0x0FFFFFF8:
            assert cluster not in visited and len(visited) < 1024, "Bad FAT chain"
            visited.add(cluster)
            chunks.append(read_at(data_offset + (cluster - 2) * sectors_per_cluster * sector_size,
                                  sectors_per_cluster * sector_size))
            cluster = struct.unpack("<I", read_at(boot_offset + reserved * sector_size + cluster * 4, 4))[0] & 0x0FFFFFFF
        directory = b"".join(chunks)
    names = set()
    long_parts = []
    for offset in range(0, len(directory), 32):
        entry = directory[offset:offset + 32]
        if not entry or entry[0] == 0:
            break
        if entry[0] == 0xE5:
            long_parts = []
            continue
        if entry[11] == 0x0F:
            raw = entry[1:11] + entry[14:26] + entry[28:32]
            long_parts.insert(0, raw.decode("utf-16le"))
            continue
        if long_parts:
            name = "".join(long_parts).split("\0")[0].replace("\uffff", "")
        else:
            base = entry[:8].decode("ascii", errors="replace").rstrip()
            extension = entry[8:11].decode("ascii", errors="replace").rstrip()
            name = base + ("." + extension if extension else "")
        names.add(name.lower())
        long_parts = []
    expected = {"kernel7.img", "config.txt", "cmdline.txt", "start.elf",
                "bcm2710-rpi-zero-2.dtb"}
    assert expected <= names, f"Missing boot files: {expected - names}"
    superblock = read_at(partitions[1][1] * 512 + 1024, 1024)
    assert superblock[56:58] == b"\x53\xef", "Invalid ext4 root filesystem"
    blocks = struct.unpack_from("<I", superblock, 4)[0]
    free_blocks = struct.unpack_from("<I", superblock, 12)[0]
    block_size = 1024 << struct.unpack_from("<I", superblock, 24)[0]
    print("PASS: MBR, partition boundaries, FAT boot files and ext4 root filesystem.")
    print(f"Uncompressed SD image: {size:,} bytes")
    print(f"Root filesystem capacity: {blocks * block_size:,} bytes")
    print(f"Root filesystem allocated blocks: {(blocks - free_blocks) * block_size:,} bytes (includes filesystem metadata)")
    print("Board-specific kernel, config, command line and Pi Zero 2 DTB present.")
    print("Physical hardware boot has not been tested.")
