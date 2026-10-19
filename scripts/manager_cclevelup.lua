-- Castles & Crusades level-up wizard for SmiteWorks' official C&C ruleset
-- (CnCRPG). Package name CCLevelUp.
--
-- Opened from the Lvl Up button on the character sheet (Main, beside the
-- level). Same steps as the SiegeCore version and the 5e level-up window:
-- Class, Hit Points, Abilities, Spells, Finish. Nothing is written until
-- Level Up on the Finish page.
--
-- Paths (Adventurer's Backpack, Changing Classes):
--   Level Up  - the character's class gains a level. The original class
--               (classes.slot1) goes through the official Character Builder
--               (the loader a class drop opens: abilities, base to hit,
--               experience needed) with its own hit point roll off; the hit
--               points rolled here are added.
--   Add Class - dual class: a second class at 1st level, both advance,
--               experience divided equally, hit points only from the
--               original class (on the Dual Class Hit Die table). Only a
--               class whose prime the character already holds; the
--               combination table limits apply.
--   Reclass   - the original class is abandoned: it loses a level (two when
--               a deity-serving class is left for one that is not, with its
--               abilities), the new class starts at 1st level and takes all
--               experience, hit points follow the Reclass Hit Point
--               Modification table until the new class passes the old one,
--               base to hit is the better of the two, primes swap when the
--               new class's prime is not held.
-- Both new-class paths follow a training period (5% of the XP total,
-- minimum 2,500, to zero level and again to 1st level; double without an
-- instructor): noted for the Castle Keeper, not enforced.
--
-- The official sheet holds one class (classes.slot1), so the second class
-- lives in classes.slot2 (name, level, officialpath, kind "dual" or
-- "reclass"); its abilities go on the sheet's ability list (source = the
-- class name), its spells in a spell block of its own, and the sheet's Main
-- tab shows it under the class. Hit points gained through this window are
-- logged per level in classes.slotN.hplog so a lost level takes off what it
-- gave.

local TABS = { "class", "hp", "spells", "finish" };
local ROLLTYPE = "cclevelup";
local STATS = { "strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma" };

-- The class-combining rules (tables, hit dice, supporting classes) are in
-- CCClassRules / CCClassCombo, shared with the creation wizard.
local DIE_STEP = { d4 = 1, d6 = 2, d8 = 3, d10 = 4, d12 = 5 };
local DEITY_CLASSES = { cleric = true, druid = true, paladin = true };

local L = {};
local _wMain = nil;
local _nRollGen = 0;

function onInit()
	ActionsManager.registerResultHandler(ROLLTYPE, onRoll);
	if ClaudeBridge and ClaudeBridge.registerPackage then
		ClaudeBridge.registerPackage("CCLevelUp", CCLevelUp);
	end
end

function getState()
	return L;
end

function lower(s)
	return StringManager.trim(s or ""):lower();
end

function firstWord(s)
	return lower(s):match("^(%a+)") or "";
end

function open(nodeChar)
	if not nodeChar then
		return;
	end
	if Session.IsHost and not DB.findNode("ccwizardofficial.classes") then
		CCWizard.prepareOfficialRecords();
	end
	L = { char = DB.getPath(nodeChar), mode = nil, slot = nil, newclass = nil, hp = nil, spells = {} };
	_nRollGen = _nRollGen + 1;
	-- A window already open (another character, or kept over a reload) starts afresh.
	local wOld = Interface.findWindow("cclevelup", "");
	if wOld then
		wOld.close();
	end
	Interface.openWindow("cclevelup", "");
end

function registerWindow(w)
	-- A window restored by FGU (campaign load, reload) has no level up in progress.
	if not getChar() then
		w.close();
		return;
	end
	_wMain = w;
	showTab("class");
end

function unregisterWindow(w)
	if _wMain == w then
		_wMain = nil;
	end
end

function getChar()
	return DB.findNode(L.char or "");
end

--
-- Classes on the character
--

-- The wizard's copy of an official class record (level rows, slots, hit dice, primes).
function findClassProxy(sName)
	local sKey = lower(sName);
	local nodeFound = nil;
	CCWizard.forEachOfficial("classes", function(node)
		if lower(DB.getValue(node, "name", "")) == sKey then
			nodeFound = node;
		end
	end);
	return nodeFound;
end

function getSlotName(sSlot, nodeChar)
	return DB.getValue(nodeChar or getChar(), "classes." .. sSlot .. ".name", "");
end

function getSlotLevel(sSlot, nodeChar)
	return DB.getValue(nodeChar or getChar(), "classes." .. sSlot .. ".level", 0);
end

-- "dual", "reclass" or "" for the character's second class.
function getSecondKind(nodeChar)
	if getSlotName("slot2", nodeChar) == "" then
		return "";
	end
	return DB.getValue(nodeChar or getChar(), "classes.slot2.kind", "dual");
end

-- Rows for the Class page: { slot, name, level, note, canlevel }
function getClassRows(nodeChar)
	local t = {};
	nodeChar = nodeChar or getChar();
	local sKind = getSecondKind(nodeChar);
	local tFirst = { reclass = "abandoned (reclass): no longer advances", dual = "original class", multi = "multi-class",
		enhanced = "principal class (enhanced)" };
	local tSecond = { reclass = "reclass: takes all experience", dual = "dual class (no hit points)",
		multi = "multi-class: rises with the first class", enhanced = "supporting class: rises with the principal class" };
	if getSlotName("slot1", nodeChar) ~= "" then
		table.insert(t, { slot = "slot1", name = getSlotName("slot1", nodeChar), level = getSlotLevel("slot1", nodeChar),
			note = tFirst[sKind] or "", canlevel = sKind ~= "reclass" });
	end
	if sKind ~= "" then
		table.insert(t, { slot = "slot2", name = getSlotName("slot2", nodeChar), level = getSlotLevel("slot2", nodeChar),
			note = tSecond[sKind] or "", canlevel = sKind == "dual" or sKind == "reclass" });
	end
	for _, v in pairs(DB.getChildren(nodeChar, "ccplus")) do
		table.insert(t, { slot = "", name = DB.getValue(v, "name", ""), level = 0, note = "class plus (zero level)", canlevel = false });
	end
	return t;
end

