const State = @import("./registers.zig").Registers.State;
const WaitStatus = @import("./cpu.zig").WaitStatus;

const instructions = @import("./cpu.zig").instructions;

const PipelineDecodingValue = union(State) {
    arm: u32,
    thumb: u16,
};

pub const PipelineFetchState = union(enum) {
    pending_half: u32,
    pending_word: u32,

    completed_half: u32,
    completed_word: u32,
};

pub const ReadyInstruction = union(State) {
    arm: instructions.Arm,
    thumb: instructions.Thumb,
};

pub const Pipeline = struct {
    /// Whether the pipeline is fetching 32-bit ARM
    /// or 16-bit THUMB instructions.
    state: State,

    /// Outstanding fetch that has not yet completed,
    /// or a fetch that completed but could not advance through the pipeline
    /// due to execute and decode still being populated.
    fetch_state: ?PipelineFetchState,

    /// A full word or half word has been fetched.
    /// It needs to be decoded into an instruction.
    decoding_value: ?PipelineDecodingValue,

    /// The instruction
    ready: ?ReadyInstruction,

    pub fn init(state: State) Pipeline {
        return .{
            .state = state,

            .fetch_state = null,
            .decoding_value = null,
            .ready = null,
        };
    }

    /// Flushing the pipeline is coordinated through the Core.
    /// The CPU will signal when a branch is taken,
    /// at which point the pipeline can be flushed and the new state can be noted.
    pub fn flush(self: *Pipeline, state: State) void {
        self.* = Pipeline.init(state);
    }

    pub fn tick(self: *Pipeline, pc: u32) void {
        if (self.fetch_state == null) {
            self.fetch_state = switch (self.state) {
                .thumb => .{ .pending_half = pc },
                .arm => .{ .pending_word = pc },
            };
        }
    }

    // Completing the fetch is coordinated through the Core.
    pub fn completeFetchHalf(self: *Pipeline, opcode: u16, pc: *u32) void {
        if (self.fetch_state == null) {
            @panic("tried to complete a null pending fetch");
        }

        if (self.state != .thumb) {
            @panic("tried to complete a half-word fetch while in arm mode");
        }

        if (self.decoding_value == null) {
            self.decoding_value = .{ .thumb = opcode };
            self.fetch_state = null;
        } else {
            self.fetch_state = .{ .completed_half = opcode };
        }

        pc.* += 2;
    }

    // Completing the fetch is coordinated through the Core.
    pub fn completeFetchWord(self: *Pipeline, opcode: u32, pc: *u32) void {
        if (self.fetch_state == null) {
            @panic("tried to complete a null pending fetch");
        }

        if (self.state != .arm) {
            @panic("tried to complete a full-word fetch while in thumb mode");
        }

        if (self.decoding_value == null) {
            self.decoding_value = .{ .arm = opcode };
            self.fetch_state = null;
        } else {
            self.fetch_state = .{ .completed_word = opcode };
        }

        pc.* += 4;
    }
};

const testing = @import("std").testing;
const ctest = @import("ctest");

test "first cycle: thumb" {
    var p = Pipeline.init(.thumb);

    // Initializes with nil fields.
    try testing.expectEqual(null, p.fetch_state);
    try testing.expectEqual(null, p.decoding_value);
    try testing.expectEqual(null, p.ready);

    var pc: u32 = 0x8100_0000;
    p.tick(pc);

    // Now the fetch is pending.
    try testing.expectEqual(PipelineFetchState{
        .pending_half = pc,
    }, p.fetch_state);

    // But nothing decoded or ready yet.
    try testing.expectEqual(null, p.decoding_value);
    try testing.expectEqual(null, p.ready);

    // Now the core completes the fetch.
    p.completeFetchHalf(0x1234, &pc);

    // That means the fetch state is null again, we are decoding that op,
    // and the ready slot is also still null.
    try testing.expectEqual(null, p.fetch_state);
    try testing.expectEqual(0x1234, p.decoding_value.?.thumb);
    try testing.expectEqual(null, p.ready);

    // And the pc is increased by 2 bytes for THUMB.
    try ctest.expectEqualHex(0x8100_0002, pc);

    // TODO: one more tick to see a new pending fetch
    // and shift from decoding to ready.
}
