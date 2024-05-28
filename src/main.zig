const std = @import("std");

const rlzb = @import("rlzb");
const rl = rlzb.raylib;
const rg = rlzb.raygui;

const CHECKBOX_SIZE = 16;

const Attribute = struct {
    name: [:0]const u8 = "",
    picked: bool = false,
};

const ExpertiseLevel = enum { Inexperienced, Beginner, Novice, Practitioner, Expert, Master };

const Expertise = struct {
    name: [:0]const u8 = "",
    level: ExpertiseLevel = .Inexperienced,
    points: u8 = 0,
    attributes: std.BoundedArray(Attribute, 16),

    fn costForPoint(self: Expertise) u32 {
        return 5 + @as(u32, @intFromEnum(self.level)) * 1;
    }
    fn costForUpgrade(self: Expertise) u32 {
        return (@as(u32, @intFromEnum(self.level)) + 1) * 3;
    }
    fn costForAttribute(self: Expertise) u32 {
        var cost: u32 = 5;
        for (self.attributes.buffer) |attribute| {
            if (attribute.picked) {
                cost += 5;
            }
        }
        return cost;
    }
};

const Character = struct {
    name: [:0]const u8,
    player: [:0]const u8,
    xp: u32 = 500,
    expertises: std.BoundedArray(Expertise, 16),
};

fn label(text: [:0]const u8, x: f32, y: f32, r: u8, g: u8, b: u8) void {
    const oldcolor = rg.GuiGetStyle(rg.GuiControl.DEFAULT.toValue(), rg.GuiControlProperty.TEXT_COLOR_NORMAL.toValue());
    defer rg.GuiSetStyle(rg.GuiControl.DEFAULT.toValue(), rg.GuiControlProperty.TEXT_COLOR_NORMAL.toValue(), oldcolor);

    rg.GuiSetStyle(rg.GuiControl.DEFAULT.toValue(), rg.GuiControlProperty.TEXT_COLOR_NORMAL.toValue(), (rl.Color{ .r = r, .g = g, .b = b, .a = 255 }).toValue());
    _ = rg.GuiLabel(rl.Rectangle.init(x, y, 100, CHECKBOX_SIZE), @ptrCast(text));
}

fn checkbox(text: [:0]const u8, value: *bool, x: f32, y: f32, size: f32) void {
    const oldcolor = rg.GuiGetStyle(rg.GuiControl.DEFAULT.toValue(), rg.GuiControlProperty.TEXT_COLOR_NORMAL.toValue());
    defer rg.GuiSetStyle(rg.GuiControl.DEFAULT.toValue(), rg.GuiControlProperty.TEXT_COLOR_NORMAL.toValue(), oldcolor);

    const light: u8 = if (value.*) 255 else 200;
    rg.GuiSetStyle(rg.GuiControl.DEFAULT.toValue(), rg.GuiControlProperty.TEXT_COLOR_NORMAL.toValue(), (rl.Color{ .r = light, .g = light, .b = light, .a = 255 }).toValue());
    _ = rg.GuiCheckBox(rl.Rectangle.init(x, y, size, size), @ptrCast(text), value);
}