-- The official record copy of the second class (its officialpath).
function getSlot2Proxy(nodeChar)
	local sPath = DB.getValue(nodeChar or getChar(), "classes.slot2.officialpath", "");
	local nodeFound = nil;
	CCWizard.forEachOfficial("classes", function(node)
		if DB.getValue(node, "officialpath", "") == sPath then nodeFound = node; end
	end);
	return nodeFound or findClassProxy(getSlotName("slot2", nodeChar));
end

-- One line for the sheet: the second class, if any.
function describeSecondClass(nodeChar)
	local sKind = getSecondKind(nodeChar);
	if sKind == "" then
		return "";
	end
	local tWord = { dual = "Dual:", reclass = "Reclass:", multi = "Multi:", enhanced = "Supporting:" };
	return string.format("%s %s %d", tWord[sKind] or "", getSlotName("slot2", nodeChar), getSlotLevel("slot2", nodeChar));
end

function isNewClassMode()
	return L.mode == "dual" or L.mode == "reclass";
end

-- The class record that gains the level.
function getTarget()
	if isNewClassMode() then
		return L.newclass and DB.findNode(L.newclass);
	end
	if L.slot then
		return findClassProxy(getSlotName(L.slot));
	end
	return nil;
end

function getTargetName()
	return DB.getValue(getTarget(), "name", "");
end

function getFromLevel()
	if isNewClassMode() then
		return 0;
	end
	return L.slot and getSlotLevel(L.slot) or 0;
end

function getToLevel()
	return getFromLevel() + 1;
end

function chooseLevelUp(sSlot)
	if not findClassProxy(getSlotName(sSlot)) then
		ChatManager.SystemMessage("Level up: the class record (" .. getSlotName(sSlot) .. ") is not in a loaded book.");
		return;
	end
	L.mode = "levelup";
	L.slot = sSlot;
	L.newclass = nil;
	resetChoices();
	showTab("class");
end

function chooseNewClass(sMode, sClassPath)
	L.mode = sMode;
	L.slot = "slot2";
	L.newclass = sClassPath;
	resetChoices();
	showTab("class");
end

function chooseDualClass(sClassPath)
	chooseNewClass("dual", sClassPath);
end

function chooseReclass(sClassPath)
	chooseNewClass("reclass", sClassPath);
end

-- Cancel on the chosen class: back to the list of classes.
function cancelChoice()
	L.mode = nil;
	L.slot = nil;
	L.newclass = nil;
	resetChoices();
	showTab("class");
end

function resetChoices()
	L.hp = nil;
	L.spells = {};
	_nRollGen = _nRollGen + 1;
end

--
-- Class combining rules
--

function isRaceClass(sName)
	return CCClassRules.isRaceClass(sName);
end

function getRaceKey(nodeChar)
	local s = lower(DB.getValue(nodeChar, "race", ""));
	if s:find("half%-elf") or s:find("half elf") then return "halfelf"; end
	if s:find("half%-orc") or s:find("half orc") then return "halforc"; end
	return s;
end

function canAddClass()
	local nodeChar = getChar();
	local sName = getSlotName("slot1", nodeChar);
	if sName == "" then
		return false, "The character has no class yet: use the Character Wizard.";
	end
	if getSecondKind(nodeChar) ~= "" then
		return false, "The character already has two classes (dual classed or reclassed).";
	end
	if isRaceClass(sName) then
		return false, "A race class (dwarf, elf, gnome, halfling) cannot be combined with another class (Adventurer's Backpack).";
	end
	return true;
end

function getComboRule(sOld, sNew, nodeChar)
	return CCClassRules.getMultiRule(sOld, sNew, DB.getValue(nodeChar, "race", ""));
end

function getClassPrimes(nodeClass)
	local t = {};
	for _, s in ipairs(STATS) do
		if DB.getValue(nodeClass, "primes." .. s, 0) == 1 then
			table.insert(t, s);
		end
	end
	return t;
end

function hasClassPrime(nodeChar, nodeClass)
	local tPrimes = getClassPrimes(nodeClass);
	if #tPrimes == 0 then
		return true, "";
	end
	for _, s in ipairs(tPrimes) do
		if DB.getValue(nodeChar, "abilities." .. s .. ".prime", 0) == 1 then
			return true, s;
		end
	end
	return false, tPrimes[1];
end

-- Classes the character could add: { node, code, rule, allowed (dual class) }
function getNewClassChoices()
	local nodeChar = getChar();
	local sOld = getSlotName("slot1", nodeChar);
	local t, tSeen = {}, {};
	CCWizard.forEachOfficial("classes", function(node)
		local sName = DB.getValue(node, "name", "");
		if not tSeen[lower(sName)] and lower(sName) ~= lower(sOld) and not isRaceClass(sName) and DB.getChildCount(node, "levels") > 0 then
			tSeen[lower(sName)] = true;
			local sCode, sRule, bAllowed = getComboRule(sOld, sName, nodeChar);
			local bPrime, sPrime = hasClassPrime(nodeChar, node);
			if bAllowed and not bPrime then
				bAllowed = false;
				sRule = string.format("Dual class needs a prime the character has (%s is not prime); reclass swaps primes.", StringManager.capitalize(sPrime));
			end
			table.insert(t, { node = node, code = sCode, rule = sRule, allowed = bAllowed });
		end
	end);
	table.sort(t, function(a, b)
		if a.allowed ~= b.allowed then return a.allowed end
		return DB.getValue(a.node, "name", "") < DB.getValue(b.node, "name", "");
	end);
	return t;
end

function getReclassLoss(sOld, sNew)
	if DEITY_CLASSES[firstWord(sOld)] and not DEITY_CLASSES[firstWord(sNew)] then
		return 2;
	end
	return 1;
end

function getTrainingNote(sNewClass)
	local nXP = DB.getValue(getChar(), "exp", 0);
	local nCost = math.max(math.floor(nXP * 0.05), 2500);
	local s = string.format("Training first (Adventurer's Backpack): with an instructor, %d XP to reach zero level in the new class and %d more to reach 1st level; without one, double (%d and %d).",
		nCost, nCost, nCost * 2, nCost * 2);
	local sKey = lower(sNewClass);
	if sKey == "wizard" or sKey == "illusionist" then
		s = s .. " A wizard or illusionist needs an instructor.";
	end
	return s .. " Level Up here is for when the character reaches 1st level.";
end

--
-- XP
--

