const std = @import("std");

const rlzb = @import("rlzb");
const rl = rlzb.raylib;
const rg = rlzb.raygui;

const character = @import("character.zig");

const CHECKBOX_SIZE = 16;

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

const State = struct {
    buf: [256]u8 = undefined,
    show_all_attributes: bool = true,

    expertise_panel_bounds: rg.Rectangle = rg.Rectangle{ .x = 20, .y = 120, .width = 500, .height = 800 },
    expertise_panel_content: rg.Rectangle = rg.Rectangle{ .x = 0, .y = 0, .width = 480, .height = 1000 },
    expertise_panel_view: rg.Rectangle = rg.Rectangle{ .x = 0, .y = 0, .width = 500, .height = 1000 },
    expertise_panel_scroll: rg.Vector2 = rg.Vector2{ .x = 0, .y = 10 },

    player_buf: [256 * 1024]u8 = undefined,
    player_list_visible: bool = false,
    player_scrollindex: c_int = 0,
    player_active: c_int = 0,
    player_focus: c_int = 0,
    player_files: rl.FilePathList = undefined,
};

pub fn main() !void {
    var player = character.makeCharacter("Srekel", "Anders");
    var state = State{};

    rl.InitWindow(800, 1000, "Tides of Tabletop");
    rg.GuiLoadStyle("external/raygui/styles/dark/style_dark.rgs");
    rg.GuiEnableTooltip();
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

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
            state.player_list_visible = !state.player_list_visible;
            if (state.player_list_visible) {
                state.player_files = rl.LoadDirectoryFilesEx(".", ".json", false);
                // for (0..files.count) |i_f| {
                //     const path = files.paths[i_f];
                //     _ = path; // autofix
                // }
            }
        }

        if (state.player_list_visible) {
            _ = rg.GuiListViewEx(rl.Rectangle.init(100, 40, 400, 200), state.player_files.paths, @intCast(state.player_files.count), &state.player_scrollindex, &state.player_active, &state.player_focus);

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
                state.player_list_visible = false;
            }

            if (state.player_active >= 0 and rg.GuiButton(rl.Rectangle.init(100, 240, 70, 30), rg.GuiIconText(.ICON_FILE_OPEN, "Load")) != 0) {
                // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
                var fba = std.heap.FixedBufferAllocator.init(&state.player_buf);
                const allocator = fba.allocator();
                const file_path = state.player_files.paths[@intCast(state.player_active)];
                const data = try std.fs.cwd().readFileAlloc(allocator, file_path[0..std.mem.len(file_path)], 256 * 1024);
                // defer allocator.free(data);
                const parsed = try std.json.parseFromSlice(character.Character, allocator, data, .{ .allocate = .alloc_always });
                defer parsed.deinit();
                player = parsed.value;
                state.player_list_visible = false;
            }
        }

        // if (rl.CheckCollisionPointRec(mouse_pos, rl.Rectangle.init(20, 20, 100, 20)) or
        //     (state.player_list_visible and rl.CheckCollisionPointRec(mouse_pos, rl.Rectangle.init(50, 20, 200, 200))))
        // {
        //     state.player_list_visible = true;
        //     _ = rg.GuiListViewEx(rl.Rectangle.init(100, 40, 200, 200), &tabs, 2, &player_scrollindex, &player_active, &player_focus);
        // } else {
        //     state.player_list_visible = false;
        // }

        if (state.player_list_visible) {
            continue;
        }

        drawCharacterSheet(&player, &state);

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

fn drawCharacterSheet(player: *character.Character, state: *State) void {
    label("Name:", 20, 40, 255, 255, 0);
    _ = rg.GuiLabel(rl.Rectangle.init(100, 40, 100, CHECKBOX_SIZE), @ptrCast(player.name));

    _ = rg.GuiLabel(rl.Rectangle.init(20, 60, 100, CHECKBOX_SIZE), "Player:");
    _ = rg.GuiLabel(rl.Rectangle.init(100, 70, 100, CHECKBOX_SIZE), @ptrCast(player.player));

    const str = std.fmt.bufPrintZ(&state.buf, "{d}", .{player.xp}) catch unreachable;
    _ = rg.GuiLabel(rl.Rectangle.init(20, 80, 100, CHECKBOX_SIZE), "XP:");
    _ = rg.GuiLabel(rl.Rectangle.init(100, 80, 100, CHECKBOX_SIZE), @ptrCast(str));

    label("Expertises:", 20, 100, 255, 0, 255);
    _ = rg.GuiCheckBox(rl.Rectangle.init(350, 100, 20, CHECKBOX_SIZE), "Show all attributes", &state.show_all_attributes);

    _ = rg.GuiScrollPanel(state.expertise_panel_bounds, null, state.expertise_panel_content, &state.expertise_panel_scroll, &state.expertise_panel_view);
    rl.BeginScissorMode(@intFromFloat(state.expertise_panel_view.x), @intFromFloat(state.expertise_panel_view.y), @intFromFloat(state.expertise_panel_view.width), @intFromFloat(state.expertise_panel_view.height));

    var x: f32 = state.expertise_panel_bounds.x + state.expertise_panel_scroll.x;
    var y: f32 = state.expertise_panel_bounds.y + state.expertise_panel_scroll.y;
    for (player.expertises.slice(), 0..) |*expertise, i_e| {
        if (i_e == player.expertises.len / 2) {
            state.expertise_panel_content.height = 50 + y - state.expertise_panel_bounds.y - state.expertise_panel_scroll.y;
            x = state.expertise_panel_bounds.x + state.expertise_panel_scroll.x + 300;
            y = state.expertise_panel_bounds.y + state.expertise_panel_scroll.y;
        }
        label(expertise.name, x, y, 255, 255, 255);

        if (expertise.level != .Master or expertise.points != 4) {
            rg.GuiSetTooltip("Upgrade your expertise.");
            if (rg.GuiButton(
                rl.Rectangle.init(x + @as(f32, @floatFromInt(rl.MeasureText(@ptrCast(expertise.name), 16))), y, 20, 20),
                rg.GuiIconText(.ICON_ARROW_UP_FILL, ""),
            ) != 0) {
                if (expertise.points == 4) {
                    if (expertise.canUpgrade() and expertise.costForUpgrade() <= player.xp) {
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
            if (!state.show_all_attributes and !attribute.picked) {
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
    state.expertise_panel_content.height = @max(state.expertise_panel_content.height, y - state.expertise_panel_bounds.y - state.expertise_panel_scroll.y);

    rl.EndScissorMode();
}
