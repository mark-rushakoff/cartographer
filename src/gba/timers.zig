/// An individual timer.
/// Part of `Timers` and should therefore not be instantiated directly.
const Timer = struct {
    /// Current timer value.
    counter: u16,

    /// Value to re-set on overflow.
    /// This should not be modified directly.
    /// Use the enable method.
    reload: u16,

    /// Whether the timer is currently running.
    /// This should not be modified directly.
    /// Use the enable method.
    running: bool,

    /// Also known as "count up."
    /// Ignored on the zeroth timer.
    cascade: bool,

    prescaler: enum(u2) {
        div_1 = 0b00,
        div_64 = 0b01,
        div_256 = 0b10,
        div_1024 = 0b11,
    },

    pub fn tick(self: *Timer) bool {
        if (self.counter == 0xffff) {
            self.counter = self.reload;

            // TODO: mark interrupt ready, if interrupts enabled for this timer.

            return true;
        }

        self.counter += 1;
        return false;
    }

    /// Enable the timer with the given reload.
    /// Normally would be called via the IO controller.
    pub fn enable(self: *Timer, reload: u16) void {
        self.reload = reload;
        self.counter = reload;
        self.running = true;
    }

    /// Disable the timer.
    /// Normally would be called via the IO controller.
    pub fn disable(self: *Timer) void {
        self.running = false;
    }
};

// The collection of `Timer` values.
pub const Timers = struct {
    timers: [4]Timer,

    pub fn init() Timers {
        const defaultTimer = Timer{
            .counter = 0,
            .reload = 0,
            .running = false,
            .cascade = false,
            .prescaler = .div_1,
        };
        return .{
            .timers = .{defaultTimer} ** 4,
        };
    }

    /// Relay a tick to any active timer,
    /// handling prescale and cascades appropriately.
    ///
    /// The argument `cycle_count` is used under the assumption that
    /// the prescaling is absolute based on total clock cycles.
    /// If that assumption is wrong, then we will remove `cycle_count` later.
    ///
    /// TODO: create interrupts from timer overflows on request.
    pub fn tick(self: *Timers, cycle_count: u64) void {
        var prev_overflowed = false;

        for (&self.timers, 0..) |*timer, i| {
            if (!timer.running) {
                continue;
            }

            if (timer.cascade and i != 0) {
                // If cascading, the prescaler is disregarded.
                // (Cascade has no effect on timer zero.)
                if (prev_overflowed) {
                    prev_overflowed = timer.tick();

                    // TODO: trigger interrupt if necessary.
                }

                continue;
            }

            // If not cascading, then respect the prescaler.
            // We are assuming that the prescaler is an absolute count,
            // not relative to the cycle count when the timer was enabled.
            const prescaler_match = switch (timer.prescaler) {
                .div_1 => true,
                .div_64 => cycle_count & (64 - 1) == 0,
                .div_256 => cycle_count & (256 - 1) == 0,
                .div_1024 => cycle_count & (1024 - 1) == 0,
            };

            if (!prescaler_match) {
                continue;
            }

            prev_overflowed = timer.tick();
        }
    }
};

const testing = @import("std").testing;
const ctest = @import("ctest");

test "Timer.running" {
    var ts = Timers.init();

    // Does not accumulate when .running = false.
    ts.tick(1);
    try testing.expectEqual(0, ts.timers[0].counter);

    // Does accumulate when .running = true.
    ts.timers[0].running = true;
    ts.tick(2);
    try testing.expectEqual(1, ts.timers[0].counter);
    try testing.expectEqual(0, ts.timers[1].counter);
}

test "Timer.prescaler = .div_64" {
    var ts = Timers.init();

    ts.timers[0].running = true;
    ts.timers[0].prescaler = .div_64;
    for (1..64) |i| {
        ts.tick(i);
        try testing.expectEqual(0, ts.timers[0].counter);
    }

    ts.tick(64);
    try testing.expectEqual(1, ts.timers[0].counter);
}

