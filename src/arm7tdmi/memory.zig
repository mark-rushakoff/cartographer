/// Status for the CPU when reading a 32-bit whole word.
pub const PendingReadWord = struct {
    address: u32,
    value: ?u32,

    // TODO: remaining cycles
};

/// Status for the CPU when reading a 16-bit half word.
pub const PendingReadHalf = struct {
    address: u32,
    value: ?u16,

    // TODO: remaining cycles
};

/// Status for the CPU when reading an 8-bit byte.
pub const PendingReadByte = struct {
    address: u32,
    value: ?u8,

    // TODO: remaining cycles
};

/// Status for the CPU when writing a 32-bit whole word.
pub const PendingWriteWord = struct {
    address: u32,
    value: u32,

    // TODO: remaining cycles
};

/// Status for the CPU when writing a 16-bit half word.
pub const PendingWriteHalf = struct {
    address: u32,
    value: u16,

    // TODO: remaining cycles
};

/// Status for the CPU when writing an 8-bit byte.
pub const PendingWriteByte = struct {
    address: u32,
    value: u8,

    // TODO: remaining cycles
};
