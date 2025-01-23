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
    arm: PendingReadWord,
    thumb: PendingReadHalf,
};

pub const ReadyInstruction = union(State) {
    arm: instructions.Arm,
    thumb: instructions.Thumb,
};

pub const Pipeline = struct {
    /// Whether the pipeline is fetching 32-bit ARM
    /// or 16-bit THUMB instructions.
    prev_state: State,

    /// Outstanding fetch that has not yet completed.
    /// Depending on CPU state, could be a full word or half word fetch.
    pending_fetch: ?PendingFetch,

    /// A full word or half word has been fetched.
    /// It needs to be decoded into an instruction.
    decoding_value: ?DecodingValue,

    ///
    ready: ?ReadyInstruction,

    /// Program Counter.
    pc: u32,

    pub fn init(state: State, pc: u32) Pipeline {
        return .{
            .prev_state = state,

            .pending_fetch = null,
            .decoding_value = null,
            .ready = null,

            .pc = pc,
        };
    }

    pub fn tick(self: *Pipeline, state: State, pc: u32) void {
        if (state != self.prev_state) {
            // State changed, so we have to flush.
            self.* = Pipeline.init(state, pc);
        }

        if (self.pending_fetch == null) {
            self.pending_fetch = switch (state) {
                .arm => .{
                    .arm = PendingReadWord{
                        .address = pc,
                        .value = null,
                    },
                },
                .thumb => .{
                    .thumb = PendingReadHalf{
                        .address = pc,
                        .value = null,
                    },
                },
            };
        }
    }

    pub fn completeFetch(self: *Pipeline, value: DecodingValue) void {
        if (self.pending_fetch == null) {
            @panic("tried to complete a nil pending fetch");
        }

        _ = value;
    }
};

const testing = @import("std").testing;
const ctest = @import("ctest");

test "first cycle: thumb" {
    var tp = Pipeline.init(.thumb, 0x8100_0000);

    // Initializes with nil fields.
    try testing.expectEqual(null, tp.pending_fetch);
    try testing.expectEqual(null, tp.decoding_value);
    try testing.expectEqual(null, tp.ready);

    try ctest.expectEqualHex(0x8100_0000, tp.pc);

    tp.tick(.thumb, 0x8100_0000);

    // Now the fetch is pending.
    try testing.expectEqual(tp.pending_fetch, PendingFetch{
        .thumb = PendingReadHalf{
            .address = 0x8100_0000,
            .value = null,
        },
    });

    // But nothing decoded or ready yet.
    try testing.expectEqual(null, tp.decoding_value);
    try testing.expectEqual(null, tp.ready);

    // TODO: continue expanding this test.
}
