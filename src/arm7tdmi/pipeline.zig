pub const PipelineOpcode = union {
    arm: u32,
    thumb: u16,
};

pub const Pipeline = struct {
    pub fn tick(self: *Pipeline) void {
        _ = self;
    }
};
