// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg");
const guile = gzzg.guile;

const gexpect            = @import("tests.zig").gexpect;
const expect             = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqual        = std.testing.expectEqual;

const Char    = gzzg.Character;
const Integer = gzzg.Integer;
const String  = gzzg.String;

test "guile string from/to narrow" {
    gzzg.initThreadForGuile();
    var buffer: [220]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    const str =
        \\You walk past the café, but you don't eat
        \\When you've lived too long
    ;

    const gstr = String.fromUTF8(str);
    const out = try gstr.toUTF8(fba.allocator());

    try expectEqualStrings(str, out);

    const str2 =
        \\There is something delicious about writing the first words
        \\ of a story. You never quite know where they'll take you.
        \\ ~ Beatrix Potter
    ;

    const gstr2 = String.fromUTF8(str2);
    const out2 = try gstr2.toUTF8(fba.allocator());

    try expectEqualStrings(str2, out2);

    var fbs = std.io.fixedBufferStream(&buffer);
    try std.fmt.format(fbs.writer(), "{}", .{gstr});
    try expectEqualStrings(str, fbs.getWritten());

    fbs.reset();
    
    try std.fmt.format(fbs.writer(), "{}", .{gstr2});
    try expectEqualStrings(str2, fbs.getWritten());
}

test "guile string from/to wide" {
    gzzg.initThreadForGuile();
    var buffer: [300]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    const mahjong_tiles = "🀣🀙";
    const chess_symbols = "🨄🨃🨀🨁🨅🨅🨅";
    const alchemical_symbols = "🜧🜓🜝";

    const egyptian_hieroglyphs = "𓀷𓀧𓀎𓁟";
    const cuneiform = "𒀕𒁖𒁲𒐈𒐨𒑔";
    const grantha = "𑌗𑌅𑌞𑌰";
    const old_hungarian = "𐲤𐲬𐲌𐲁";
    const gothic = "𐌶𐌳𐌽𐍂𐍊";
    const vai = "ꕇꔯꔐꔀꔋꕲ";
    const hiragana = "どゅゲノダ";
    const braille_patterns = "⡆⡲⢜⠯⠁";
    const runic = "ᚻᛘᛡᛯᚿᚡᚭ";
    const tibetan = "༆༲ཧཏ༱ཐ";
    const arabic = "ظؤؿـق";
    const hebrew = "הףמא";
    const latin = "ĘæïÐŒ56sgSGbP";
    const cjk = "⺥⻝⻳⻰⼆⼏";

    const currency_symbols = "€₹₤¥";

    const str =
        mahjong_tiles ++
        chess_symbols ++
        alchemical_symbols ++
        egyptian_hieroglyphs ++
        cuneiform ++
        grantha ++
        old_hungarian ++
        gothic ++
        vai ++
        hiragana ++
        braille_patterns ++
        runic ++
        tibetan ++
        arabic ++
        hebrew ++
        latin ++
        cjk ++
        currency_symbols;

    const gstr = String.fromUTF8(str); // This will create a wide string

    const out = try gstr.toUTF8(fba.allocator());
    try expectEqualStrings(str, out);

    var fbs = std.io.fixedBufferStream(&buffer);
    try std.fmt.format(fbs.writer(), "{}", .{gstr});
    
    try expectEqualStrings(str, fbs.getWritten());
}

test "guile string ref" {
    gzzg.initThreadForGuile();

    const str  = "Hello World!";
    const gstr = String.fromUTF8CStr(str);

    try expect(str.len == gstr.lenZ());
    try gexpect(Integer.from(str.len).equal(gstr.len()));

    try gexpect(gstr.refZ( 0).equal(Char.fromZ('H')));
    try gexpect(gstr.refZ( 1).equal(Char.fromZ('e')));
    try gexpect(gstr.refZ( 2).equal(Char.fromZ('l')));
    try gexpect(gstr.refZ( 3).equal(Char.fromZ('l')));
    try gexpect(gstr.refZ( 4).equal(Char.fromZ('o')));
    try gexpect(gstr.refZ( 5).equal(Char.fromZ(' ')));
    try gexpect(gstr.refZ( 6).equal(Char.fromZ('W')));
    try gexpect(gstr.refZ( 7).equal(Char.fromZ('o')));
    try gexpect(gstr.refZ( 8).equal(Char.fromZ('r')));
    try gexpect(gstr.refZ( 9).equal(Char.fromZ('l')));
    try gexpect(gstr.refZ(10).equal(Char.fromZ('d')));
    try gexpect(gstr.refZ(11).equal(Char.fromZ('!')));

    try gexpect(gstr.ref(Integer.from(4)).equal(Char.fromZ('o')));
    try gexpect(gstr.ref(Integer.from(5)).equal(Char.fromZ(' ')));
    try gexpect(gstr.ref(Integer.from(6)).equal(Char.fromZ('W')));
}

test "guile string iter" {
    gzzg.initThreadForGuile();

    const str = "Then we were Ziggy's band";
    const gstr = String.fromUTF8CStr(str);

    var itr = gstr.iterator();

    var idx: usize = 0;
    while (itr.next()) |c| : (idx += 1) {
        try expect((try c.toZ()).getOne() == str[idx]);
    }
}
