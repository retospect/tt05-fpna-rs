#! python3
# defines two classes: A cell and a bitstream_gen.
# The cell contains registers that are joined in a shift register.
# The bitstream_gen contains an array of cells.
# The bitstream_gen is responsible for generating the bitstream.


class BitstreamGen:
    def __init__(self, xCells, yCells):
        self.xCells = xCells
        self.yCells = yCells
        # cells is a 3d array of cells
        self.cells = []
        for x in range(xCells):
            self.cells.append([])
            for y in range(yCells):
                self.cells[x].append(Cell())

    def reset(self):
        """reset the bitstream generator"""
        for x in range(self.xCells):
            for y in range(self.yCells):
                self.cells[x][y].reset()

    def ones(self):
        """set all the cells to 1"""
        for x in range(self.xCells):
            for y in range(self.yCells):
                self.cells[x][y].ones()

    def getBS(self):
        """get the bitstream of the generator"""
        bs = []
        for x in range(self.xCells):
            for y in range(self.yCells):
                bs += self.cells[x][y].getBS()
        return bs

    def getAllCells(self):
        """get a linearized array of all the cells"""
        cells = []
        for x in range(self.xCells):
            for y in range(self.yCells):
                yield self.cells[x][y]


class Register:
    def __init__(self, length, initValue=0):
        """length is the number of bits in the register"""
        self.length = length
        self.value = initValue

    def set(self, value):
        """set the value of the register"""
        assert type(value) == int
        assert value < 2**self.length
        assert value >= 0
        self.value = value

    def reset(self):
        """reset the register to 0"""
        self.value = 0

    def ones(self):
        """set the register to all 1's"""
        self.value = 2**self.length - 1

    def getBS(self):
        """get the array of bits representing the register"""
        return [int(x) for x in bin(self.value)[2:].zfill(self.length)]


class Cell:
    def __init__(self):
        self.w1 = Register(3)
        self.w2 = Register(3)
        self.w3 = Register(3)
        self.w4 = Register(3)
        self.uT = Register(4)
        self.clockDecay = Register(3)

    def getBS(self):
        """get the bitstream of the cell"""
        return (
            self.w1.getBS()
            + self.w2.getBS()
            + self.w3.getBS()
            + self.w4.getBS()
            + self.uT.getBS()
            + self.clockDecay.getBS()
        )

    def reset(self):
        """reset the cell to 0"""
        self.w1.reset()
        self.w2.reset()
        self.w3.reset()
        self.w4.reset()
        self.uT.reset()
        self.clockDecay.reset()

    def ones(self):
        """set the cell to all 1's"""
        self.w1.ones()
        self.w2.ones()
        self.w3.ones()
        self.w4.ones()
        self.uT.ones()
        self.clockDecay.ones()


if __name__ == "__main__":
    # test the bitstream generator
    # Make a 2x2 bitstream generator
    # Read the bitstream
    # Check that the bitstream length is correct and all the values are 0
    xCells = 2
    yCells = 2
    bitstream_gen = BitstreamGen(xCells, yCells)
    bs = bitstream_gen.getBS()
    assert len(bs) == xCells * yCells * 16
    for i in range(len(bs)):
        assert bs[i] == 0

    # Make another bitstream generator
    # Set the value of the 2,2 clock decay to 7
    # Read the bitstream
    # Check that the bitstream length is correct and all the values are, except for the clock decay
    bitstream_gen = BitstreamGen(xCells, yCells)
    bitstream_gen.cells[1][1].clockDecay.set(2)
    bs = bitstream_gen.getBS()
    assert len(bs) == xCells * yCells * 16
    for i in range(len(bs)):
        if i == 62:
            assert bs[i] == 1
        else:
            assert bs[i] == 0

    bitstream_gen.reset()
    bs = bitstream_gen.getBS()
    assert len(bs) == xCells * yCells * 16
    for i in range(len(bs)):
        assert bs[i] == 0

    bitstream_gen.ones()
    bs = bitstream_gen.getBS()
    assert len(bs) == xCells * yCells * 16
    for i in range(len(bs)):
        assert bs[i] == 1

    print("All tests passed.")