test "Timer.prescaler = .div_256" {
    var ts = Timers.init();

    ts.timers[0].running = true;
    ts.timers[0].prescaler = .div_256;
    for (1..256) |i| {
        ts.tick(i);
        try testing.expectEqual(0, ts.timers[0].counter);
    }

    ts.tick(256);
    try testing.expectEqual(1, ts.timers[0].counter);
}

test "Timer.prescaler = .div_1024" {
    var ts = Timers.init();

    ts.timers[0].running = true;
    ts.timers[0].prescaler = .div_1024;
    for (1..1024) |i| {
        ts.tick(i);
        try testing.expectEqual(0, ts.timers[0].counter);
    }

    ts.tick(1024);
    try testing.expectEqual(1, ts.timers[0].counter);
}

test "Timer.cascade" {
    var ts = Timers.init();

    // Timer 0 will cascade to timer 1 every 4 ticks.
    ts.timers[0].enable(0x1_0000 - 4);
    ts.timers[1].cascade = true;

    // Timer 1 cascades to timer 2 every 3 ticks (so 12 clock ticks).
    ts.timers[1].enable(0x1_0000 - 3);
    ts.timers[2].cascade = true;

    // Timer 2 cascades to timer 3 every 2 ticks (so 24 clock ticks).
    ts.timers[2].enable(0x1_0000 - 2);
    ts.timers[3].cascade = true;

    ts.timers[3].enable(0);

    var ticks: u64 = 0;

    // First wave: timer 0 has not yet cascaded.
    for (0..3) |_| {
        ticks += 1;

        ts.tick(ticks);

        // This is failing, because when we enable the timer,
        // it starts counting at 0 instead of reload.
        // So we probably want an enable method instead.
        try ctest.expectEqualHex(0x1_0000 - 4 + ticks, ts.timers[0].counter);
        try ctest.expectEqualHex(0x1_0000 - 3, ts.timers[1].counter);
        try ctest.expectEqualHex(0x1_0000 - 2, ts.timers[2].counter);
        try ctest.expectEqualHex(0, ts.timers[3].counter);
    }

    // Now the fourth tick.
    // This overflows timer 0, which cascades only to timer 1.
    ticks += 1;
    ts.tick(ticks);

    try ctest.expectEqualHex(0x1_0000 - 4, ts.timers[0].counter);
    try ctest.expectEqualHex(0x1_0000 - 2, ts.timers[1].counter);
    try ctest.expectEqualHex(0x1_0000 - 2, ts.timers[2].counter);
    try ctest.expectEqualHex(0, ts.timers[3].counter);

    // Another four ticks to cascade to timer 1 again.
    for (0..4) |_| {
        ticks += 1;

        ts.tick(ticks);
    }
    try ctest.expectEqualHex(0x1_0000 - 4, ts.timers[0].counter);
    try ctest.expectEqualHex(0x1_0000 - 1, ts.timers[1].counter);
    try ctest.expectEqualHex(0x1_0000 - 2, ts.timers[2].counter);
    try ctest.expectEqualHex(0, ts.timers[3].counter);

    // And four more ticks cascade to timer 1,
    // which in turn cascades to timer 2.
    for (0..4) |_| {
        ticks += 1;

        ts.tick(ticks);
    }
    try ctest.expectEqualHex(0x1_0000 - 4, ts.timers[0].counter);
    try ctest.expectEqualHex(0x1_0000 - 3, ts.timers[1].counter);
    try ctest.expectEqualHex(0x1_0000 - 1, ts.timers[2].counter);
    try ctest.expectEqualHex(0, ts.timers[3].counter);

    // Now timer 1 is three shy of an overflow,
    // and timer 2 is one shy,
    // so three more overflows should get timer 2 to cascade to timer 3.
    for (0..12) |_| {
        ticks += 1;

        ts.tick(ticks);
    }
    try ctest.expectEqualHex(0x1_0000 - 4, ts.timers[0].counter);
    try ctest.expectEqualHex(0x1_0000 - 3, ts.timers[1].counter);
    try ctest.expectEqualHex(0x1_0000 - 2, ts.timers[2].counter);
    try ctest.expectEqualHex(1, ts.timers[3].counter);
}
