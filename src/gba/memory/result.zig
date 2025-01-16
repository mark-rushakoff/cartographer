pub fn ReadResult(comptime T: type) type {
    return struct {
        value: T,
        timing: Timing,
    };
}

const WriteResult = struct {
    timing: Timing,
};

// Placeholder for now.
pub const Timing = struct {
    cycles: u32,
};