pub fn main() !void {
    const exp_movement: Expertise = .{
        .name = "Movement",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Acrobatic" },
            .{ .name = "Agile" },
            .{ .name = "Aquatic" },
            .{ .name = "Balanced" },
            .{ .name = "Dextrous" },
            .{ .name = "Fast" },
            .{ .name = "Mounted" },
            .{ .name = "Nimble" },
            .{ .name = "Stealthy" },
        }) catch unreachable,
    };
    const exp_physique: Expertise = .{
        .name = "Physique",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Athletic" },
            .{ .name = "Healthy" },
            .{ .name = "Imposing" },
            .{ .name = "Inconspicuous" },
            .{ .name = "Resilient" },
            .{ .name = "Slender" },
            .{ .name = "Strong" },
            .{ .name = "Tough" },
        }) catch unreachable,
    };
    const exp_communication: Expertise = .{
        .name = "Communication",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Charming" },
            .{ .name = "Deceitful" },
            .{ .name = "Eloquent" },
            .{ .name = "Emphatic" },
            .{ .name = "Haggley" },
            .{ .name = "Intimidating" },
            .{ .name = "Pushy" },
            .{ .name = "Respective" },
        }) catch unreachable,
    };
    const exp_melee_combat: Expertise = .{
        .name = "Melee Combat",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Anatomical" },
            .{ .name = "Brutal" },
            .{ .name = "Defensive" },
            .{ .name = "Dirty" },
            .{ .name = "Evasive" },
            .{ .name = "Fierce" },
            .{ .name = "Powerful" },
            .{ .name = "Precise" },
            .{ .name = "Stealthy" },
            .{ .name = "Swift" },
        }) catch unreachable,
    };
    const exp_ranged_combat: Expertise = .{
        .name = "Ranged Combat",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Anatomical" },
            .{ .name = "Accurate" },
            .{ .name = "Adaptive" },
            .{ .name = "Bursty" },
            .{ .name = "Clever" },
            .{ .name = "Long-range" },
            .{ .name = "Powerful" },
            .{ .name = "Precise" },
            .{ .name = "Stationary" },
            .{ .name = "Stealthy" },
        }) catch unreachable,
    };
    const exp_exploration: Expertise = .{
        .name = "Exploration",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Cartographic" },
            .{ .name = "Cautious" },
            .{ .name = "Curious" },
            .{ .name = "Fast" },
            .{ .name = "Perceptive" },
            .{ .name = "Pioneer" },
            .{ .name = "Resilient" },
            .{ .name = "Survivalist" },
            .{ .name = "Vigilant" },
        }) catch unreachable,
    };
    const exp_education: Expertise = .{
        .name = "Education",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Academic" },
            .{ .name = "Aristocratic" },
            .{ .name = "Archaeological" },
            .{ .name = "Language" },
            .{ .name = "Mercantile" },
            .{ .name = "Military" },
            .{ .name = "Streetwise" },
            .{ .name = "Worldly" },
            .{ .name = "Zoological" },
        }) catch unreachable,
    };
    const exp_healing: Expertise = .{
        .name = "Healing",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Anatomical" },
            .{ .name = "Compassionate" },
            .{ .name = "Diagnostic" },
            .{ .name = "Fast" },
            .{ .name = "Herbal" },
            .{ .name = "Meticulous" },
            .{ .name = "Perceptive" },
            .{ .name = "Surgical" },
            .{ .name = "Unflappable" },
            .{ .name = "Zoological" },
        }) catch unreachable,
    };
    const exp_investigation: Expertise = .{
        .name = "Investigation",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Analytical" },
            .{ .name = "Discreet" },
            .{ .name = "Deductive" },
            .{ .name = "Inconspicuous" },
            .{ .name = "Intuitive" },
            .{ .name = "Inquisitive" },
            .{ .name = "Perceptive" },
            .{ .name = "Shady" },
            .{ .name = "Stealthy" },
        }) catch unreachable,
    };
    const exp_crafting: Expertise = .{
        .name = "Crafting",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Alchemical" },
            .{ .name = "Architectural" },
            .{ .name = "Artisanal" },
            .{ .name = "Gastronomical" },
            .{ .name = "Herbal" },
            .{ .name = "Mechanical" },
            .{ .name = "Medical" },
        }) catch unreachable,
    };
    const exp_thievery: Expertise = .{
        .name = "Thievery",
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Appreciative" },
            .{ .name = "Inconspicuous" },
            .{ .name = "Cheaty" },
            .{ .name = "Fast" },
            .{ .name = "Handy" },
            .{ .name = "Precise" },
            .{ .name = "Silent" },
            .{ .name = "Traceless" },
            .{ .name = "Tricky" },
            .{ .name = "Vigilant" },
        }) catch unreachable,
    };
    const expertises = [_]Expertise{
        exp_movement,
        exp_physique,
        exp_communication,
        exp_melee_combat,
        exp_ranged_combat,
        exp_exploration,
        exp_education,
        exp_investigation,
        exp_thievery,
        exp_healing,
        exp_crafting,
    };
    var player = Character{
        .name = "Srekel",
        .player = "Anders",
        .expertises = std.BoundedArray(Expertise, 16).fromSlice(&expertises) catch unreachable,
    };

    rl.InitWindow(800, 1000, "Tides of Tabletop");
    rg.GuiLoadStyle("external/raygui/styles/dark/style_dark.rgs");
    rg.GuiEnableTooltip();
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    var buf: [256]u8 = undefined;
    var show_all_attributes = true;
    const expertise_panel_bounds = rg.Rectangle{ .x = 20, .y = 120, .width = 500, .height = 800 };
    var expertise_panel_content = rg.Rectangle{ .x = 0, .y = 0, .width = 480, .height = 1000 };
    var expertise_panel_view = rg.Rectangle{ .x = 0, .y = 0, .width = 500, .height = 1000 };
    var expertise_panel_scroll = rg.Vector2{ .x = 0, .y = 10 };

    var player_buf: [256 * 1024]u8 = undefined;
    var player_list_visible = false;
    var player_scrollindex: c_int = 0;
    var player_active: c_int = 0;
    var player_focus: c_int = 0;
    var player_files: rl.FilePathList = undefined;

    while (!rl.WindowShouldClose()) {
        const mouse_pos: rl.Vector2 = .{ .x = @floatFromInt(rl.GetMouseX()), .y = @floatFromInt(rl.GetMouseY()) };
        _ = mouse_pos; // autofix
        rl.BeginDrawing();
        defer rl.EndDrawing();
        const style = rg.GuiGetStyle(
            rg.GuiControl.DEFAULT.toValue(),
            rg.GuiDefaultProperty.BACKGROUND_COLOR.toValue(),
        );
        rl.ClearBackground(rl.GetColor(@bitCast(style)));

        // var active = [_]c_int{ 0, 0 };
        // _ = active; // autofix
        // var tabs = [_][*c]const u8{ "a", "b" };
        // _ = tabs; // autofix
        // _ = rg.GuiTabBar(rl.Rectangle.init(20, 0, 500, 20), &tabs, 2, &active);

        rg.GuiSetTooltip("Load and save characters.");
        if (rg.GuiButton(rl.Rectangle.init(5, 5, 32, 32), rg.GuiIconText(.ICON_FILE_OPEN, "")) != 0) {
            player_list_visible = !player_list_visible;
            if (player_list_visible) {
                player_files = rl.LoadDirectoryFilesEx(".", ".json", false);
                // for (0..files.count) |i_f| {
                //     const path = files.paths[i_f];
                //     _ = path; // autofix
                // }
            }
        }

        if (player_list_visible) {
            _ = rg.GuiListViewEx(rl.Rectangle.init(100, 40, 400, 200), player_files.paths, @intCast(player_files.count), &player_scrollindex, &player_active, &player_focus);

            if (rg.GuiButton(rl.Rectangle.init(20, 240, 70, 30), rg.GuiIconText(.ICON_FILE_SAVE, "Save")) != 0) {
                var jsonbuf: [100000]u8 = undefined;
                var fba = std.heap.FixedBufferAllocator.init(&jsonbuf);
                var string = std.ArrayList(u8).init(fba.allocator());
                try std.json.stringify(player, .{}, string.writer());

                const file = try std.fs.cwd().createFile(
                    "default.character.json",
                    .{ .read = true },
                );
                defer file.close();

                const bytes_written = try file.writeAll(string.items);
                _ = bytes_written; // autofix
                player_list_visible = false;
            }

            if (player_active >= 0 and rg.GuiButton(rl.Rectangle.init(100, 240, 70, 30), rg.GuiIconText(.ICON_FILE_OPEN, "Load")) != 0) {
                // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
                var fba = std.heap.FixedBufferAllocator.init(&player_buf);
                const allocator = fba.allocator();
                const file_path = player_files.paths[@intCast(player_active)];
                const data = try std.fs.cwd().readFileAlloc(allocator, file_path[0..std.mem.len(file_path)], 256 * 1024);
                // defer allocator.free(data);
                const parsed = try std.json.parseFromSlice(Character, allocator, data, .{ .allocate = .alloc_always });
                defer parsed.deinit();
                player = parsed.value;
                player_list_visible = false;
            }
        }

        // if (rl.CheckCollisionPointRec(mouse_pos, rl.Rectangle.init(20, 20, 100, 20)) or
        //     (player_list_visible and rl.CheckCollisionPointRec(mouse_pos, rl.Rectangle.init(50, 20, 200, 200))))
        // {
        //     player_list_visible = true;
        //     _ = rg.GuiListViewEx(rl.Rectangle.init(100, 40, 200, 200), &tabs, 2, &player_scrollindex, &player_active, &player_focus);
        // } else {
        //     player_list_visible = false;
        // }

        if (player_list_visible) {
            continue;
        }

        label("Name:", 20, 40, 255, 255, if (player_list_visible) 255 else 0);
        _ = rg.GuiLabel(rl.Rectangle.init(100, 40, 100, CHECKBOX_SIZE), @ptrCast(player.name));

        _ = rg.GuiLabel(rl.Rectangle.init(20, 60, 100, CHECKBOX_SIZE), "Player:");
        _ = rg.GuiLabel(rl.Rectangle.init(100, 70, 100, CHECKBOX_SIZE), @ptrCast(player.player));

        const str = try std.fmt.bufPrintZ(&buf, "{d}", .{player.xp});
        _ = rg.GuiLabel(rl.Rectangle.init(20, 80, 100, CHECKBOX_SIZE), "XP:");
        _ = rg.GuiLabel(rl.Rectangle.init(100, 80, 100, CHECKBOX_SIZE), @ptrCast(str));

        label("Expertises:", 20, 100, 255, 0, 255);
        _ = rg.GuiCheckBox(rl.Rectangle.init(350, 100, 20, CHECKBOX_SIZE), "Show all attributes", &show_all_attributes);

        _ = rg.GuiScrollPanel(expertise_panel_bounds, null, expertise_panel_content, &expertise_panel_scroll, &expertise_panel_view);
        rl.BeginScissorMode(@intFromFloat(expertise_panel_view.x), @intFromFloat(expertise_panel_view.y), @intFromFloat(expertise_panel_view.width), @intFromFloat(expertise_panel_view.height));

        var x: f32 = expertise_panel_bounds.x + expertise_panel_scroll.x;
        var y: f32 = expertise_panel_bounds.y + expertise_panel_scroll.y;
        for (player.expertises.slice(), 0..) |*expertise, i_e| {
            if (i_e == player.expertises.len / 2) {
                expertise_panel_content.height = 50 + y - expertise_panel_bounds.y - expertise_panel_scroll.y;
                x = expertise_panel_bounds.x + expertise_panel_scroll.x + 300;
                y = expertise_panel_bounds.y + expertise_panel_scroll.y;
            }
            label(expertise.name, x, y, 255, 255, 255);

            if (expertise.level != .Master or expertise.points != 4) {
                rg.GuiSetTooltip("Upgrade your expertise.");
                if (rg.GuiButton(
                    rl.Rectangle.init(x + @as(f32, @floatFromInt(rl.MeasureText(@ptrCast(expertise.name), 16))), y, 20, 20),
                    rg.GuiIconText(.ICON_ARROW_UP_FILL, ""),
                ) != 0) {
                    if (expertise.points == 4) {
                        if (expertise.costForUpgrade() <= player.xp) {
                            player.xp -= expertise.costForUpgrade();
                            expertise.level = @enumFromInt(@intFromEnum(expertise.level) + 1);
                            expertise.points = 0;
                        }
                    } else {
                        if (expertise.costForPoint() <= player.xp) {
                            player.xp -= expertise.costForPoint();
                            expertise.points += 1;
                        }
                    }
                }
            }

            y += 20;

            label(
                @tagName(expertise.level),
                x + 30,
                y,
                255,
                150,
                255,
            );

            rg.GuiLock();
            const CHECKBOX_SIZE_EXPERTISE_POINT = CHECKBOX_SIZE / 2;
            // var last_checked = true;
            for (0..4) |exp_point| {
                var checked = expertise.points > exp_point;
                // if (checked) {
                //     rg.GuiLock();
                // } else if (!last_checked) {
                //     rg.GuiLock();
                // }
                // const checked_prev = checked;

                checkbox(
                    "",
                    &checked,
                    x + 10 + @as(f32, @floatFromInt(CHECKBOX_SIZE_EXPERTISE_POINT * (exp_point % 2))),
                    y + @as(f32, @floatFromInt(CHECKBOX_SIZE_EXPERTISE_POINT * (exp_point / 2))),
                    CHECKBOX_SIZE_EXPERTISE_POINT,
                );
                // rg.GuiSetTooltip("");

                // if (!checked_prev and checked and expertise.costForPoint() <= player.xp) {
                //     player.xp -= expertise.costForPoint();
                //     expertise.points += 1;
                // }

                // last_checked = checked;
            }
            rg.GuiUnlock();

            for (expertise.attributes.slice(), 0..) |*attribute, i_a| {
                _ = i_a; // autofix
                if (!show_all_attributes and !attribute.picked) {
                    continue;
                }
                y += @as(f32, @floatFromInt(20));
                var picked = attribute.picked;
                checkbox(attribute.name, &picked, x + 10, y, CHECKBOX_SIZE);
                if (picked and !attribute.picked and expertise.costForAttribute() < player.xp) {
                    player.xp -= expertise.costForAttribute();
                    attribute.picked = true;
                }
            }

            y += 30;
        }
        expertise_panel_content.height = @max(expertise_panel_content.height, y - expertise_panel_bounds.y - expertise_panel_scroll.y);

        rl.EndScissorMode();

        // if (rg.GuiButton(rl.Rectangle.init(24, 24, 120, 30), "#191#Show Message") > 0)
        //     showMessageBox = true;

        // if (showMessageBox) {
        //     const bounds = rl.Rectangle.init(85, 70, 250, 100);
        //     const result = rg.GuiMessageBox(bounds, "#191#Message Box", "Hi! This is a message!", "Nice;Cool");
        //     if (result >= 0) showMessageBox = false;
        // }

        // rl.EndDrawing();
    }

    return;
}