function getXPNote()
	local nodeChar = getChar();
	local nodeTarget = getTarget();
	if not nodeTarget then
		return "";
	end
	local nXP = DB.getValue(nodeChar, "exp", 0);
	local sName = getTargetName();
	if L.mode == "dual" then
		return string.format("Dual class: from now on experience is divided equally between %s and %s (Adventurer's Backpack). The character has %d XP.",
			getSlotName("slot1"), sName, nXP) .. "\n" .. getTrainingNote(sName);
	end
	if L.mode == "reclass" then
		return string.format("Reclass: from now on all experience goes to %s; %s no longer advances (Adventurer's Backpack). The character has %d XP.",
			sName, getSlotName("slot1"), nXP) .. "\n" .. getTrainingNote(sName);
	end
	local nodeRow = CCWizard.getLevelRow(nodeTarget, getToLevel());
	local nNeed = nodeRow and DB.getValue(nodeRow, "xp", 0) or 0;
	local nCombined = CCWizard.getOfficialNextXP(nodeChar);
	if nCombined and L.slot == "slot1" then
		return string.format("Next level needs %d XP (the combined classes, Adventurer's Backpack); the character has %d.%s", nCombined, nXP,
			nXP < nCombined and " The Castle Keeper can allow the level anyway." or "");
	end
	if getSecondKind(nodeChar) == "dual" then
		local nBase = DB.getValue(nodeChar, "classes.slot2.xpbase", 0);
		local nSince = math.floor(math.max(nXP - nBase, 0) / 2);
		return string.format("%s %d needs %d XP in that class; it has %d (experience since the dual class is divided equally between the classes).",
			sName, getToLevel(), nNeed, L.slot == "slot2" and nSince or (nBase + nSince));
	end
	if nNeed > 0 and nXP < nNeed then
		return string.format("%s %d needs %d XP; the character has %d. The Castle Keeper can allow the level anyway.", sName, getToLevel(), nNeed, nXP);
	end
	return string.format("%s %d needs %d XP; the character has %d.", sName, getToLevel(), nNeed, nXP);
end

--
-- Hit points
--

function getHitDie(nodeClass)
	return lower(DB.getValue(nodeClass, "hitdie", "")):match("(d%d+)") or "";
end

function getConBonus()
	return CCWizard.getModifier(DB.getValue(getChar(), "abilities.constitution.score", 10));
end

-- Dice, flat bonus and a note for the level. Con is added to rolled dice.
function getHPPlan()
	local nodeChar = getChar();
	local nodeTarget = getTarget();
	if not nodeTarget then
		return {}, 0, "Choose a class on the Class page.";
	end
	local nLevel = getToLevel();
	local sKind = isNewClassMode() and L.mode or getSecondKind(nodeChar);
	local sName = getTargetName();
	if sKind == "dual" and L.slot == "slot2" then
		return {}, 0, "A dual-classed character gains hit points only when the original class gains a level (Adventurer's Backpack).";
	end
	if sKind == "reclass" and L.slot == "slot2" then
		local sOld = getSlotName("slot1");
		local nodeOld = findClassProxy(sOld);
		local nOldLevel = getSlotLevel("slot1");
		if L.mode == "reclass" then
			nOldLevel = math.max(nOldLevel - getReclassLoss(sOld, sName), 1);
		end
		if nLevel <= nOldLevel then
			local nStep = (DIE_STEP[getHitDie(nodeTarget)] or 0) - (DIE_STEP[getHitDie(nodeOld)] or 0);
			if nStep > 0 then
				return {}, nStep, string.format("Reclass Hit Point Modification: %s (%s) after %s (%s) gives %d hit point(s) a level, no constitution bonus, until %s's level passes %s's (%d).",
					sName, getHitDie(nodeTarget), sOld, getHitDie(nodeOld), nStep, sName, sOld, nOldLevel);
			end
			return {}, 0, string.format("Reclass: no hit points until %s's level passes %s's (%d); the new hit die is not larger (Adventurer's Backpack).",
				sName, sOld, nOldLevel);
		end
	end
	local tDice, nFlat = CCWizard.getOfficialHPGain(nodeTarget, nLevel);
	if (sKind == "multi" or sKind == "enhanced") and L.slot == "slot1" and #tDice > 0 then
		local nodeSecond = getSlot2Proxy(nodeChar);
		local sMain, sSecond = getHitDie(nodeTarget), getHitDie(nodeSecond);
		local sDie = sKind == "multi" and CCClassRules.getMultiDie({ sMain, sSecond }) or CCClassRules.getEnhancedDie(sSecond, sMain);
		if sDie then
			for i = 1, #tDice do tDice[i] = sDie; end
			return tDice, nFlat, string.format("%s: %s and %s roll %s (Adventurer's Backpack).",
				sKind == "multi" and "Multi-class" or "Enhanced class", sMain, sSecond, sDie);
		end
	end
	if sKind == "dual" and L.slot == "slot1" and #tDice > 0 then
		local nodeSecond = findClassProxy(getSlotName("slot2"));
		local sOrigin = getHitDie(nodeTarget);
		local sDie = nodeSecond and CCClassRules.getMultiDie({ sOrigin, getHitDie(nodeSecond) });
		if sDie then
			for i = 1, #tDice do tDice[i] = sDie; end
			return tDice, nFlat, string.format("Dual Class Hit Die: %s with %s rolls %s.", sOrigin, getHitDie(nodeSecond), sDie);
		end
	end
	return tDice, nFlat, "";
end

function needsHPRoll()
	local tDice = getHPPlan();
	return #tDice > 0;
end

function describeHPRoll()
	local tDice, nFlat, sNote = getHPPlan();
	if #tDice == 0 and nFlat == 0 then
		return sNote ~= "" and sNote or "No hit points this level (or the Castle Keeper sets them for high levels).";
	end
	local s = #tDice > 0 and (#tDice .. tDice[1]) or "";
	local nCon = #tDice > 0 and getConBonus() or 0;
	if nCon ~= 0 then s = s .. string.format(" %+d Con", nCon); end
	if nFlat > 0 then s = s .. (s ~= "" and " " or "") .. string.format("+%d", nFlat); end
	if #tDice == 0 then s = s .. " (fixed)"; end
	return (sNote ~= "" and (sNote .. "\n") or "") .. "Hit points for this level: " .. s;
end

