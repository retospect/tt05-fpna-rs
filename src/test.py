import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
from bitstream_gen import BitstreamGen

# Must match paramter X_MAX and Y_MAX in tt_um_retospect_neurochip.v
bitstream_x = 10
bitstream_y = 5
counter_cnt = 6


def getBitstream():
    """Gets a default bitstream, initialized"""
    bitstream = BitstreamGen(bitstream_x, bitstream_y, counter_cnt)
    bitstream.reset()
    return bitstream


def isBitstream(bitstream):
    """assert that the bitstream is an array of 1's and 0's"""
    # assert that the bitstream is an array of 1's and 0's
    assert isinstance(bitstream, list)
    assert all(isinstance(x, int) for x in bitstream)
    assert all(x == 0 or x == 1 for x in bitstream)


async def loadBitstream(dut, bitstream):
    """load the bitstream into the shift register"""
    isBitstream(bitstream)

    config_en = dut.uio_in[3]
    bs_in = dut.uio_in[2]
    bs_out = dut.uio_out[1]
    bs_in.value = 0

    config_en.value = 1

    for bit in bitstream:
        bs_in.value = bit
        await ClockCycles(dut.clk, 1)
    config_en.value = 0
    bs_in.value = 0


async def checkBitstream(dut, bitstream):
    """check the shift register against the expected bitstream"""
    isBitstream(bitstream)

    config_en = dut.uio_in[3]
    bs_in = dut.uio_in[2]
    bs_out = dut.uio_out[1]
    bs_in.value = 0

    config_en.value = 1

    for i in range(len(bitstream)):
        await ClockCycles(dut.clk, 1)
        bit = bitstream[i]
        # show the sequence id, the expected and the actual bit
        # note that the bs_out.value can be a number or a string
        # if it is a string, it is likely the string "z"
        # print("%d: %d %s" % (i, bit, bs_out.value))
        assert bs_out.value == bit
    config_en.value = 0
    bs_in.value = 0


async def reset(dut, bitstream):
    """Initialize the device and load the provided bitstream"""
    # zero out all inputs
    for i in range(8):
        dut.uio_in[i].value = 0
        dut.ui_in[i].value = 0
    config_en = dut.uio_in[3]
    dut.tt_um_retospect_neurochip.ena.value = 1

    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # reset
    dut._log.info("reset")
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1  # reset is now done

    bitstream = getBitstream()
    bitarray = bitstream.getBS()

    print("bitstream length: %d" % len(bitarray))
    dut._log.info("bitstream length: %d" % len(bitarray))
    await loadBitstream(dut, bitarray)
    config_en.value = 0


def listEntries(item):
    """Shows all the objects in an item"""
    # get the type of item
    # if item is iterable, print its type and recurse into it

    t = type(item)
    # if it is not a cocotb object, print its type and return
    if not "cocotb" in str(t):
        print("not cocotb object: %s: %s" % (item, t))
        return

    # if it is a cocotb object, print its type
    fullpath = item._path
    if hasattr(item, "__iter__"):
        # if this object has a value, do not recurse into it
        if hasattr(item, "value"):
            pass

        else:
            # print("DOWN: %s: %s" % (fullpath, t))
            for i in item:
                listEntries(i)

    # if it is a modifiable object, print its full _path and value
    if "ModifiableObject" in str(t):
        print("V: %s: %s" % (fullpath, item.value))

    elif "NonHierarchyIndexableObject" in str(t):
        print("NHI: %s: %s" % (fullpath, item.value))

    # if it is a constant object, print its full _path and value
    elif "ConstantObject" in str(t):
        print("C: %s: %s (C)" % (fullpath, item.value))

    elif "HierarchyObject" in str(t) or "HierarchyArrayObject" in str(t):
        # print("%s" % (fullpath))
        # if it is a hierarchy object, recurse into it
        # for name, handle in item._sub_handles.items():
        #    # catch any exceptions and print them while iterating
        #    try:
        #        listEntries(handle)
        #    except Exception as e:
        #        print("Exception while processing child of %s: %s" % (fullpath, e))
        pass
    else:
        print("unknown type: %s: %s" % (t, item))
    return


def b2i(x):
    """Converts a cocotb binary value to an integer"""
    return int(str(x), 2)


@cocotb.test()
async def test_shiftreg(dut):
    bitstream = getBitstream()
    await reset(dut, bitstream)
    print("After reset")
    await checkBitstream(dut, bitstream.getBS())

    # Reset_nn is high for a cycle, so all the uT values should be
    # set to 1
    for cell in bitstream.getAllCells():
        cell.uT.set(1)
    reset_nn = dut.uio_in[0]
    reset_nn.value = 1
    await ClockCycles(dut.clk, 1)
    reset_nn.value = 0

    print("After reset_nn")
    await loadBitstream(dut, bitstream.getBS())

    bitstream.ones()
    bitstream.cells[0][0].uT.set(5)
    bitstream.cells[bitstream_x - 1][bitstream_y - 1].uT.set(3)
    print("After ones")
    await loadBitstream(dut, bitstream.getBS())
    await checkBitstream(dut, bitstream.getBS())


@cocotb.test()
async def test_register_mapping(dut):
    bitstream = getBitstream()
    bitstream.clockbox.delay[3].set(5)
    bitstream.reset()
    await reset(dut, bitstream)
    tl = dut.tt_um_retospect_neurochip
    assert tl.uio_out[0].value == 0
    listEntries(tl.clockbox)
    assert inti(tl.clockbox.clock_max[3].value) == 5


@cocotb.test()
async def test_clockgen(dut):
    bitstream = getBitstream()
    bitstream.clockbox.delay[3].set(5)
    await reset(dut, bitstream)
