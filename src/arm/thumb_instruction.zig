// Reference: ARM7TDMI Data Sheet
// (Look up ARM DDI 0029E, which appears to be labeled as "open access".)

pub const ThumbInstruction = union(enum) {
    // These values are in the same order as the data sheet.

    move_shifted: MoveShifted,
    add_subtract: AddSubtract,
    immediate: Immediate,
    alu: Alu,
    hi_register: HiRegister,
    pc_load: PcLoad,
    reg_offset: RegOffset,
};

pub const MoveShifted = struct {
    op: enum(u2) {
        lsl = 0,
        lsr = 1,
        asr = 2,
        // Undefined behavior for 3?
    },
    offset: u5,
    src: u3,
    dst: u3,
};

pub const AddSubtract = struct {
    imm: u1, // Whether val is an immediate value or a register reference.
    op: enum(u1) {
        add = 0,
        sub = 1,
    },
    val: u3, // Register or immediate value.
    src: u3,
    dst: u3,
};

pub const Immediate = struct {
    op: enum(u2) {
        mov = 0,
        cmp = 1,
        add = 2,
        sub = 3,
    },
    dst: u3,
    val: u8,
};

pub const Alu = struct {
    op: enum(u4) {
        and_ = 0,
        eor = 1,
        lsl = 2,
        lsr = 3,
        asr = 4,
        adc = 5,
        sbc = 6,
        ror = 7,
        tst = 8,
        neg = 9,
        cmp = 10,
        cmn = 11,
        orr = 12,
        mul = 13,
        bic = 14,
        mvn = 15,
    },
    src: u3,
    dst: u3,
};

pub const HiRegister = struct {
    op: enum(u2) {
        add = 0,
        cmp = 1,
        mov = 2,
        bx = 3,
    },
    h1: u1,
    h2: u1,
    src: u3,
    dst: u3,
};

pub const PcLoad = struct {
    dst: u3,
    val: u8,
};

pub const RegOffset = struct {
    l: enum(u1) {
        store = 0,
        load = 1,
    },
    b: enum(u1) {
        word = 0,
        byte = 1,
    },
    ro: u3,
    rb: u3,
    rd: u3,
};
