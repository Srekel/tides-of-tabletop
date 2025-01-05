const std = @import("std");

pub const Attribute = struct {
    name: [:0]const u8 = "",
    picked: bool = false,
};

pub const ExpertiseLevel = enum { Inexperienced, Beginner, Novice, Practitioner, Expert, Master };

pub const Expertise = struct {
    name: [:0]const u8 = "",
    level: ExpertiseLevel = .Inexperienced,
    points: u8 = 0,
    has_talent: bool = false,
    attributes: std.BoundedArray(Attribute, 16),

    pub fn costForPoint(self: Expertise) u32 {
        const cost = 5 + @as(u32, @intFromEnum(self.level)) * 1;
        return cost - @as(u8, if (self.has_talent) 2 else 0);
    }

    pub fn canUpgrade(self: Expertise) bool {
        if (self.points != 4) {
            return false;
        }
        if (self.level == .Master) {
            return false;
        }
        var attributes: i32 = 0;
        for (self.attributes.buffer) |attribute| {
            if (attribute.picked) {
                attributes += 1;
            }
        }

        // const next_level = (@as(u32, @intFromEnum(self.level)) + 1);
        // if (next_level > attributes * 2) {
        //     return false;
        // }
        return true;
    }
    pub fn costForUpgrade(self: Expertise) u32 {
        const cost: u32 = (@as(u32, @intFromEnum(self.level)) + 1) * 3;
        return cost - @as(u8, if (self.has_talent) 2 else 0);
    }
    pub fn costForAttribute(self: Expertise) u32 {
        var cost: u32 = 5;
        for (self.attributes.buffer) |attribute| {
            if (attribute.picked) {
                cost += 5;
            }
        }
        return cost - @as(u8, if (self.has_talent) 2 else 0);
    }

    pub fn pickedAttributeCount(self: Expertise) u32 {
        var count: u32 = 0;
        for (self.attributes.slice()) |attribute| {
            if (attribute.picked) {
                count += 1;
            }
        }
        return count;
    }

    pub fn getAttribute(self: *Expertise, attribute_name: []const u8) *Attribute {
        for (self.attributes.slice()) |*attribute| {
            if (std.mem.eql(u8, attribute.name, attribute_name)) {
                return attribute;
            }
        }
        unreachable;
    }
};

pub const Character = struct {
    name: std.BoundedArray(u8, 64),
    player: std.BoundedArray(u8, 64),
    xp: u32 = 500,
    expertises: std.BoundedArray(Expertise, 16),

    pub fn getExpertise(self: *Character, exp_name: []const u8) *Expertise {
        for (self.expertises.slice()) |*exp| {
            if (std.mem.eql(u8, exp.name, exp_name)) {
                return exp;
            }
        }
        unreachable;
    }
};

pub var all_expertises = [_][:0]const u8{
    "Communication",
    "Crafting",
    "Education",
    "Exploration",
    "Healing",
    "Investigation",
    "Melee Combat",
    "Movement",
    "Perception",
    "Physique",
    "Ranged Combat",
    "Thievery",
};

pub var all_difficulties = [_][:0]const u8{
    "Routine",
    "Easy",
    "Tricky",
    "Hard",
    "Extreme",
    "Miraculous",
};

pub var target_numbers = [_]f32{
    5,
    10,
    15,
    20,
    25,
    30,
};

pub var ui_expertises: [*c][*c]const u8 = undefined;
pub var ui_difficulties: [*c][*c]const u8 = undefined;

pub fn init() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    ui_expertises = @ptrCast(allocator.alloc([*]const u8, all_expertises.len) catch unreachable);
    for (all_expertises, 0..) |exp, i| {
        ui_expertises[i] = exp;
    }
    ui_difficulties = @ptrCast(allocator.alloc([*]const u8, all_difficulties.len) catch unreachable);
    for (all_difficulties, 0..) |diff, i| {
        ui_difficulties[i] = diff;
    }
}

pub fn makeCharacter(name: [:0]const u8, player: [:0]const u8) Character {
    const exp_movement: Expertise = .{
        .name = "Movement",
        .level = .Beginner,
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
        .level = .Beginner,
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
    const exp_perception: Expertise = .{
        .name = "Perception",
        .level = .Beginner,
        .attributes = std.BoundedArray(Attribute, 16).fromSlice(&[_]Attribute{
            .{ .name = "Alert" },
            .{ .name = "Auditory" },
            .{ .name = "Discerning" },
            .{ .name = "Kinesthetic" },
            .{ .name = "Nasal" },
            .{ .name = "Precise" },
            .{ .name = "Sagacious" },
            .{ .name = "Sensitive" },
            .{ .name = "Sharp-sighted" },
            .{ .name = "Skeptical" },
            .{ .name = "Tactile" },
        }) catch unreachable,
    };
    const exp_communication: Expertise = .{
        .name = "Communication",
        .level = .Beginner,
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
        exp_perception,
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
    const character = Character{
        .name = std.BoundedArray(u8, 64).fromSlice(name) catch unreachable,
        .player = std.BoundedArray(u8, 64).fromSlice(player) catch unreachable,
        .expertises = std.BoundedArray(Expertise, 16).fromSlice(&expertises) catch unreachable,
    };

    return character;
}
