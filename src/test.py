import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

bitstream_length = 10

@cocotb.test()
async def test_shiftreg(dut):
    config_en = dut.uio_in[3]
    bs_in     = dut.uio_in[2]
    bs_out    = dut.uio_out[1]
    bs_in.value = 0 

    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # reset
    dut._log.info("reset")
    dut.rst_n.value = 0
    # set the compare value
    
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    config_en.value = 1 
    # initialize the bitstream buffer.
    await ClockCycles(dut.clk, bitstream_length+10)

    bs_in.value = 1
    await ClockCycles(dut.clk, 1)
    bs_in.value = 0
    for i in range(bitstream_length-1):
        await ClockCycles(dut.clk, 1)
        print(i, bs_out.value)
        assert bs_out.value == 0
    await ClockCycles(dut.clk, 1)
    assert bs_out.value == 1