function rollHP()
	local tDice, nFlat = getHPPlan();
	if #tDice == 0 then
		L.hp = nFlat;
		refreshAll();
		return;
	end
	if L.hp ~= nil and OptionsManager.isOption("CCWIZ_REROLL", "off") then
		ChatManager.SystemMessage("Hit points are already rolled (the Castle Keeper has rerolls off).");
		return;
	end
	_nRollGen = _nRollGen + 1;
	local nodeChar = getChar();
	local rRoll = { sType = ROLLTYPE, aDice = tDice, nMod = nFlat + getConBonus(),
		sDesc = string.format("[LEVEL UP] %s %s %d hit points", DB.getValue(nodeChar, "name", ""), getTargetName(), getToLevel()),
		sGen = tostring(_nRollGen) };
	ActionsManager.performAction(nil, ActorManager.resolveActor(nodeChar), rRoll);
end

function onRoll(rSource, rTarget, rRoll)
	Comm.deliverChatMessage(ActionsManager.createActionMessage(rSource, rRoll));
	if tostring(_nRollGen) ~= (rRoll.sGen or "") then
		return;
	end
	L.hp = math.max(1, ActionsManager.total(rRoll));
	refreshAll();
end

--
-- Abilities
--

function getAbilitiesAt(nodeClass, nLevel)
	local t = {};
	for _, v in pairs(DB.getChildren(nodeClass, "abilities")) do
		if tonumber(DB.getValue(v, "level", "")) == nLevel then
			table.insert(t, v);
		end
	end
	table.sort(t, function(a, b) return DB.getValue(a, "name", "") < DB.getValue(b, "name", "") end);
	return t;
end

function getNewAbilities()
	local t = {};
	local nodeTarget = getTarget();
	if nodeTarget then
		for _, v in ipairs(getAbilitiesAt(nodeTarget, getToLevel())) do
			table.insert(t, DB.getValue(v, "name", ""));
		end
	end
	return t;
end

function getBtH(nodeClass, nLevel)
	local nodeRow = nodeClass and nLevel > 0 and CCWizard.getLevelRow(nodeClass, nLevel);
	return nodeRow and DB.getValue(nodeRow, "bth", 0) or 0;
end

