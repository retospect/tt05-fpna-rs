import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
from bitstream_gen import BitstreamGen

bitstream_x = 4
bitstream_y = 4


def getBitstream():
    bitstream = BitstreamGen(bitstream_x, bitstream_y)
    bitstream.reset()
    return bitstream


def isBitstream(bitstream):
    """assert that the bitstream is an array of 1's and 0's"""
    # assert that the bitstream is an array of 1's and 0's
    assert isinstance(bitstream, list)
    assert all(isinstance(x, int) for x in bitstream)
    assert all(x == 0 or x == 1 for x in bitstream)


async def loadBitstream(dut, bitstream, bs_in, config_en):
    """load the bitstream into the shift register"""
    isBitstream(bitstream)
    config_en.value = 1

    for bit in bitstream:
        bs_in.value = bit
        await ClockCycles(dut.clk, 1)
    config_en.value = 0
    bs_in.value = 0


async def checkBitstream(dut, bitstream, bs_out, config_en):
    """check the shift register against the expected bitstream"""
    isBitstream(bitstream)

    config_en.value = 1
    for i in range(len(bitstream)):
        await ClockCycles(dut.clk, 1)
        bit = bitstream[i]
        print(i, bs_out.value, bit)
        assert bs_out.value == bit
    config_en.value = 0


@cocotb.test()
async def test_shiftreg(dut):
    config_en = dut.uio_in[3]
    bs_in = dut.uio_in[2]
    bs_out = dut.uio_out[1]
    bs_in.value = 0

    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # reset
    dut._log.info("reset")
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    bitstream = getBitstream()
    bitarray = bitstream.getBS()

    print("bitstream length: %d" % len(bitarray))
    dut._log.info("bitstream length: %d" % len(bitarray))

    await loadBitstream(dut, bitarray, bs_in, config_en)
    await checkBitstream(dut, bitarray, bs_out, config_en)

    # bitstream.cells[1][1].uT.set(5)
    bitstream.ones()
    bitarray = bitstream.getBS()
    print(bitarray)
    await loadBitstream(dut, bitarray, bs_in, config_en)
    await checkBitstream(dut, bitarray, bs_out, config_en)
