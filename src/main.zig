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
    _ = rg.GuiLabel(rl.Rectangle.init(x, y, 300, CHECKBOX_SIZE), @ptrCast(text));
}

fn checkbox(text: [:0]const u8, value: *bool, x: f32, y: f32, size: f32) void {
    const oldcolor = rg.GuiGetStyle(rg.GuiControl.DEFAULT.toValue(), rg.GuiControlProperty.TEXT_COLOR_NORMAL.toValue());
    defer rg.GuiSetStyle(rg.GuiControl.DEFAULT.toValue(), rg.GuiControlProperty.TEXT_COLOR_NORMAL.toValue(), oldcolor);

    const light: u8 = if (value.*) 255 else 200;
    rg.GuiSetStyle(rg.GuiControl.DEFAULT.toValue(), rg.GuiControlProperty.TEXT_COLOR_NORMAL.toValue(), (rl.Color{ .r = light, .g = light, .b = light, .a = 255 }).toValue());
    _ = rg.GuiCheckBox(rl.Rectangle.init(x, y, size, size), @ptrCast(text), value);
}

const Die = struct {
    pos: rl.Vector2,
    // vel: rl.Vector2,
    rot: f32,
    rotvel: f32,
    value: f32,
    chosen: bool,
};

const State = struct {
    buf: [256]u8 = undefined,
    mouse_pos: rl.Vector2 = undefined,
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

    roll_state: enum { inactive, configuring, rolling, displaying } = .inactive,
    roll_expertise_active: c_int = 0,
    roll_expertise_focus: c_int = 0,
    roll_difficulty_active: c_int = 0,
    roll_difficulty_focus: c_int = 0,
    roll_advantages: f32 = 0,
    roll_disadvantages: f32 = 0,
    roll_advantage_bonus: f32 = 0,

    dice: std.BoundedArray(Die, 32) = std.BoundedArray(Die, 32).init(0) catch unreachable,
};

pub fn main() !void {
    character.init();
    var player = character.makeCharacter("Srekel", "Anders");
    var state = State{};

    rl.InitWindow(800, 1000, "Tides of Tabletop");
    rg.GuiLoadStyle("style_dark.rgs");
    rg.GuiEnableTooltip();
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    while (!rl.WindowShouldClose()) {
        state.mouse_pos = .{ .x = @floatFromInt(rl.GetMouseX()), .y = @floatFromInt(rl.GetMouseY()) };
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
        drawDice(&player, &state);
    }

    return;
}

