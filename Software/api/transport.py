"""Transport layer abstraction for ATE register access.
Supports PCIe (XDMA driver) and JTAG-AXI (Vivado hw_server) backends.
"""

import struct
from abc import ABC, abstractmethod


class Transport(ABC):
    """Abstract register read/write interface."""

    @abstractmethod
    def write32(self, addr: int, value: int) -> None:
        """Write 32-bit value to register address."""

    @abstractmethod
    def read32(self, addr: int) -> int:
        """Read 32-bit value from register address."""

    @abstractmethod
    def open(self) -> None:
        """Open connection to device."""

    @abstractmethod
    def close(self) -> None:
        """Close connection."""

    def __enter__(self):
        self.open()
        return self

    def __exit__(self, *args):
        self.close()


class PCIeTransport(Transport):
    """Register access via XDMA PCIe BAR0 (memory-mapped file).

    On Linux: /dev/xdma0_user or resource0 sysfs entry
    On Windows: uses XDMA driver IOCTL or WinDriver
    """

    def __init__(self, device_path: str = None):
        self._path = device_path
        self._fd = None
        self._mmap = None

    def open(self):
        import mmap
        import os
        import platform

        if self._path is None:
            if platform.system() == "Linux":
                self._path = "/dev/xdma0_user"
            else:
                # Windows: try sysfs-like path or use ctypes for driver IOCTL
                self._path = r"\\.\xdma0_user"

        if platform.system() == "Linux":
            self._fd = os.open(self._path, os.O_RDWR | os.O_SYNC)
            self._mmap = mmap.mmap(self._fd, 0x10000,  # 64KB BAR0
                                   mmap.MAP_SHARED,
                                   mmap.PROT_READ | mmap.PROT_WRITE)
        else:
            # Windows: open device file
            self._fd = open(self._path, "r+b")

    def close(self):
        if self._mmap:
            self._mmap.close()
            self._mmap = None
        if self._fd is not None:
            import os, platform
            if platform.system() == "Linux":
                os.close(self._fd)
            else:
                self._fd.close()
            self._fd = None

    def write32(self, addr: int, value: int):
        data = struct.pack("<I", value & 0xFFFFFFFF)
        if self._mmap:
            self._mmap[addr:addr+4] = data
        else:
            self._fd.seek(addr)
            self._fd.write(data)
            self._fd.flush()

    def read32(self, addr: int) -> int:
        if self._mmap:
            data = self._mmap[addr:addr+4]
        else:
            self._fd.seek(addr)
            data = self._fd.read(4)
        return struct.unpack("<I", data)[0]


class JTAGTransport(Transport):
    """Register access via Vivado hw_server + JTAG-AXI IP.

    Uses Vivado TCL commands over a socket connection to hw_server.
    Requires: Vivado hw_server running, JTAG-AXI IP in bitstream.
    """

    def __init__(self, hw_server: str = "localhost:3121", target_index: int = 0):
        self._server = hw_server
        self._target_idx = target_index
        self._vivado = None

    def open(self):
        import subprocess
        # Launch Vivado in TCL server mode for register access
        # Alternative: use hw_server protocol directly
        print(f"JTAG transport: connect to {self._server}")
        print("Use Vivado Hardware Manager for JTAG-AXI transactions")
        print("Or run: vivado -mode tcl, then source jtag_rw.tcl")

    def close(self):
        pass

    def write32(self, addr: int, value: int):
        # Generate TCL command for Vivado JTAG-AXI
        print(f"create_hw_axi_txn wr_txn [get_hw_axis hw_axi_1] "
              f"-type write -address {addr:08X} -data {value:08X}")

    def read32(self, addr: int) -> int:
        print(f"create_hw_axi_txn rd_txn [get_hw_axis hw_axi_1] "
              f"-type read -address {addr:08X}")
        print(f"run_hw_axi rd_txn")
        return 0  # Placeholder; real impl reads hw_axi result


class SimTransport(Transport):
    """Simulated transport for offline development/testing.
    Maintains a dict of register values.
    """

    def __init__(self):
        self._regs = {}
        # Pre-populate read-only registers
        from ate_regs import DEVICE_ID, REG_DEVICE_ID, REG_FPGA_VERSION
        self._regs[REG_DEVICE_ID] = DEVICE_ID
        self._regs[REG_FPGA_VERSION] = 0x00010000

    def open(self):
        pass

    def close(self):
        pass

    def write32(self, addr: int, value: int):
        self._regs[addr] = value & 0xFFFFFFFF

    def read32(self, addr: int) -> int:
        return self._regs.get(addr, 0xDEADBEEF)
