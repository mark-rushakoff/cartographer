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
    mem_sign: MemSign,
    mem_offset: MemOffset,
    mem_halfword: MemHalfword,
    access_sp: AccessSp,
    load: Load,
    adjust_sp: AdjustSp,
    stack: Stack,
    mem_multiple: MemMultiple,
    cond_branch: CondBranch,
    software_interrupt: SoftwareInterrupt,
    branch: Branch,
    long_branch: LongBranch,
};

/// Format 1: move shifted register.
///
/// "These instructions move a shifted value between Lo registers."
pub const MoveShifted = struct {
    op: enum(u2) {
        lsl = 0,
        lsr = 1,
        asr = 2,
        // Undefined behavior for 3?
    },
    offset: u5,
    rs: u3,
    rd: u3,
};

/// Format 2: add/subtract.
///
/// "These instructions allow the contents of a Lo register or a 3-bit immediate value to be
/// added to or subtracted from a Lo register."
pub const AddSubtract = struct {
    imm: u1, // Whether val is an immediate value or a register reference.
    op: enum(u1) {
        add = 0,
        sub = 1,
    },
    val: u3, // Register or immediate value.
    rs: u3,
    rd: u3,
};

/// Format 3: move/compare/add/subtract immediate.
///
/// "The instructions in this group perform operations between a Lo register and an 8-bit
/// immediate value."
pub const Immediate = struct {
    op: enum(u2) {
        mov = 0,
        cmp = 1,
        add = 2,
        sub = 3,
    },
    rd: u3,
    val: u8,
};

/// Format 4: ALU operations.
///
/// "The following instructions perform ALU operations on a Lo register pair."
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
    rs: u3,
    rd: u3,
};

/// Format 5: Hi register operations/branch exchange.
///
/// "There are four sets of instructions in this group. The first three allow ADD, CMP and
/// MOV operations to be performed between Lo and Hi registers, or a pair of Hi registers.
/// The fourth, BX, allows a Branch to be performed which may also be used to switch
/// processor state."
pub const HiRegister = struct {
    op: enum(u2) {
        add = 0,
        cmp = 1,
        mov = 2,
        bx = 3,
    },
    h1: u1,
    h2: u1,
    rs: u3,
    rd: u3,
};

/// Format 6: PC-relative load.
///
/// "This instruction loads a word from an address specified as a 10-bit immediate offset
/// from the PC."
pub const PcLoad = struct {
    rd: u3,
    val: u8,
};

/// Format 7: load/store with register offset.
///
/// "These instructions transfer byte or word values between registers and memory.
/// Memory addresses are pre-indexed using an offset register in the range 0-7."
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

/// Format 8: load/store sign-extended byte/halfword.
///
/// "These instructions load optionally sign-extended bytes or halfwords,
/// and store halfwords."
pub const MemSign = struct {
    h: u1,
    s: u1,
    ro: u3,
    rb: u3,
    rd: u3,
};

/// Format 9: load/store with immediate offset.
///
/// "These instructions transfer byte or word values between registers
/// and memory using an immediate 5 or 7-bit offset."
pub const MemOffset = struct {
    b: enum(u1) {
        word = 0,
        byte = 1,
    },
    l: enum(u1) {
        store = 0,
        load = 1,
    },
    offset: u5,
    rb: u3,
    rd: u3,
};

/// Format 10: load/store halfword.
///
/// "These instructions transfer halfword values between a Lo register and memory.
/// Addresses are pre-indexed, using a 6-bit immediate value."
pub const MemHalfword = struct {
    l: enum(u1) {
        store = 0,
        load = 1,
    },
    offset: u5,
    rb: u3,
    rd: u3,
};

/// Format 11: SP-relative load/store.
///
/// "The instructions in this group perform an SP-relative load or store."
pub const AccessSp = struct {
    l: enum(u1) {
        store = 0,
        load = 1,
    },
    rd: u3,
    val: u8,
};

/// Format 12: load address.
///
/// "These instructions calculate an address by adding an 10-bit constant to either the PC
/// or the SP, and load the resulting address into a register."
pub const Load = struct {
    src: enum(u1) {
        pc = 0,
        sp = 1,
    },
    rd: u3,
    val: u8,
};

/// Format 13: add offset to Stack Pointer.
///
/// "This instruction adds a 9-bit signed constant to the stack pointer."
pub const AdjustSp = struct {
    // The datasheet has a separate sign bit and a 7-bit value
    // to be interpreted as signed or unsigned based on the sign bit.
    //
    // Seems like it makes more sense to just use an i8 here.
    offset: i8,
};

/// Format 14: push/pop registers.
///
/// "The instructions in this group allow registers 0-7
/// and optionally LR to be pushed onto the stack,
/// and registers 0-7 and optionally PC to be popped off the stack."
pub const Stack = struct {
    l: enum(u1) {
        store = 0,
        load = 1,
    },
    r: enum(u1) {
        no_store = 0,
        store = 1,
    },
    rlist: u8,
};

/// Format 15: multiple load/store.
///
/// "These instructions allow multiple loading and storing of Lo registers."
pub const MemMultiple = struct {
    l: enum(u1) {
        store = 0,
        load = 1,
    },
    rb: u3,
    rlist: u8,
};

/// Format 16: conditional branch.
///
/// "The instructions in this group all perform a conditional Branch
/// depending on the state of the CPSR condition codes."
pub const CondBranch = struct {
    cond: enum(u4) {
        eq = 0,
        ne = 1,
        cs = 2,
        cc = 3,
        mi = 4,
        pl = 5,
        vs = 6,
        vc = 7,
        hi = 8,
        ls = 9,
        ge = 10,
        lt = 11,
        gt = 12,
        le = 13,
    },
    offset: i8,
};

/// Format 17: software interrupt.
///
/// "The SWI instruction performs a software interrupt."
pub const SoftwareInterrupt = struct {
    val: u8,
};

/// Format 18: unconditional branch.
///
/// "This instruction performs a PC-relative Branch."
pub const Branch = struct {
    offset: i11,
};

/// Format 19: long branch with link.
///
/// "This format specifies a long branch with link."
pub const LongBranch = struct {
    h: enum(u1) {
        high = 0,
        low = 1,
    },
    offset: i11,
};
