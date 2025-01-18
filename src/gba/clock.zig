/// System clock.
///
/// Not sure if this type is going to stay
/// or get absorbed into a higher level type.
pub const Clock = struct {
    // At 16.78MHz, it would take about 35 years to overflow the cycle count,
    // so a u64 seems completely appropriate here.
    cycle_count: u64,

    pub fn tick(self: *Clock) void {
        // TODO: ppu first

        // TODO: DMA would take priority over CPU

        self.cycle_count += 1;
    }
};
