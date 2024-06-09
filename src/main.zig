const std = @import("std");
const sin = std.math.sin;

const rlzb = @import("rlzb");
const rl = rlzb.raylib;
const rg = rlzb.raygui;

const character = @import("character.zig");

const experience_colors = [_]rl.Color{
    .{ .r = 180, .g = 150, .b = 150, .a = 255 },
    .{ .r = 200, .g = 140, .b = 100, .a = 255 },
    .{ .r = 220, .g = 180, .b = 60, .a = 255 },
    .{ .r = 50, .g = 200, .b = 0, .a = 255 },
    .{ .r = 50, .g = 255, .b = 100, .a = 255 },
    .{ .r = 50, .g = 230, .b = 255, .a = 255 },
};

const cc_beginner_skills = 4;
const cc_novice_skills = 2;
const cc_total_skills = cc_beginner_skills + cc_novice_skills;
const cc_talents = 2;
const cc_attributes = 2;

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
    anim_t: f64 = 0,
    buf: [256]u8 = undefined,
    buf2: [256]u8 = undefined,
    mouse_pos: rl.Vector2 = undefined,
    show_all_attributes: bool = true,
    text_focus: enum { none, char_name, player_name } = .none,

    creating_character: union(enum) {
        inactive,
        naming,
        pick_expertises: u8,
        pick_attributes: u8,
        pick_talents: u8,
    } = .inactive,
    cc_comparison: character.Character = undefined,

    expertise_panel_bounds: rg.Rectangle = rg.Rectangle{ .x = 20, .y = 120, .width = 520, .height = 800 },
    expertise_panel_content: rg.Rectangle = rg.Rectangle{ .x = 0, .y = 0, .width = 500, .height = 1000 },
    expertise_panel_view: rg.Rectangle = rg.Rectangle{ .x = 0, .y = 0, .width = 520, .height = 1000 },
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
    roll_difficulty_active: c_int = 3,
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

    rl.SetConfigFlags(rl.ConfigFlags.FLAG_WINDOW_RESIZABLE.toCInt());
    rl.InitWindow(800, 1100, "Tides of Tabletop");
    rg.GuiLoadStyle("style_dark.rgs");
    rg.GuiEnableTooltip();
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    while (!rl.WindowShouldClose()) {
        state.anim_t = rl.GetTime();
        state.mouse_pos = .{ .x = @floatFromInt(rl.GetMouseX()), .y = @floatFromInt(rl.GetMouseY()) };
        state.expertise_panel_bounds.height = @floatFromInt(rl.GetScreenHeight() - 150);
        rl.BeginDrawing();
        defer rl.EndDrawing();
        const style = rg.GuiGetStyle(
            rg.GuiControl.DEFAULT.toValue(),
            rg.GuiDefaultProperty.BACKGROUND_COLOR.toValue(),
        );
        rl.ClearBackground(rl.GetColor(@bitCast(style)));

        if (state.creating_character == .inactive) {
            rg.GuiSetTooltip("Create new character.");
            if (rg.GuiButton(rl.Rectangle.init(5, 5, 32, 32), rg.GuiIconText(.ICON_FILE_NEW, "")) != 0) {
                if (state.creating_character == .inactive) {
                    state.creating_character = .naming;
                    @memcpy(state.buf[0..player.name.slice().len], player.name.slice());
                    @memcpy(state.buf2[0..player.player.slice().len], player.player.slice());
                    state.buf[player.name.slice().len] = 0;
                    state.buf[player.player.slice().len] = 0;
                    state.show_all_attributes = false;
                } else {
                    state.creating_character = .inactive;
                }
            }
            rg.GuiSetTooltip("Load and save characters.");
            if (rg.GuiButton(rl.Rectangle.init(40, 5, 32, 32), rg.GuiIconText(.ICON_FILE_OPEN, "")) != 0) {
                state.player_list_visible = !state.player_list_visible;
                if (state.player_list_visible) {
                    state.player_files = rl.LoadDirectoryFilesEx(".", ".json", false);
                    // for (0..files.count) |i_f| {
                    //     const path = files.paths[i_f];
                    //     _ = path; // autofix
                    // }
                }
            }
        }

        const time: f64 = @floatFromInt((std.time.Instant.now() catch unreachable).timestamp);
        const cc_color = rl.Color.init(
            @intFromFloat(200 + sin(time * 0.000001) * 20),
            @intFromFloat(200 + sin(time * 0.000001) * 20),
            @intFromFloat(50 + sin(time * 0.000001) * 20),
            255,
        );
        switch (state.creating_character) {
            .inactive => {},
            .naming => {
                rl.DrawText("1/5 Name your character!", 150, 10, 30, cc_color);
            },
            .pick_expertises => {
                if (state.creating_character.pick_expertises < cc_novice_skills) {
                    rl.DrawText("2/5 Choose Novice expertises + attributes)", 30, 10, 30, cc_color);
                    rl.DrawLine(600, 50, 650, 140, cc_color);
                } else if (state.creating_character.pick_expertises < cc_total_skills) {
                    rl.DrawText("3/5 Choose Beginner expertises + attributes)", 30, 10, 30, cc_color);
                    rl.DrawLine(600, 50, 650, 140, cc_color);
                }
            },
            .pick_attributes => {
                rl.DrawText("4/5 Add two attributes!", 100, 10, 30, cc_color);
                rl.DrawLine(350, 50, 300, 140, cc_color);
            },
            .pick_talents => {
                rl.DrawText("5/5 Choose two talents!", 400, 10, 30, cc_color);
                rl.DrawLine(600, 50, 650, 140, cc_color);
            },
        }

        if (state.creating_character == .naming) {
            label("Character name:", 220, 220, 255, 255, 255);
            const name_choice = rg.GuiTextBox(rl.Rectangle.init(350, 215, 200, 30), &state.buf, 20, state.text_focus == .char_name);
            if (name_choice == 1) {
                state.text_focus = if (state.text_focus == .char_name) .none else .char_name;
            }
            label("Player name:", 220, 260, 255, 255, 255);
            const player_choice = rg.GuiTextBox(rl.Rectangle.init(350, 255, 200, 30), &state.buf2, 20, state.text_focus == .player_name);
            if (player_choice == 1) {
                state.text_focus = if (state.text_focus == .player_name) .none else .player_name;
            }

            if (rg.GuiButton(rl.Rectangle.init(550, 215, 100, 30), rg.GuiIconText(.ICON_HELP, "Random!")) != 0) {
                const names = [_][:0]const u8{
                    "Kaida",
                    "Renn",
                    "Lyra",
                    "Jax",
                    "Vesper",
                    "Caspian",
                    "Piper",
                    "Rowan",
                    "Luna",
                    "Cormac",
                    "Aria",
                    "Kieran",
                    "Zephyr",
                    "Lila",
                    "Thane",
                    "Niamh",
                    "Gideon",
                    "Celeste",
                    "Rowan",
                    "Kaia",
                };
                const name_index = rl.GetRandomValue(0, names.len - 1);
                const name = names[@intCast(name_index)];
                @memcpy(state.buf[0..name.len], name);
                state.buf[name.len] = 0;
            }

            if (state.buf[0] != 0 and state.buf2[0] != 0 and rg.GuiButton(rl.Rectangle.init(220, 300, 430, 50), rg.GuiIconText(.ICON_STAR, "Confirm!")) != 0) {
                state.creating_character = .{ .pick_expertises = 0 };
                const name_len: u7 = @intCast(std.mem.len(@as([*c]u8, @ptrCast(&state.buf))));
                const player_len: u7 = @intCast(std.mem.len(@as([*c]u8, @ptrCast(&state.buf2))));
                player = character.makeCharacter("", "");

                player.xp = 1000;
                player.name.appendSliceAssumeCapacity(state.buf[0..name_len]);
                player.name.appendAssumeCapacity(0);
                player.name.len -= 1;
                player.player.appendSliceAssumeCapacity(state.buf2[0..player_len]);
                player.player.appendAssumeCapacity(0);
                player.player.len -= 1;
                state.cc_comparison = player;
            }
            continue;
        }

        if (state.player_list_visible) {
            _ = rg.GuiListViewEx(rl.Rectangle.init(100, 40, 400, 200), state.player_files.paths, @intCast(state.player_files.count), &state.player_scrollindex, &state.player_active, &state.player_focus);

            if (rg.GuiButton(rl.Rectangle.init(20, 240, 70, 30), rg.GuiIconText(.ICON_FILE_SAVE, "Save")) != 0) {
                var jsonbuf: [100000]u8 = undefined;
                var fba = std.heap.FixedBufferAllocator.init(&jsonbuf);
                var string = std.ArrayList(u8).init(fba.allocator());
                try std.json.stringify(player, .{}, string.writer());

                const str = std.fmt.bufPrintZ(&state.buf, "{s}_{s}.json", .{ player.name.slice(), player.player.slice() }) catch unreachable;

                const file = try std.fs.cwd().createFile(
                    str,
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

        if (state.player_list_visible) {
            continue;
        }

        if (state.creating_character == .pick_expertises) {
            rg.GuiLock();
        }
        drawCharacterSheet(&player, &state);
        rg.GuiUnlock();

        if (state.creating_character == .inactive) {
            drawDice(&player, &state);
        } else if (state.creating_character != .inactive) {
            drawCharacterCreation(&player, &state);
        }
    }

    return;
}

fn drawCharacterSheet(player: *character.Character, state: *State) void {
    label("Name:", 20, 40, 255, 255, 0);
    _ = rg.GuiLabel(rl.Rectangle.init(100, 40, 100, CHECKBOX_SIZE), @ptrCast(player.name.slice()));

    _ = rg.GuiLabel(rl.Rectangle.init(20, 60, 100, CHECKBOX_SIZE), "Player:");
    _ = rg.GuiLabel(rl.Rectangle.init(100, 60, 100, CHECKBOX_SIZE), @ptrCast(player.player.slice()));

    if (state.creating_character == .inactive) {
        const str = std.fmt.bufPrintZ(&state.buf, "{d}", .{player.xp}) catch unreachable;
        _ = rg.GuiLabel(rl.Rectangle.init(20, 80, 100, CHECKBOX_SIZE), "XP:");
        _ = rg.GuiLabel(rl.Rectangle.init(100, 80, 100, CHECKBOX_SIZE), @ptrCast(str));

        if (rg.GuiButton(rl.Rectangle.init(150, 80, 20, 20), rg.GuiIconText(.ICON_ARROW_UP_FILL, "")) != 0) {
            player.xp += if (rl.IsKeyDown(@intFromEnum(rl.KeyboardKey.KEY_LEFT_CONTROL))) 10 else 1;
        }
    }

    label("Expertises:", 20, 100, 255, 0, 255);
    _ = rg.GuiCheckBox(rl.Rectangle.init(350, 100, 20, CHECKBOX_SIZE), "Show all attributes", &state.show_all_attributes);

    _ = rg.GuiScrollPanel(state.expertise_panel_bounds, null, state.expertise_panel_content, &state.expertise_panel_scroll, &state.expertise_panel_view);
    rl.BeginScissorMode(@intFromFloat(state.expertise_panel_view.x), @intFromFloat(state.expertise_panel_view.y), @intFromFloat(state.expertise_panel_view.width), @intFromFloat(state.expertise_panel_view.height));

    var x: f32 = state.expertise_panel_bounds.x + state.expertise_panel_scroll.x;
    var y: f32 = state.expertise_panel_bounds.y + state.expertise_panel_scroll.y + 5;
    for (player.expertises.slice(), 0..) |*expertise, i_e| {
        if (i_e == player.expertises.len / 2) {
            state.expertise_panel_content.height = 50 + y - state.expertise_panel_bounds.y - state.expertise_panel_scroll.y;
            x = state.expertise_panel_bounds.x + state.expertise_panel_scroll.x + 300;
            y = state.expertise_panel_bounds.y + state.expertise_panel_scroll.y + 5;
        }
        const exp_color = experience_colors[@intFromEnum(expertise.level)];
        rl.DrawText(expertise.name, @intFromFloat(x + 5), @intFromFloat(y), 20, exp_color);

        if (state.creating_character == .inactive and (expertise.level != .Master or expertise.points != 4)) {
            rg.GuiSetTooltip("Upgrade your expertise.");
            if (rg.GuiButton(
                rl.Rectangle.init(x + 160, y, 20, 20),
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

        if (expertise.has_talent) {
            rg.GuiSetTooltip("You are Talented in this expertise.");
            rg.GuiDrawIcon(.ICON_HEART, @intFromFloat(x + 180), @intFromFloat(y + 2), 1, rl.Color.init(0, 150, 0, 255));
        }

        y += 30;

        label(@tagName(expertise.level), x + 30, y, exp_color.r, exp_color.g, exp_color.b);

        rg.GuiLock();
        const CHECKBOX_SIZE_EXPERTISE_POINT = CHECKBOX_SIZE / 2;
        for (0..4) |exp_point| {
            var checked = expertise.points > exp_point;
            checkbox(
                "",
                &checked,
                x + 10 + @as(f32, @floatFromInt(CHECKBOX_SIZE_EXPERTISE_POINT * (exp_point % 2))),
                y + @as(f32, @floatFromInt(CHECKBOX_SIZE_EXPERTISE_POINT * (exp_point / 2))),
                CHECKBOX_SIZE_EXPERTISE_POINT,
            );
        }
        rg.GuiUnlock();
        const cc_expertise = player.getExpertise(character.all_expertises[@intCast(state.roll_expertise_active)]);
        for (expertise.attributes.slice()) |*attribute| {
            const show_from_cc = state.creating_character == .pick_expertises and cc_expertise == expertise and expertise.level == .Inexperienced;
            if (!show_from_cc and !state.show_all_attributes and !attribute.picked) {
                continue;
            }
            y += @as(f32, @floatFromInt(20));
            var picked = attribute.picked;
            if (state.creating_character == .pick_attributes and state.cc_comparison.getExpertise(expertise.name).getAttribute(attribute.name).picked) {
                rg.GuiDisable();
            }
            checkbox(attribute.name, &picked, x + 10, y, CHECKBOX_SIZE);

            if (state.creating_character == .pick_attributes and state.cc_comparison.getExpertise(expertise.name).getAttribute(attribute.name).picked) {
                rg.GuiEnable();
            }
            if (picked != attribute.picked) {
                if (state.creating_character == .inactive) {
                    if (picked and expertise.costForAttribute() < player.xp) {
                        player.xp -= expertise.costForAttribute();
                        attribute.picked = true;
                    }
                } else if (state.creating_character == .pick_expertises) {
                    attribute.picked = !attribute.picked;
                } else if (state.creating_character == .pick_attributes) {
                    attribute.picked = !attribute.picked;
                }
            }
        }

        y += 30;
    }
    state.expertise_panel_content.height = @max(state.expertise_panel_content.height, y - state.expertise_panel_bounds.y - state.expertise_panel_scroll.y);

    rl.EndScissorMode();
}

fn drawDice(player: *character.Character, state: *State) void {
    rg.GuiDisableTooltip();
    defer rg.GuiEnableTooltip();

    var rnd = std.Random.Pcg.init(@intFromFloat(rl.GetTime()));
    if (state.roll_state == .inactive) {
        if (rg.GuiButton(rl.Rectangle.init(700, 100, 100, 50), "Roll...") != 0) {
            state.roll_advantage_bonus = 0;
            state.roll_state = .configuring;
            return;
        }
    }

    const at_advantage = state.roll_advantages > state.roll_disadvantages;
    if (state.roll_state == .configuring) {
        if (rg.GuiButton(rl.Rectangle.init(600, 100, 200, 50), "Roll!") != 0) {
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

        _ = rg.GuiListViewEx(rl.Rectangle.init(600, 150, 200, 380), @ptrCast(character.ui_expertises), @intCast(character.all_expertises.len), &state.player_scrollindex, &state.roll_expertise_active, &state.roll_expertise_focus);
        _ = rg.GuiListViewEx(rl.Rectangle.init(600, 530, 200, 200), @ptrCast(character.ui_difficulties), @intCast(character.all_difficulties.len), &state.player_scrollindex, &state.roll_difficulty_active, &state.roll_difficulty_focus);
        state.roll_expertise_active = @max(0, state.roll_expertise_active);
        state.roll_difficulty_active = @max(0, state.roll_difficulty_active);

        var str = std.fmt.bufPrintZ(&state.buf, "{d}", .{state.roll_advantages}) catch unreachable;
        _ = rg.GuiSlider(rl.Rectangle.init(600, 730, 170, 30), "Advantages", str, &state.roll_advantages, 0, 10);
        str = std.fmt.bufPrintZ(&state.buf, "{d}", .{state.roll_disadvantages}) catch unreachable;
        _ = rg.GuiSlider(rl.Rectangle.init(600, 760, 170, 30), "Disadvantages.", str, &state.roll_disadvantages, 0, 10);
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

fn drawCharacterCreation(player: *character.Character, state: *State) void {
    if (state.creating_character == .pick_expertises) {
        var active = state.roll_expertise_active;
        _ = rg.GuiListViewEx(rl.Rectangle.init(600, 150, 200, 380), @ptrCast(character.ui_expertises), @intCast(character.all_expertises.len), &state.player_scrollindex, &active, &state.roll_expertise_focus);
        active = @max(0, active);

        const expertise_prev = player.getExpertise(character.all_expertises[@intCast(state.roll_expertise_active)]);
        if (active != state.roll_expertise_active and expertise_prev.level == .Inexperienced and expertise_prev.pickedAttributeCount() != 0) {
            active = state.roll_expertise_active;
        }
        state.roll_expertise_active = active;
        var expertise = player.getExpertise(character.all_expertises[@intCast(state.roll_expertise_active)]);
        const wanted_attribute_count: u32 = if (state.creating_character.pick_expertises < cc_novice_skills) 2 else 1;
        const attribute_count = expertise.pickedAttributeCount();
        const already_picked = expertise.level != .Inexperienced;
        const button_text = if (already_picked) "Already chosen!" else if (wanted_attribute_count != attribute_count) "Choose attributes" else "Confirm!";
        if (already_picked or wanted_attribute_count != attribute_count) {
            rg.GuiDisable();
        }
        if (rg.GuiButton(rl.Rectangle.init(600, 530, 200, 50), button_text) != 0) {
            if (state.creating_character.pick_expertises < cc_novice_skills) {
                if (expertise.pickedAttributeCount() == 2) {
                    expertise.level = .Novice;
                }
            } else if (state.creating_character.pick_expertises < cc_total_skills) {
                if (expertise.pickedAttributeCount() == 1) {
                    expertise.level = .Beginner;
                }
            } else {
                expertise.has_talent = true;
            }
            state.creating_character.pick_expertises += 1;
            if (state.creating_character.pick_expertises == cc_total_skills) {
                state.creating_character = .{ .pick_attributes = 0 };
                state.cc_comparison = player.*;
                state.show_all_attributes = true;
            }
            state.cc_comparison = player.*;
        }
        if (already_picked or wanted_attribute_count != attribute_count) {
            rg.GuiEnable();
        }
    } else if (state.creating_character == .pick_attributes) {
        var y: f32 = 150;
        var count: u32 = 0;
        for (player.expertises.slice()) |expertise| {
            for (expertise.attributes.slice()) |attribute| {
                const attribute_comp = state.cc_comparison.getExpertise(expertise.name).getAttribute(attribute.name);
                if (attribute.picked and !attribute_comp.picked) {
                    count += 1;
                    const str = std.fmt.bufPrintZ(&state.buf, "{s} / {s}", .{ expertise.name, attribute.name }) catch unreachable;
                    _ = rg.GuiLabel(rl.Rectangle.init(20, 80, 100, CHECKBOX_SIZE), "XP:");
                    _ = rg.GuiLabel(rl.Rectangle.init(100, 80, 100, CHECKBOX_SIZE), @ptrCast(str));

                    label("Attribute:", 600, y, 255, 255, 0);
                    label(@ptrCast(str), 630, y + 20, if (count > cc_attributes) 255 else 200, if (count <= cc_attributes) 255 else 200, 200);
                    y += 50;
                }
            }
        }
        if (count != cc_attributes) {
            rg.GuiDisable();
        }
        if (rg.GuiButton(rl.Rectangle.init(600, 500, 200, 50), "Confirm!") != 0) {
            state.creating_character = .{ .pick_talents = 0 };
            state.show_all_attributes = false;
        }
        if (count != cc_attributes) {
            rg.GuiEnable();
        }
    } else if (state.creating_character == .pick_talents) {
        _ = rg.GuiListViewEx(rl.Rectangle.init(600, 150, 200, 380), @ptrCast(character.ui_expertises), @intCast(character.all_expertises.len), &state.player_scrollindex, &state.roll_expertise_active, &state.roll_expertise_focus);
        state.roll_expertise_active = @max(0, state.roll_expertise_active);
        var expertise = player.getExpertise(character.all_expertises[@intCast(state.roll_expertise_active)]);
        const can_pick_talent = !expertise.has_talent;
        const button_text = if (expertise.has_talent) "Already talented" else "Confirm!";
        if (!can_pick_talent) {
            rg.GuiDisable();
        }
        if (rg.GuiButton(rl.Rectangle.init(600, 530, 200, 50), button_text) != 0) {
            expertise.has_talent = true;
            state.creating_character.pick_talents += 1;
            if (state.creating_character.pick_talents == cc_talents) {
                state.creating_character = .inactive;
                player.xp = 0;
            }
        }
        if (!can_pick_talent) {
            rg.GuiEnable();
        }
    }
}
