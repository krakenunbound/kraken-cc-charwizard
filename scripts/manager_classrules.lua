-- Castles & Crusades class-combining rules (Adventurer's Backpack), with no
-- ruleset code: both C&C wizards (SiegeCore and the official CnCRPG one) use
-- it. Package name CCClassRules. The tables are in data_classcombo.lua
-- (CCClassCombo), generated from the Backpack module by
-- cc-conversion/build_class_combo.py. cc-conversion/build_official_wizard.py
-- copies this file to the official wizard: edit it here.
--
-- Class keys are names in lower case, letters only, without a bracketed
-- variant: "Arcane Thief" -> arcanethief, "Bard (Spell Caster)" -> bard.

local CODE_TEXT = {
	A = "Allowed.",
	S = "Allowed, but the two classes share abilities (impractical).",
	U = "Unusual: needs the Castle Keeper's agreement and a good reason.",
};
local RACE_CLASSES = { dwarf = true, elf = true, halfling = true, gnome = true };
-- Classes that cannot support (enhanced class) or be plussed.
local NEVER_SUPPORT = { paladin = true, divineknight = true };
DIE_STEP = { d4 = 1, d6 = 2, d8 = 3, d10 = 4, d12 = 5 };
DEITY_CLASSES = { cleric = true, druid = true, paladin = true };

function key(sName)
	local s = (sName or ""):lower():gsub("%s*%b()", ""):gsub("[^a-z]", "");
	return s;
end

-- Alignment a class allows (the ALIGNMENT or DISPOSITION line of its book
-- entry; classes not listed: any). Tests take the two axis words of an
-- alignment ("Lawful Good" -> lawful, good; "Neutral" -> neutral, neutral).
local ALIGN_RULES = {
	paladin = { text = "Lawful good", test = function(l, m) return l == "lawful" and m == "good"; end },
	assassin = { text = "Any non-good", test = function(l, m) return m ~= "good"; end },
	druid = { text = "Neutral (any)", test = function(l, m) return l == "neutral" or m == "neutral"; end },
	foresworn = { text = "Neutral, Neutral/Good, Neutral/Evil", test = function(l, m) return l == "neutral"; end },
	primaldruid = { text = "Chaos/Neutral, Neutral, Law/Neutral", test = function(l, m) return m == "neutral"; end },
	skald = { text = "Neutral or any Chaotic", test = function(l, m) return l == "chaotic" or (l == "neutral" and m == "neutral"); end },
	thief = { text = "Any Neutral or Evil", test = function(l, m) return l == "neutral" or m == "neutral" or m == "evil"; end },
	warlock = { text = "Any Chaotic", test = function(l, m) return l == "chaotic"; end },
	elfmagi = { text = "Good/Neutral or Chaotic", test = function(l, m) return l == "chaotic" or (l == "neutral" and m == "good"); end },
	gnomeprimeval = { text = "Neutral", test = function(l, m) return l == "neutral" and m == "neutral"; end },
};

local function alignmentAxes(sAlignment)
	local s = (sAlignment or ""):lower();
	local l = s:match("^(%a+)") or "";
	local m = s:match("(%a+)$") or "";
	if s == "neutral" or s == "true neutral" then return "neutral", "neutral"; end
	return l, m;
end

-- Does the class allow this alignment? Second value: the book's words.
function isAlignmentAllowed(sClass, sAlignment)
	local tRule = ALIGN_RULES[key(sClass)];
	if not tRule then return true, "Any"; end
	return tRule.test(alignmentAxes(sAlignment)) and true or false, tRule.text;
end

function getAlignmentRuleText(sClass)
	local tRule = ALIGN_RULES[key(sClass)];
	return tRule and tRule.text or "Any";
end

-- The race a race class belongs to ("Dwarf, Iron Born" -> dwarf), or nil.
function getRaceClassRace(sClass)
	if not isRaceClass(sClass) then return nil; end
	return (sClass or ""):lower():match("^%s*(%a+)");
end

-- Race classes (Dwarf Ironborn, Elf Magi, Gnome Primeval, Halfling Feral) combine with nothing.
function isRaceClass(sName)
	local sFirst = (sName or ""):lower():match("^%s*(%a+)");
	return RACE_CLASSES[sFirst or ""] == true;
end

function getRaceKey(sRace)
	local s = (sRace or ""):lower();
	if s:find("half%-elf") or s:find("half elf") then return "halfelf"; end
	if s:find("half%-orc") or s:find("half orc") then return "halforc"; end
	return key(s);
end

-- Plain words for a table code and whether it is allowed for the race.
function describeCode(sCode, sRace)
	if not sCode or sCode == "" then
		return "", "No table entry: the Castle Keeper decides.", true;
	end
	if sCode == "x" then
		return sCode, "Same class.", false;
	end
	local sRaceKey = getRaceKey(sRace);
	local bRace = (sCode:find("E") and (sRaceKey == "elf" or sRaceKey == "halfelf")) or (sCode:find("G") and sRaceKey == "gnome")
		or (sCode:find("H") and sRaceKey == "halfling") or (sCode:find("O") and sRaceKey == "halforc");
	if sCode:find("A") or bRace then
		return sCode, CODE_TEXT.A, true;
	end
	if sCode:find("S") then
		return sCode, CODE_TEXT.S, true;
	end
	if sCode:find("U") then
		return sCode, CODE_TEXT.U, true;
	end
	if sCode:find("[EGHO]") then
		local s = sCode:gsub("E", "elf/half-elf "):gsub("G", "gnome "):gsub("H", "halfling "):gsub("O", "half-orc ");
		return sCode, "Only for some races (" .. StringManager.trim(s) .. ").", false;
	end
	return sCode, "Not allowed (Adventurer's Backpack).", false;
end

-- Multi-class and dual class: the Allowed Multi-Class Combinations tables,
-- read either way round. Returns code, words, allowed.
function getMultiRule(sA, sB, sRace)
	if isRaceClass(sA) or isRaceClass(sB) then
		return "", "A race class combines with no other class (Adventurer's Backpack).", false;
	end
	local kA, kB = key(sA), key(sB);
	if kA == kB then
		return "x", "Same class.", false;
	end
	local sCode = (CCClassCombo.MULTI[kA] or {})[kB] or (CCClassCombo.MULTI[kB] or {})[kA];
	return describeCode(sCode, sRace);
end

-- Enhanced class: supporting option (a class or sub-class key) with a principal class.
function getEnhancedRule(sPrincipal, sOption, sRace)
	local kPrincipal, kOption = key(sPrincipal), key(sOption);
	local tSupport = getSupport(kOption);
	if isRaceClass(sPrincipal) then
		return "", "A race class combines with no other class (Adventurer's Backpack).", false;
	end
	if not tSupport then
		return "", "Not a supporting class.", false;
	end
	if tSupport.class == kPrincipal then
		return "x", "Same class.", false;
	end
	return describeCode((CCClassCombo.ENHANCED[kOption] or {})[kPrincipal], sRace);
end

function getSupport(sKey)
	return CCClassCombo.SUPPORT[key(sKey)];
end

-- Supporting options, sorted by name: { key, name, class, sub, prime }
function getSupportOptions()
	local t = {};
	for k, v in pairs(CCClassCombo.SUPPORT) do
		if not NEVER_SUPPORT[v.class] then
			table.insert(t, { key = k, name = v.name, class = v.class, sub = v.sub, prime = v.prime });
		end
	end
	table.sort(t, function(a, b) return a.name < b.name end);
	return t;
end

-- Level the supporting class counts as: half the principal level (fighter:
-- +2 every 3 levels, Adventurer's Backpack), at least 1 so the class's first
-- abilities ("as 0 level") are listed.
function getSupportLevel(sKey, nPrincipal)
	local tSupport = getSupport(sKey);
	if tSupport and tSupport.class == "fighter" and not tSupport.sub then
		return math.max(1, math.floor(nPrincipal * 2 / 3));
	end
	return math.max(1, math.floor(nPrincipal / 2));
end

-- Additional XP the supporting option needs at a principal level.
function getSupportXP(sKey, nPrincipal)
	local tSupport = getSupport(sKey);
	local tRow = tSupport and tSupport.adv[nPrincipal];
	return tRow and tRow.xp or 0;
end

-- Words: what the supporting option gives at a principal level.
function getSupportGained(sKey, nPrincipal)
	local tSupport = getSupport(sKey);
	local tRow = tSupport and tSupport.adv[nPrincipal];
	return tRow and tRow.gained or "";
end

-- Spells per day of a spell-casting supporting option: { [0] = n, ... } or nil.
function getSupportSlots(sKey, nPrincipal)
	local tSupport = getSupport(sKey);
	if not tSupport or not tSupport.spells then
		return nil;
	end
	local t = {};
	for n, v in pairs(tSupport.spells[nPrincipal] or {}) do
		t[n] = v;
	end
	return t;
end

-- Names of the abilities an option gives ("death attack, poisons, sneak attack").
function getSupportAbilityNames(sKey)
	local t = {};
	local tSupport = getSupport(sKey);
	for s in ((tSupport and tSupport.abilities) or ""):gmatch("[^,]+") do
		table.insert(t, StringManager.trim(s):lower());
	end
	return t;
end

-- Does a class ability belong to a supporting option? Full classes take all
-- of their abilities; a sub-class only those named in its list.
function isSupportAbility(sKey, sAbilityName)
	local tSupport = getSupport(sKey);
	if not tSupport then
		return false;
	end
	if not tSupport.sub then
		return true;
	end
	local sName = (sAbilityName or ""):lower():gsub("%s*%b()", "");
	sName = StringManager.trim(sName);
	for _, s in ipairs(getSupportAbilityNames(sKey)) do
		local sWord = s:gsub("%s*%b()", ""):gsub("%.", "");
		if sName == sWord or sName:find(sWord, 1, true) or sWord:find(sName, 1, true) then
			return true;
		end
	end
	return false;
end

-- Hit dice. Multi-class (and dual class): first x second die; more than two
-- classes use the highest and lowest. Enhanced class: supporting x principal.
function getMultiDie(tDice)
	local sLow, sHigh = nil, nil;
	for _, s in ipairs(tDice) do
		if DIE_STEP[s] then
			if not sLow or DIE_STEP[s] < DIE_STEP[sLow] then sLow = s; end
			if not sHigh or DIE_STEP[s] > DIE_STEP[sHigh] then sHigh = s; end
		end
	end
	if not sLow then
		return nil;
	end
	return CCClassCombo.HD_MULTI[sHigh][sLow];
end

function getEnhancedDie(sSupportDie, sPrincipalDie)
	return (CCClassCombo.HD_ENHANCED[sSupportDie] or {})[sPrincipalDie];
end

-- Class plus: what a class gives at zero level, or nil when it may not be plussed.
function getPlusText(sClass)
	local v = CCClassCombo.PLUS[key(sClass)];
	if v == false then
		return nil;
	end
	return v;
end

-- XP needed with n plussed classes: each costs 5% of all experience earned,
-- the same as needing 1 / (1 - 0.05 n) as much.
function getPlusXP(nXP, nPlus)
	if nPlus <= 0 or nXP <= 0 then
		return nXP;
	end
	return math.ceil(nXP / (1 - 0.05 * nPlus));
end

-- Training before 1st level in a new class (dual class, reclass).
function getTrainingNote(nXP, sNewClass)
	local nCost = math.max(math.floor((nXP or 0) * 0.05), 2500);
	local s = string.format("Training first (Adventurer's Backpack): with an instructor, %d XP to reach zero level in the new class and %d more to reach 1st level; without one, double (%d and %d).",
		nCost, nCost, nCost * 2, nCost * 2);
	local k = key(sNewClass);
	if k == "wizard" or k == "illusionist" then
		s = s .. " A wizard or illusionist needs an instructor.";
	end
	return s .. " Level Up here is for when the character reaches 1st level.";
end

function getReclassLoss(sOld, sNew)
	if DEITY_CLASSES[key(sOld)] and not DEITY_CLASSES[key(sNew)] then
		return 2;
	end
	return 1;
end