fn drawCharacterSheet(player: *character.Character, state: *State) void {
    label("Name:", 20, 40, 255, 255, 0);
    _ = rg.GuiLabel(rl.Rectangle.init(100, 40, 100, CHECKBOX_SIZE), @ptrCast(player.name));

    _ = rg.GuiLabel(rl.Rectangle.init(20, 60, 100, CHECKBOX_SIZE), "Player:");
    _ = rg.GuiLabel(rl.Rectangle.init(100, 60, 100, CHECKBOX_SIZE), @ptrCast(player.player));

    const str = std.fmt.bufPrintZ(&state.buf, "{d}", .{player.xp}) catch unreachable;
    _ = rg.GuiLabel(rl.Rectangle.init(20, 80, 100, CHECKBOX_SIZE), "XP:");
    _ = rg.GuiLabel(rl.Rectangle.init(100, 80, 100, CHECKBOX_SIZE), @ptrCast(str));

    if (rg.GuiButton(rl.Rectangle.init(150, 80, 20, 20), rg.GuiIconText(.ICON_ARROW_UP_FILL, "")) != 0) {
        player.xp += if (rl.IsKeyDown(@intFromEnum(rl.KeyboardKey.KEY_LEFT_CONTROL))) 10 else 1;
    }

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

fn drawDice(player: *character.Character, state: *State) void {
    rg.GuiDisableTooltip();

    var rnd = std.Random.Pcg.init(@intFromFloat(rl.GetTime()));
    if (state.roll_state == .inactive) {
        if (rg.GuiButton(rl.Rectangle.init(700, 100, 100, 50), "Roll...") != 0) {
            state.roll_difficulty_active = 3;
            state.roll_advantage_bonus = 0;
            state.roll_state = .configuring;
            return;
        }
    }

    const at_advantage = state.roll_advantages > state.roll_disadvantages;
    if (state.roll_state == .configuring) {
        if (rg.GuiButton(rl.Rectangle.init(700, 100, 100, 50), "Roll!") != 0) {
            state.dice.resize(0) catch unreachable;
            var extra_dice: u32 = @intFromFloat(@abs(state.roll_advantages - state.roll_disadvantages));
            if (extra_dice > 3) {
                state.roll_advantage_bonus = @floatFromInt((extra_dice - 3) * 3);
                if (!at_advantage) {
                    state.roll_advantage_bonus *= -1;
                }
                extra_dice = @min(extra_dice, 3);
            }
            for (0..3 + extra_dice) |i_d| {
                var die = state.dice.addOneAssumeCapacity();
                die.chosen = false;
                die.pos.x = 600 + @as(f32, @floatFromInt(i_d % 3)) * 80;
                die.pos.y = 350 + @as(f32, @floatFromInt(i_d / 3)) * 80;
                die.rot = rnd.random().float(f32) * 400;
                die.rotvel = 200 + rnd.random().float(f32) * 1800;
            }

            state.roll_state = .rolling;
            return;
        }

        _ = rg.GuiListViewEx(rl.Rectangle.init(600, 150, 200, 350), @ptrCast(character.ui_expertises), @intCast(character.all_expertises.len), &state.player_scrollindex, &state.roll_expertise_active, &state.roll_expertise_focus);
        _ = rg.GuiListViewEx(rl.Rectangle.init(600, 500, 200, 200), @ptrCast(character.ui_difficulties), @intCast(character.all_difficulties.len), &state.player_scrollindex, &state.roll_difficulty_active, &state.roll_difficulty_focus);
        state.roll_expertise_active = @max(0, state.roll_expertise_active);
        state.roll_difficulty_active = @max(0, state.roll_difficulty_active);

        var str = std.fmt.bufPrintZ(&state.buf, "{d}", .{state.roll_advantages}) catch unreachable;
        _ = rg.GuiSlider(rl.Rectangle.init(600, 700, 170, 30), "Advantages", str, &state.roll_advantages, 0, 10);
        str = std.fmt.bufPrintZ(&state.buf, "{d}", .{state.roll_disadvantages}) catch unreachable;
        _ = rg.GuiSlider(rl.Rectangle.init(600, 730, 170, 30), "Disadvantages.", str, &state.roll_disadvantages, 0, 10);
        state.roll_advantages = @round(state.roll_advantages);
        state.roll_disadvantages = @round(state.roll_disadvantages);
    }

    if (state.roll_state == .rolling) {
        const dt = @min(0.1, rl.GetFrameTime());
        for (state.dice.slice()) |*die| {
            die.rotvel *= 0.98;
            die.value = @ceil(die.rot / 36);
            if (@abs(die.rotvel) < 100) {
                die.rotvel = 0;
                die.rot = 36 * die.value;
            }

            die.rot += die.rotvel * dt;
            if (die.rot > 360) {
                die.rot -= 360;
            }
        }

        const default_value: f32 = if (at_advantage) 0 else 100;
        var results = [_]f32{default_value} ** 20;
        for (state.dice.slice(), 0..) |*die, i| {
            if (@abs(die.rotvel) != 0) {
                break;
            }
            results[i] = die.value;
        } else {
            if (at_advantage) {
                std.mem.sort(f32, &results, {}, std.sort.desc(f32));
            } else {
                std.mem.sort(f32, &results, {}, std.sort.asc(f32));
            }

            for (results[0..3]) |choice| {
                for (state.dice.slice()) |*die| {
                    if (!die.chosen and die.value == choice) {
                        die.chosen = true;
                        break;
                    }
                }
            }

            state.roll_state = .displaying;
        }
    }

    if (state.roll_state == .rolling or state.roll_state == .displaying) {
        if (rg.GuiButton(rl.Rectangle.init(700, 100, 100, 50), "Done") != 0) {
            state.roll_state = .inactive;
        }

        label("Expertise:", 600, 150, 255, 255, 0);
        _ = rg.GuiLabel(rl.Rectangle.init(700, 150, 100, CHECKBOX_SIZE), @ptrCast(character.all_expertises[@intCast(state.roll_expertise_active)]));

        label("Difficulty:", 600, 180, 255, 255, 0);
        _ = rg.GuiLabel(rl.Rectangle.init(700, 180, 100, CHECKBOX_SIZE), @ptrCast(character.ui_difficulties[@intCast(state.roll_difficulty_active)]));

        const target_number = character.target_numbers[@intCast(state.roll_difficulty_active)];
        var str = std.fmt.bufPrintZ(&state.buf, "{d}", .{target_number}) catch unreachable;
        label("Target number:", 600, 210, 255, 255, 0);
        _ = rg.GuiLabel(rl.Rectangle.init(700, 210, 100, CHECKBOX_SIZE), str);

        if (at_advantage) {
            label("Rolling with advantage!", 600, 240, 255, 0, 255);
        } else if (state.roll_advantages < state.roll_disadvantages) {
            label("Rolling with disadvantage!", 600, 240, 255, 0, 0);
        }
        const color_rolling = rl.Color.init(0, 0, 255, 255);
        const color_still = rl.Color.init(255, 0, 255, 255);
        const color_chosen = rl.Color.init(255, 255, 255, 255);
        for (state.dice.slice()) |*die| {
            const color = if (die.chosen) color_chosen else if (die.rotvel == 0) color_still else color_rolling;
            const radius: f32 = if (die.chosen) 40 else 30;
            rl.DrawPolyLines(die.pos, 10, radius, die.rot, color);

            str = std.fmt.bufPrintZ(&state.buf, "{d}", .{die.value}) catch unreachable;

            label(str, die.pos.x, die.pos.y - 10, 255, 0, 255);
        }

        var dice_sum: f32 = 0;
        for (state.dice.slice()) |*die| {
            if (die.chosen) {
                dice_sum += die.value;
            }
        }

        const color_success = rl.Color.init(150, 150, 255, 255);
        const color_fail = rl.Color.init(255, 0, 0, 255);
        const color_value = rl.Color.init(255, 255, 200, 255);

        label("Dice:", 600, 500, 255, 255, 0);
        str = std.fmt.bufPrintZ(&state.buf, "{d}", .{dice_sum}) catch unreachable;
        rl.DrawText(str, 750, 500, 20, color_value);
        // _ = rg.GuiLabel(rl.Rectangle.init(750, 600, 100, CHECKBOX_SIZE), str);

        label("Converted advantage:", 600, 530, 255, 255, 0);
        str = std.fmt.bufPrintZ(&state.buf, "{d}", .{state.roll_advantage_bonus}) catch unreachable;
        rl.DrawText(str, 750, 530, 20, color_value);
        // _ = rg.GuiLabel(rl.Rectangle.init(750, 630, 100, CHECKBOX_SIZE), str);

        label("Expertise points:", 600, 560, 255, 255, 0);
        const expertise = player.getExpertise(character.all_expertises[@intCast(state.roll_expertise_active)]);
        str = std.fmt.bufPrintZ(&state.buf, "{d}", .{expertise.points}) catch unreachable;
        rl.DrawText(str, 750, 560, 20, color_value);
        // _ = rg.GuiLabel(rl.Rectangle.init(750, 560, 100, CHECKBOX_SIZE), str);

        if (state.roll_state == .displaying) {
            const sum: f32 = dice_sum + state.roll_advantage_bonus + @as(f32, @floatFromInt(expertise.points));

            str = std.fmt.bufPrintZ(&state.buf, "{d} VS {d}", .{ sum, target_number }) catch unreachable;
            rl.DrawText(str, 630, 600, 30, if (sum >= target_number) color_success else color_fail);

            var y: c_int = 600;
            var bonus: f32 = 1;
            var next_bonus: f32 = 1;
            while (sum >= target_number + next_bonus) {
                y += 30;
                str = std.fmt.bufPrintZ(&state.buf, "Bonus: {d}", .{target_number + next_bonus}) catch unreachable;
                rl.DrawText(str, 630, y, 30, if (sum >= target_number) color_success else color_fail);
                bonus += 1;
                next_bonus += bonus;
            }
        }
    }
}
