const State = @import("./registers.zig").Registers.State;
const WaitStatus = @import("./cpu.zig").WaitStatus;

const m = @import("./memory.zig");
const PendingReadWord = m.PendingReadWord;
const PendingReadHalf = m.PendingReadHalf;

const instructions = @import("./cpu.zig").instructions;

const DecodingValue = union(State) {
    arm: u32,
    thumb: u16,
};

pub const PendingFetch = union(State) {
    arm: PipelinePendingReadWord,
    thumb: PipelinePendingReadHalf,
};

pub const PipelinePendingReadHalf = struct { addr: u32 };
pub const PipelinePendingReadWord = struct { addr: u32 };

pub const ReadyInstruction = union(State) {
    arm: instructions.Arm,
    thumb: instructions.Thumb,
};

pub const Pipeline = struct {
    /// Whether the pipeline is fetching 32-bit ARM
    /// or 16-bit THUMB instructions.
    state: State,

    /// Outstanding fetch that has not yet completed.
    /// Depending on CPU state, could be a full word or half word fetch.
    pending_fetch: ?PendingFetch,

    /// A full word or half word has been fetched.
    /// It needs to be decoded into an instruction.
    decoding_value: ?DecodingValue,

    ///
    ready: ?ReadyInstruction,

    /// Program Counter.
    /// Dubious whether we actually need this field,
    /// as we currently store it in Pipeline
    /// but also accept it as an argument to tick.
    /// There should only be one value tracking pc, ideally.
    pc: u32,

    pub fn init(state: State, pc: u32) Pipeline {
        return .{
            .state = state,

            .pending_fetch = null,
            .decoding_value = null,
            .ready = null,

            .pc = pc,
        };
    }

    /// Flushing the pipeline is coordinated through the Core.
    /// The CPU will signal when a branch is taken,
    /// at which point the pipeline can be flushed and the new state can be noted.
    pub fn flush(self: *Pipeline, state: State, pc: u32) void {
        self.* = Pipeline.init(state, pc);
    }

    pub fn tick(self: *Pipeline, pc: u32) void {
        if (self.pending_fetch == null) {
            self.pending_fetch = switch (self.state) {
                .arm => .{
                    .arm = PipelinePendingReadWord{ .addr = pc },
                },
                .thumb => .{
                    .thumb = PipelinePendingReadHalf{ .addr = pc },
                },
            };
        }
    }

    // Completing the fetch is coordinated through the Core.
    // The return value is how much to increment pc.
    pub fn completeFetch(self: *Pipeline, value: DecodingValue) u32 {
        if (self.pending_fetch == null) {
            @panic("tried to complete a null pending fetch");
        }

        _ = value;

        return switch (self.state) {
            .arm => 4,
            .thumb => 2,
        };
    }
};

const testing = @import("std").testing;
const ctest = @import("ctest");

test "first cycle: thumb" {
    const pc: u32 = 0x8100_0000;
    var tp = Pipeline.init(.thumb, pc);

    // Initializes with nil fields.
    try testing.expectEqual(null, tp.pending_fetch);
    try testing.expectEqual(null, tp.decoding_value);
    try testing.expectEqual(null, tp.ready);

    try ctest.expectEqualHex(0x8100_0000, tp.pc);

    tp.tick(pc);

    // Now the fetch is pending.
    try testing.expectEqual(tp.pending_fetch, PendingFetch{
        .thumb = PipelinePendingReadHalf{ .addr = 0x8100_0000 },
    });

    // But nothing decoded or ready yet.
    try testing.expectEqual(null, tp.decoding_value);
    try testing.expectEqual(null, tp.ready);

    // And the pc hasn't been modified.
    try ctest.expectEqualHex(0x8100_0000, tp.pc);

    // TODO: continue expanding this test.
}