function describeLevel()
	local nodeTarget = getTarget();
	if not nodeTarget then
		return "Choose a class on the Class page.";
	end
	local nLevel = getToLevel();
	local t = { string.format("%s %d", getTargetName(), nLevel) };
	if nLevel == 1 or getBtH(nodeTarget, nLevel) ~= getBtH(nodeTarget, nLevel - 1) then
		table.insert(t, string.format("Base to hit %+d", getBtH(nodeTarget, nLevel)));
	end
	local tNew = getNewAbilities();
	table.insert(t, #tNew > 0 and ("New: " .. table.concat(tNew, ", ")) or "No new class abilities at this level; existing ones grow with the level.");
	if L.mode == "reclass" then
		table.insert(t, describeReclass());
	elseif L.mode == "dual" or getSecondKind(getChar()) == "dual" then
		table.insert(t, "Dual class: saving throws and general checks use the original class's level; checks for a class's own abilities use that class's level.");
	end
	local sKind = getSecondKind(getChar());
	if L.slot == "slot1" and sKind == "multi" then
		table.insert(t, string.format("Multi-class: %s rises to level %d with it.", getSlotName("slot2"), nLevel));
	elseif L.slot == "slot1" and sKind == "enhanced" then
		local sKey = DB.getValue(getChar(), "classes.slot2.key", "");
		local sGained = CCClassRules.getSupportGained(sKey, nLevel);
		table.insert(t, string.format("Supporting %s: counts as level %d.%s", getSlotName("slot2"),
			CCClassRules.getSupportLevel(sKey, nLevel), sGained ~= "" and (" Gains: " .. sGained .. ".") or ""));
	end
	return table.concat(t, "\n");
end

function describeReclass()
	local nodeChar = getChar();
	local sOld, sNew = getSlotName("slot1"), getTargetName();
	local nOld = getSlotLevel("slot1");
	local nLoss = getReclassLoss(sOld, sNew);
	local t = { string.format("Reclass: %s abandons %s for %s (1st level). %s drops from level %d to %d and loses the hit points of the lost level(s).",
		DB.getValue(nodeChar, "name", ""), sOld, sNew, sOld, nOld, math.max(nOld - nLoss, 1)) };
	if nLoss == 2 then
		table.insert(t, string.format("Leaving a deity-serving class: %s's abilities are lost (they come off the sheet) and two levels go.", sOld));
	elseif DEITY_CLASSES[firstWord(sOld)] then
		table.insert(t, string.format("Deity-serving class to deity-serving class: keeping the same religion, %s's abilities stay usable; otherwise the Castle Keeper applies the two-level loss.", sOld));
	else
		table.insert(t, string.format("Using abilities found only in %s costs 10%% of the adventure's experience (5%% for preparing them).", sOld));
	end
	local bPrime, sPrime = hasClassPrime(nodeChar, getTarget());
	if not bPrime then
		local tOld = getClassPrimes(findClassProxy(sOld));
		table.insert(t, string.format("Primes swap: %s becomes prime%s.", StringManager.capitalize(sPrime),
			#tOld > 0 and (", " .. StringManager.capitalize(tOld[1]) .. " stops being prime") or ""));
	end
	table.insert(t, "Base to hit is the better of the two classes; saving throws and general checks use the higher class level.");
	return table.concat(t, "\n");
end

--
-- Spells
--

-- Spell lists that gain spells with this level: the class levelled, and
-- with multi-class the second class, with enhanced class a spell-casting
-- supporting class (its Supporting Spells table). { node, class, slots, slot }
function getCasterSets()
	local t = {};
	local nodeTarget = getTarget();
	if not nodeTarget then
		return t;
	end
	local nLevel = getToLevel();
	local function add(node, tSlots, sSlot)
		local sClass = node and DB.getValue(node, "spellclass", "") or "";
		if sClass ~= "" and tSlots and next(tSlots) then
			table.insert(t, { node = node, class = sClass, slots = tSlots, slot = sSlot });
		end
	end
	add(nodeTarget, getSlots(nLevel, nodeTarget), L.slot);
	local sKind = getSecondKind(getChar());
	if not isNewClassMode() and L.slot == "slot1" then
		local nodeSecond = getSlot2Proxy(getChar());
		if sKind == "multi" then
			add(nodeSecond, getSlots(nLevel, nodeSecond), "slot2");
		elseif sKind == "enhanced" then
			add(nodeSecond, CCClassRules.getSupportSlots(DB.getValue(getChar(), "classes.slot2.key", ""), nLevel), "slot2");
		end
	end
	return t;
end

function getSpellSetIndex()
	local n = L.spellset or 1;
	if n > #getCasterSets() then n = 1; end
	return n;
end

function setSpellSetIndex(n)
	L.spellset = n;
	refreshAll();
end

function getSpellSet(n)
	return getCasterSets()[n or getSpellSetIndex()];
end

function getSpellClass(n)
	local t = getSpellSet(n);
	return t and t.class or "";
end

-- The spell block of a class: the one named for it, else (the original
-- class) the first block.
function getSpellBlock(sClassName, bCreate)
	local nodeChar = getChar();
	local nodeFirst = nil;
	for _, node in pairs(DB.getChildren(nodeChar, "spellset")) do
		nodeFirst = nodeFirst or node;
		if lower(DB.getValue(node, "spellclass.name", "")) == lower(sClassName) then
			return node;
		end
	end
	if lower(sClassName) == lower(getSlotName("slot1")) and nodeFirst then
		return nodeFirst;
	end
	if bCreate then
		local node = DB.createChild(DB.createChild(nodeChar, "spellset"));
		DB.setValue(node, "spellclass.name", "string", sClassName);
		DB.setValue(node, "caster_level", "number", 0);
		return node;
	end
	return nil;
end

function getSlots(nLevel, nodeClass)
	local nodeTarget = nodeClass or getTarget();
	local t = {};
	local nodeRow = nodeTarget and CCWizard.getLevelRow(nodeTarget, nLevel);
	local i = 0;
	for s in (nodeRow and DB.getValue(nodeRow, "slots", "") or ""):gmatch("[^,]+") do
		t[i] = tonumber(s) or 0;
		i = i + 1;
	end
	local sStat = nodeTarget and DB.getValue(nodeTarget, "slotbonusstat", "") or "";
	local nScore = sStat ~= "" and DB.getValue(getChar(), "abilities." .. sStat .. ".score", 10) or 10;
	for sMin, sLevel, sCount in (nodeTarget and DB.getValue(nodeTarget, "slotbonuses", "") or ""):gmatch("(%d+):(%d+):(%d+)") do
		local n = tonumber(sLevel);
		if nScore >= tonumber(sMin) and (t[n] or 0) > 0 then
			t[n] = t[n] + tonumber(sCount);
		end
	end
	return t;
end

function getKnown(sClass)
	local t, tNames = {}, {};
	local nodeBlock = getSpellBlock(sClass or getSpellClass(), false);
	if not nodeBlock then
		return t, tNames;
	end
	for n = 0, 9 do
		for _, nodeSpell in pairs(DB.getChildren(nodeBlock, "levels.level" .. n .. ".spells")) do
			t[n] = (t[n] or 0) + 1;
			tNames[lower(DB.getValue(nodeSpell, "name", ""))] = true;
		end
	end
	return t, tNames;
end

function getNewPicks(n)
	local tSet = getSpellSet(n);
	local t = {};
	if not tSet then
		return t;
	end
	local tKnown = getKnown(tSet.class);
	for i = 0, 9 do
		local nPicks = math.max((tSet.slots[i] or 0) - (tKnown[i] or 0), 0);
		if nPicks > 0 then t[i] = nPicks; end
	end
	return t;
end

function hasSpellStep()
	for n = 1, #getCasterSets() do
		if next(getNewPicks(n)) then return true; end
	end
	return false;
end

function getSpellChoices(sSearch)
	local sClass = getSpellClass();
	local tPicks = getNewPicks();
	local _, tKnown = getKnown(sClass);
	local t, tSeen = {}, {};
	sSearch = lower(sSearch);
	CCWizard.forEachOfficial("spells", function(node)
		local sName = DB.getValue(node, "name", "");
		local nLevel = CCWizard.getPowerLevelFor(node, sClass);
		if nLevel and tPicks[nLevel] and not tSeen[lower(sName)] and not tKnown[lower(sName)]
				and (sSearch == "" or lower(sName):find(sSearch, 1, true)) then
			tSeen[lower(sName)] = true;
			table.insert(t, { node = node, level = nLevel });
		end
	end);
	table.sort(t, function(a, b) if a.level ~= b.level then return a.level < b.level end
		return DB.getValue(a.node, "name", "") < DB.getValue(b.node, "name", "") end);
	return t;
end

-- L.spells[path] = { level, set } (set: index into getCasterSets).
function isSpellPicked(sPath)
	local t = L.spells[sPath];
	return t ~= nil and t.set == getSpellSetIndex();
end

function countSpellsAt(nLevel, nSet)
	nSet = nSet or getSpellSetIndex();
	local n = 0;
	for _, v in pairs(L.spells) do
		if v.level == nLevel and v.set == nSet then n = n + 1; end
	end
	return n;
end

function toggleSpell(sPath, bOn)
	local nSet = getSpellSetIndex();
	if bOn then
		local nLevel = CCWizard.getPowerLevelFor(DB.findNode(sPath), getSpellClass()) or 0;
		local nAllowed = getNewPicks()[nLevel] or 0;
		if not isSpellPicked(sPath) and countSpellsAt(nLevel) >= nAllowed then
			ChatManager.SystemMessage(string.format("Level %d: %d new spell(s) already chosen.", nLevel, nAllowed));
			return false;
		end
		L.spells[sPath] = { level = nLevel, set = nSet };
	else
		L.spells[sPath] = nil;
	end
	refreshTabs();
end

function describeSpellPicks()
	local t = {};
	local tSets = getCasterSets();
	for n, tSet in ipairs(tSets) do
		for i = 0, 9 do
			local nPicks = getNewPicks(n)[i];
			if nPicks then
				table.insert(t, string.format("%sLevel %d: %d of %d new spells chosen", #tSets > 1 and (tSet.class .. ", ") or "", i, countSpellsAt(i, n), nPicks));
			end
		end
	end
	return #t > 0 and table.concat(t, "\n") or "No new spells at this level.";
end

--
-- Tabs
--

function isTabDone(sTab)
	if sTab == "class" or sTab == "abilities" then
		return getTarget() ~= nil;
	elseif sTab == "hp" then
		return getTarget() ~= nil and (not needsHPRoll() or L.hp ~= nil);
	elseif sTab == "spells" then
		for nSet = 1, #getCasterSets() do
			for i, n in pairs(getNewPicks(nSet)) do
				if countSpellsAt(i, nSet) < n then return false; end
			end
		end
		return true;
	end
	return getMissing() == "";
end

function getMissing()
	local t = {};
	if not getTarget() then table.insert(t, "a class"); end
	if getTarget() and needsHPRoll() and L.hp == nil then table.insert(t, "hit points (roll them)"); end
	if getTarget() and not isTabDone("spells") then table.insert(t, "spells"); end
	return table.concat(t, ", ");
end

function showTab(sTab)
	if not _wMain then
		return;
	end
	for _, s in ipairs(TABS) do
		local c = _wMain["sub_" .. s];
		if c then
			c.setVisible(s == sTab);
			if s == sTab and c.subwindow and c.subwindow.onPageShow then
				c.subwindow.onPageShow();
			end
		end
	end
	L.tab = sTab;
	refreshTabs();
end

function refreshTabs()
	if not _wMain or not _wMain.sub_tabs or not _wMain.sub_tabs.subwindow then
		return;
	end
	local w = _wMain.sub_tabs.subwindow;
	local tNames = { class = "Class", hp = "Hit Points", spells = "Spells", finish = "Finish" };
	for _, s in ipairs(TABS) do
		local c = w["tab_" .. s];
		if c then
			c.setStateText(0, tNames[s]);
			c.setFrame(s == L.tab and "buttondown" or "buttonup", 5, 5, 5, 5);
			-- Badge as in the creation wizard: "!" while the step needs something, a check when done.
			local bDone = (s == "finish") and (#getWarnings() == 0) or isTabDone(s);
			local sIcon = bDone and "button_dialog_ok_down" or "ccwiz_alert";
			local cBadge = c.findWidget("cclevelup_badge");
			if cBadge then
				cBadge.setBitmap(sIcon);
			else
				c.addBitmapWidget({ name = "cclevelup_badge", icon = sIcon, position = "bottomright", x = -6, y = -6, w = 16, h = 16 });
			end
		end
	end
	if w.tab_spells then
		w.tab_spells.setVisible(#getCasterSets() > 0);
	end
end

function refreshAll()
	if _wMain and L.tab then
		local c = _wMain["sub_" .. L.tab];
		if c and c.subwindow and c.subwindow.onPageShow then
			c.subwindow.onPageShow();
		end
	end
	refreshTabs();
end

--
-- Finish
--

function getHPGain()
	if L.hp ~= nil then
		return L.hp;
	end
	local _, nFlat = getHPPlan();
	return nFlat;
end

-- Cards for the Class page once a class is chosen (5e wizard: only what the
-- new level brings): each new class ability with its text, then notes.
function getFeatureCards()
	local t = {};
	local nodeTarget = getTarget();
	if not nodeTarget then
		return t;
	end
	for _, v in ipairs(getAbilitiesAt(nodeTarget, getToLevel())) do
		table.insert(t, { title = string.format("(Level %02d)  %s", getToLevel(), DB.getValue(v, "name", "")),
			text = CCWizard.plainText(DB.getValue(v, "text", "")), open = true });
	end
	table.insert(t, { title = "What the level brings", text = describeLevel(), open = true });
	table.insert(t, { title = "Experience", text = getXPNote(), open = true });
	return t;
end

-- Plain words for each thing still to do (Finish page warnings, tab badges).
function getWarnings()
	local t = {};
	if not getTarget() then
		table.insert(t, "Choose the class to advance");
		return t;
	end
	if needsHPRoll() and L.hp == nil then
		table.insert(t, "Roll hit points");
	end
	if not isTabDone("spells") then
		table.insert(t, "Choose spells");
	end
	return t;
end

function getEntryRows()
	return getClassRows();
end

function describeSummary()
	local nodeChar = getChar();
	if not getTarget() then
		return "Choose a class on the Class page.";
	end
	local t = {};
	if L.mode == "dual" then
		table.insert(t, string.format("Dual class: %s adds %s at 1st level (%s keeps advancing; experience is divided equally).",
			DB.getValue(nodeChar, "name", ""), getTargetName(), getSlotName("slot1")));
	elseif L.mode == "reclass" then
		table.insert(t, describeReclass());
	else
		table.insert(t, string.format("%s: %s %d -> %d.", DB.getValue(nodeChar, "name", ""), getTargetName(), getFromLevel(), getToLevel()));
	end
	if needsHPRoll() then
		table.insert(t, L.hp and string.format("Hit points: +%d.", L.hp) or "Hit points: not rolled yet.");
	else
		local _, nFlat, sNote = getHPPlan();
		table.insert(t, nFlat > 0 and string.format("Hit points: +%d.", nFlat) or ("Hit points: none. " .. sNote));
	end
	local tNew = getNewAbilities();
	if #tNew > 0 then table.insert(t, "New abilities: " .. table.concat(tNew, ", ") .. "."); end
	local tSpells = {};
	for sPath in pairs(L.spells) do table.insert(tSpells, DB.getValue(DB.findNode(sPath), "name", "")); end
	table.sort(tSpells);
	if #tSpells > 0 then table.insert(t, "New spells: " .. table.concat(tSpells, ", ") .. "."); end
	table.insert(t, getXPNote());
	local sMissing = getMissing();
	if sMissing ~= "" then table.insert(t, "Still needed: " .. sMissing .. "."); end
	return table.concat(t, "\n");
end

local function shortcut(sClass, sPath)
	return { getType = function() return "shortcut"; end, isType = function(s) return s == "shortcut"; end,
		getShortcutData = function() return sClass, sPath; end, getDatabaseNode = function() return DB.findNode(sPath); end };
end

-- Sets the original class's level through the official Character Builder
-- (abilities, base to hit, saves, experience needed), its hit point roll off.
function setOfficialLevel(nodeChar, nodeClass, nLevel)
	local w = Interface.openWindow("charsheet", nodeChar);
	if not w or not w.onDrop then
		return false, "the character sheet could not be opened";
	end
	w.onDrop(0, 0, shortcut("referenceclass", DB.getValue(nodeClass, "officialpath", "")));
	local wPopup = Interface.findWindow("class_drop_popup", DB.getPath(nodeChar, "popup"));
	if not wPopup then
		-- The builder cannot read this class's table (the Backpack's Spell Caster
		-- variants): the wizard sets the level itself.
		CCWizard.setLevelWithoutLoader(nodeChar, nodeClass, nLevel, nLevel);
		return true;
	end
	wPopup.content.subwindow.new_level.setValue(tostring(nLevel));
	if wPopup.roll_hp then
		wPopup.roll_hp.setValue("no_roll");
	end
	wPopup.accept.onButtonPress();
	if DB.getValue(nodeChar, "classes.slot1.level", 0) ~= nLevel then
		wPopup = Interface.findWindow("class_drop_popup", DB.getPath(nodeChar, "popup"));
		if wPopup then
			wPopup.close();
		end
		-- Past the printed rows (the Backpack prints 1-12 and "13+"): the
		-- wizard sets the level itself.
		CCWizard.setLevelWithoutLoader(nodeChar, nodeClass, nLevel, nLevel);
	end
	return true;
end

function addHP(nodeChar, sSlot, nLevel, nGain)
	DB.setValue(nodeChar, "hp.total", "number", DB.getValue(nodeChar, "hp.total", 0) + nGain);
	-- The log names its class: a class dropped on the sheet in its place makes it stale.
	local sClass = getSlotName(sSlot, nodeChar);
	if DB.getValue(nodeChar, "classes." .. sSlot .. ".hplogclass", "") ~= sClass then
		local nodeOld = DB.getChild(nodeChar, "classes." .. sSlot .. ".hplog");
		if nodeOld then
			DB.deleteNode(nodeOld);
		end
		DB.setValue(nodeChar, "classes." .. sSlot .. ".hplogclass", "string", sClass);
	end
	DB.setValue(nodeChar, "classes." .. sSlot .. ".hplog.l" .. nLevel, "number", nGain);
end

-- Hit points a level gave: from the log, else the level's average (dice
-- rounded up, plus Con) or its fixed bonus.
function getLevelHP(nodeChar, sSlot, nodeClass, nLevel)
	local nodeLog = DB.getChild(nodeChar, "classes." .. sSlot .. ".hplog.l" .. nLevel);
	if nodeLog and DB.getValue(nodeChar, "classes." .. sSlot .. ".hplogclass", "") == getSlotName(sSlot, nodeChar) then
		return DB.getValue(nodeLog, "", 0);
	end
	local tDice, nFlat = CCWizard.getOfficialHPGain(nodeClass, nLevel);
	if #tDice == 0 then
		return nFlat;
	end
	local n = nFlat + getConBonus();
	for _, sDie in ipairs(tDice) do
		n = n + math.floor((tonumber(sDie:match("d(%d+)")) or 0) / 2) + 1;
	end
	return math.max(n, 1);
end

-- The second class's abilities on the sheet's ability list, levels nFrom..nTo.
function addSecondAbilities(nodeChar, nodeClass, nFrom, nTo)
	local sName = DB.getValue(nodeClass, "name", "");
	for n = nFrom, nTo do
		for _, v in ipairs(getAbilitiesAt(nodeClass, n)) do
			local nodeNew = DB.createChild(DB.createChild(nodeChar, "abilitylist"));
			DB.setValue(nodeNew, "name", "string", DB.getValue(v, "name", ""));
			DB.setValue(nodeNew, "type", "string", "Class Ability");
			DB.setValue(nodeNew, "source", "string", sName);
			DB.setValue(nodeNew, "level", "number", n);
			DB.setValue(nodeNew, "text", "formattedtext", DB.getValue(v, "text", ""));
			DB.setValue(nodeNew, "locked", "number", 1);
		end
	end
end

-- After the official loader runs, the second class's abilities are put back
-- if it removed them.
function restoreSecondAbilities(nodeChar)
	local sName = getSlotName("slot2", nodeChar);
	local nodeClass = sName ~= "" and findClassProxy(sName);
	if not nodeClass then
		return;
	end
	for _, v in pairs(DB.getChildren(nodeChar, "abilitylist")) do
		if lower(DB.getValue(v, "source", "")) == lower(sName) then
			return;
		end
	end
	addSecondAbilities(nodeChar, nodeClass, 1, getSlotLevel("slot2", nodeChar));
end

function setBetterBtH(nodeChar)
	local nOld = getBtH(findClassProxy(getSlotName("slot1", nodeChar)), getSlotLevel("slot1", nodeChar));
	local nNew = getBtH(findClassProxy(getSlotName("slot2", nodeChar)), getSlotLevel("slot2", nodeChar));
	DB.setValue(nodeChar, "attackbonus.base", "number", math.max(nOld, nNew));
end

-- A reclassed character's experience all goes to the new class: XP needed
-- is the new class's next level.
function setReclassXPNeeded(nodeChar, nodeClass)
	local nodeRow = CCWizard.getLevelRow(nodeClass, getSlotLevel("slot2", nodeChar) + 1);
	if nodeRow then
		DB.setValue(nodeChar, "expneeded", "number", DB.getValue(nodeRow, "xp", 0));
	end
end

-- Spells: each list's slots and picks into its class's spell block. tSets
-- is taken before the level changes (getCasterSets reads the level after this one).
function addSpells(nodeChar, nodeTarget, nLevel, tSets)
	for n, tSet in ipairs(tSets or getCasterSets()) do
		local nodeBlock = getSpellBlock(tSet.class, true);
		if tSet.slot == "slot2" then
			DB.setValue(nodeBlock, "caster_level", "number", getSlotLevel("slot2", nodeChar));
		end
		for i, nCount in pairs(tSet.slots) do
			DB.setValue(nodeBlock, "spellsavailable.availablelevel" .. i, "number", nCount);
		end
		for sPath, tPick in pairs(L.spells) do
			if tPick.set == n then
				local sSource = DB.getValue(DB.findNode(sPath), "officialpath", "");
				local nodeDest = DB.createChild(DB.createChild(nodeBlock, "levels.level" .. tPick.level .. ".spells"));
				DB.copyNode(DB.findNode(sSource), nodeDest);
				DB.setValue(nodeDest, "prepared", "number", 0);
				DB.setValue(nodeDest, "cast", "number", 0);
				DB.setValue(nodeDest, "shortcut", "windowreference", "spell", sSource);
			end
		end
	end
end

-- Reclass: the original class loses its level(s) and their hit points, a
-- deity-serving class left for another kind loses its abilities, primes swap.
function applyReclassLoss(nodeChar, nodeOld, nodeNew)
	local sOld = DB.getValue(nodeOld, "name", "");
	local nOld = getSlotLevel("slot1", nodeChar);
	local nLoss = getReclassLoss(sOld, DB.getValue(nodeNew, "name", ""));
	local nNew = math.max(nOld - nLoss, 1);
	if nNew < nOld then
		-- The official Character Builder only raises levels, so the lost
		-- levels come off here: level, the abilities they brought, their
		-- hit points, and the class's spells per day.
		local nLost = 0;
		for n = nNew + 1, nOld do
			nLost = nLost + getLevelHP(nodeChar, "slot1", nodeOld, n);
			local nodeLog = DB.getChild(nodeChar, "classes.slot1.hplog.l" .. n);
			if nodeLog then DB.deleteNode(nodeLog); end
		end
		DB.setValue(nodeChar, "classes.slot1.level", "number", nNew);
		DB.setValue(nodeChar, "hp.total", "number", math.max(DB.getValue(nodeChar, "hp.total", 0) - nLost, 1));
		for _, v in pairs(DB.getChildren(nodeChar, "abilitylist")) do
			if lower(DB.getValue(v, "source", "")) == lower(sOld) and DB.getValue(v, "level", 0) > nNew then
				DB.deleteNode(v);
			end
		end
		local nodeBlock = DB.getValue(nodeOld, "spellclass", "") ~= "" and getSpellBlock(sOld, false);
		if nodeBlock then
			DB.setValue(nodeBlock, "caster_level", "number", nNew);
			local tSlots = getSlots(nNew, nodeOld);
			for n = 0, 9 do
				if DB.getChild(nodeBlock, "spellsavailable.availablelevel" .. n) or tSlots[n] then
					DB.setValue(nodeBlock, "spellsavailable.availablelevel" .. n, "number", tSlots[n] or 0);
				end
			end
		end
	end
	if nLoss == 2 then
		for _, v in pairs(DB.getChildren(nodeChar, "abilitylist")) do
			if lower(DB.getValue(v, "source", "")) == lower(sOld) and DB.getValue(v, "type", "") == "Class Ability" then
				DB.deleteNode(v);
			end
		end
	end
	local bPrime, sPrime = hasClassPrime(nodeChar, nodeNew);
	if not bPrime then
		for _, s in ipairs(getClassPrimes(nodeOld)) do
			DB.setValue(nodeChar, "abilities." .. s .. ".prime", "number", 0);
		end
		DB.setValue(nodeChar, "abilities." .. sPrime .. ".prime", "number", 1);
	end
	return true;
end

function commit()
	local sMissing = getMissing();
	if sMissing ~= "" then
		ChatManager.SystemMessage("Level up: still needed: " .. sMissing .. ".");
		return false;
	end
	local nodeChar = getChar();
	local nodeTarget = getTarget();
	local nLevel = getToLevel();
	local tSets = getCasterSets();
	local nGain = getHPGain() or 0;
	local sSummary = describeSummary():gsub("\nStill needed.*", "");
	local sKind = getSecondKind(nodeChar);

	if L.mode == "levelup" and L.slot == "slot1" then
		local bOk, sErr = setOfficialLevel(nodeChar, nodeTarget, nLevel);
		if not bOk then
			ChatManager.SystemMessage("Level up: " .. sErr .. ".");
			return false;
		end
		addHP(nodeChar, "slot1", nLevel, nGain);
		restoreSecondAbilities(nodeChar);
		-- A multi-class second class rises with the first; a supporting class
		-- follows the principal (Adventurer's Backpack).
		local nodeSecond = getSlot2Proxy(nodeChar);
		if sKind == "multi" and nodeSecond then
			DB.setValue(nodeChar, "classes.slot2.level", "number", nLevel);
			addSecondAbilities(nodeChar, nodeSecond, nLevel, nLevel);
			setBetterBtH(nodeChar);
		elseif sKind == "enhanced" and nodeSecond then
			local sKey = DB.getValue(nodeChar, "classes.slot2.key", "");
			local nOld, nNew = getSlotLevel("slot2", nodeChar), CCClassRules.getSupportLevel(sKey, nLevel);
			if nNew > nOld then
				DB.setValue(nodeChar, "classes.slot2.level", "number", nNew);
				CCWizard.addOfficialAbilities(nodeChar, nodeSecond, nOld + 1, nNew, DB.getValue(nodeSecond, "name", ""), sKey);
			end
		end
	elseif L.mode == "levelup" then
		DB.setValue(nodeChar, "classes.slot2.level", "number", nLevel);
		addSecondAbilities(nodeChar, nodeTarget, nLevel, nLevel);
		if sKind == "reclass" then
			addHP(nodeChar, "slot2", nLevel, nGain);
			setBetterBtH(nodeChar);
			setReclassXPNeeded(nodeChar, nodeTarget);
		end
	else
		if L.mode == "reclass" then
			local nodeOld = findClassProxy(getSlotName("slot1", nodeChar));
			if nodeOld then
				local bOk, sErr = applyReclassLoss(nodeChar, nodeOld, nodeTarget);
				if not bOk then
					ChatManager.SystemMessage("Level up: " .. sErr .. ".");
					return false;
				end
			end
		end
		DB.setValue(nodeChar, "classes.slot2.name", "string", getTargetName());
		DB.setValue(nodeChar, "classes.slot2.level", "number", 1);
		DB.setValue(nodeChar, "classes.slot2.kind", "string", L.mode);
		-- Experience from here on is split (dual) or goes to the new class (reclass).
		DB.setValue(nodeChar, "classes.slot2.xpbase", "number", DB.getValue(nodeChar, "exp", 0));
		DB.setValue(nodeChar, "classes.slot2.officialpath", "string", DB.getValue(nodeTarget, "officialpath", ""));
		addSecondAbilities(nodeChar, nodeTarget, 1, 1);
		if L.mode == "reclass" then
			addHP(nodeChar, "slot2", 1, nGain);
			setBetterBtH(nodeChar);
			setReclassXPNeeded(nodeChar, nodeTarget);
		end
	end
	addSpells(nodeChar, nodeTarget, nLevel, tSets);
	-- XP needed for combined classes (the loader set the first class's alone).
	CCWizard.setOfficialXPNeeded(nodeChar);
	Comm.deliverChatMessage({ font = "systemfont", text = "[LEVEL UP] " .. sSummary });
	if _wMain then
		_wMain.close();
	end
	return true;
end
