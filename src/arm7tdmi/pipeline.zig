const State = @import("./registers.zig").Registers.State;

const instructions = @import("./cpu.zig").instructions;

const PipelineDecodingValue = union(State) {
    arm: u32,
    thumb: u16,
};

pub const PipelineFetchState = union(enum) {
    /// Pending half-word read at the given address.
    pending_half: u32,
    /// Pending full-word read at the given address.
    pending_word: u32,

    /// Completed half-word read with the given value.
    completed_half: u16,
    /// Completed full-word read with the given value.
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

    /// The instruction to be executed by the CPU.
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
        self.tick_decoding();
        self.tick_fetch_state(pc);
    }

    // Handle the decoding value's reaction to a tick.
    fn tick_decoding(self: *Pipeline) void {
        if (self.decoding_value == null or self.ready != null) {
            // We can't shift decoding,
            // because we don't have a value or we don't have a place for it to go.
            return;
        }

        // Otherwise we do have a decoding value and ready is null,
        // so we can decode and shift.
        self.ready = .{
            .thumb = instructions.Thumb.decode(self.decoding_value.?.thumb),
        };
        self.decoding_value = null;
    }

    /// Handle the fetch_state field's reaction to a tick.
    fn tick_fetch_state(self: *Pipeline, pc: u32) void {
        if (self.fetch_state) |fs| {
            if (self.decoding_value != null) {
                // Whether the fetch is completed or pending,
                // we can't shift it if we still have a populated decoding value.
                return;
            }

            switch (fs) {
                // Decoding value is null, so we can populate it
                // if we have a completed fetch.
                .completed_half => {
                    self.decoding_value = .{ .thumb = fs.completed_half };
                    self.begin_fetch(pc);
                },
                .completed_word => {
                    self.decoding_value = .{ .arm = fs.completed_word };
                    self.begin_fetch(pc);
                },

                // Otherwise the fetch was still pending so we can't do anything.
                else => {},
            }

            return;
        }

        // Otherwise fetch state was null;
        // this should only happen in initial state or after a flush.
        self.begin_fetch(pc);
    }

    /// Begin a fetch for the instruction at pc.
    /// This happens in initial state, after a flush,
    /// or following a completed fetch that shifts to decoding.
    fn begin_fetch(self: *Pipeline, pc: u32) void {
        self.fetch_state = switch (self.state) {
            .thumb => .{ .pending_half = pc },
            .arm => .{ .pending_word = pc },
        };
    }

    // Completing the fetch is coordinated through the Core.
    pub fn completeFetchHalf(self: *Pipeline, opcode: u16, pc: *u32) void {
        if (self.fetch_state == null) {
            @panic("tried to complete a null pending fetch");
        }

        if (self.state != .thumb) {
            @panic("tried to complete a half-word fetch while in arm mode");
        }

        self.fetch_state = .{ .completed_half = opcode };

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

        self.fetch_state = .{ .completed_word = opcode };

        pc.* += 4;
    }
};

const testing = @import("std").testing;
const ctest = @import("ctest");

test "from flush, thumb state" {
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

    // And if we tick again -- as would happen with memory in wait state --
    // nothing changes.
    p.tick(pc);

    try testing.expectEqual(PipelineFetchState{
        .pending_half = pc,
    }, p.fetch_state);

    // But nothing decoded or ready yet.
    try testing.expectEqual(null, p.decoding_value);
    try testing.expectEqual(null, p.ready);

    // Now the core completes the fetch.
    // This would happen at the end of a tick, before the next tick starts.
    const inst = instructions.Thumb.Immediate{
        .op = .mov,
        .rd = 0,
        .val = 123,
    };
    const op = inst.encode();
    p.completeFetchHalf(op, &pc);

    // Now the fetch state has changed from pending to complete.
    // Still nothing decoding or ready.
    try testing.expectEqual(PipelineFetchState{
        .completed_half = op,
    }, p.fetch_state);
    try testing.expectEqual(null, p.decoding_value);
    try testing.expectEqual(null, p.ready);

    // On the next tick, we begin a new fetch
    // while the old fetch is moved to decoding.
    p.tick(pc);
    try testing.expectEqual(PipelineFetchState{
        .pending_half = pc,
    }, p.fetch_state);
    try testing.expectEqual(op, p.decoding_value.?.thumb);
    try testing.expectEqual(null, p.ready);

    // And the pc was increased by 2 bytes for THUMB.
    try ctest.expectEqualHex(0x8100_0002, pc);

    // Now we do another tick.
    // The fetch hasn't completed so that is still pending.
    // But we had a decoding value,
    // so now decoding shifts out to ready.
    p.tick(pc);
    try testing.expectEqual(PipelineFetchState{
        .pending_half = pc,
    }, p.fetch_state);
    try testing.expectEqual(null, p.decoding_value);
    try testing.expectEqual(inst, p.ready.?.thumb.immediate);
}
