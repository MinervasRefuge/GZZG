const refAllDecls = @import("std").testing.refAllDecls;

test {
    refAllDecls(@import("test_list.zig"));
    refAllDecls(@import("test_vector.zig"));
}
