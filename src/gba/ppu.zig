/// Picture processing unit.
/// Work in progress.
pub const Ppu = struct {
    enabled: bool,

    cur_line: u16,
    cur_lpx: u16,

    const vis_pixels = 240;
    const blank_pixels = 68;

    const vis_lines = 160;
    const blank_lines = 68;

    pub fn init() Ppu {
        return .{
            .enabled = false,
            .cur_line = 0,
            .cur_lpx = 0,
        };
    }

    pub fn tick(self: *Ppu) void {
        if (!self.enabled) {
            return;
        }

        // TODO: do something with the current pixel.

        if (self.cur_lpx == vis_pixels + blank_pixels) {
            self.cur_lpx = 0;
            if (self.cur_line == vis_lines + blank_lines) {
                self.cur_line = 0;
            } else {
                self.cur_line += 1;
            }
        } else {
            self.cur_lpx += 1;
        }
    }
};
