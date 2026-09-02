------------------------------------------------------------------------------
--	FILE:	 West_vs_East.lua
--	AUTHOR:  Bob Thomas
--	PURPOSE: Regional map script - Designed to pit two teams against each other
--	         with a strip of water dividing the map east from west.
------------------------------------------------------------------------------
--	Copyright (c) 2010 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

include("DEFMapGeneratorW8");
include("DEFMultilayeredFractalW");
include("DEFFeatureGeneratorW");
include("DEFTerrainGeneratorW");

local OPT_CENTER_SPLIT = 1;
local OPT_SNOW_BARRIER = 2;
local OPT_FRONT_MOUNTAIN = 3;
local SPLIT_SNOW = 1;
local SPLIT_WRAP = 2;
local SPLIT_NOWRAP = 3;
local DEF_WORLD_AGE = 2;
local DEF_TEMPERATURE = 2;
local DEF_RAINFALL = 2;
local DEF_RESOURCES = 4;
local DEF_TEAM = 1;
local DEF_FRONTLINE = 7;
local DEF_BACK = 7;
local DEF_MIRRORED = 1;
local DEF_TOPBOTTOM = 7;
local DEF_NATURAL_WONDERS = 16;

------------------------------------------------------------------------------
function GetResourceSetting()
	return DEF_RESOURCES;
end
------------------------------------------------------------------------------
function GetMapScriptInfo()
	return {
		Name = "### Weevee Map - v11",
		Description = "HellBlazers Teamer Map combined with Skirmish. Uses Leszek Deska's mirroring algorithm. Frankensteined together by Meota.",
		SupportsMultiplayer = true,
		IconIndex = 18,
		CustomOptions = {
			{
				Name = "Center Split",
				Values = {
					"Snow",
					"Snow v2 (wrap) - Default",
					"Snow v2 (no wrap)",
				},
				DefaultValue = 1,
				SortPriority = -99,
			},
			{
				Name = "Snow Barrier Width",
				Values = {
					"0",
					"2",
					"4",
					"6",
					"Random (2-6) - Default",
				},
				DefaultValue = 5,
				SortPriority = -98,
			},
			{
				Name = "Front Mountain %",
				Values = {
					"20%",
					"25%",
					"30%",
					"35% - Default",	
					"40%",
					"45%",
					"50%",
				},
				DefaultValue = 4,
				SortPriority = -97,
			},
		},
	}
end
------------------------------------------------------------------------------
function IsSnowWrapX()
	return Map.GetCustomOption(OPT_CENTER_SPLIT) == SPLIT_WRAP;
end
------------------------------------------------------------------------------
function IsSnowNoWrap()
	return Map.GetCustomOption(OPT_CENTER_SPLIT) == SPLIT_NOWRAP;
end
------------------------------------------------------------------------------
function IsOldSnow()
	return Map.GetCustomOption(OPT_CENTER_SPLIT) == SPLIT_SNOW;
end
------------------------------------------------------------------------------
function IsSnowBarrier()
	local ops = Map.GetCustomOption(OPT_CENTER_SPLIT);
	return ops == SPLIT_WRAP or ops == SPLIT_NOWRAP;
end
------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function GetMapInitData(worldSize)
	-- This function can reset map grid sizes or world wrap settings.
	--
	-- East vs West is an extremely compact multiplayer map type.
	local worldsizes = {
		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = {34, 14},
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = {40, 22},
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {44, 26},
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = {50, 30},
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = {52, 32},
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = {64, 40}
		}
	local grid_size = worldsizes[worldSize];
	--
	local world = GameInfo.Worlds[worldSize];
	if(world ~= nil) then
		local w = grid_size[1] - Map.Rand(5, "Map Width Variance");
		local h = grid_size[2] - Map.Rand(5, "Map Height Variance");
		print("Map canvas:", w, "x", h, "(base", grid_size[1], "x", grid_size[2], ")");
		return {
			Width = w,
			Height = h,
			WrapX = IsSnowWrapX(),
		};
	end
end
-------------------------------------------------------------------------------
local snowWrapWidthResolved = false;
local snowWrapBackWidth = 0;
local snowWrapCenterWidth = 0;
function ResolveSnowWrapWidths()
	if snowWrapWidthResolved then
		return snowWrapBackWidth, snowWrapCenterWidth;
	end
	snowWrapWidthResolved = true;
	local ops = Map.GetCustomOption(OPT_SNOW_BARRIER);
	if IsSnowWrapX() == false then
		snowWrapBackWidth = 0;
		if ops == 5 then
			snowWrapCenterWidth = 2 * (Map.Rand(3, "Snow Wrap Center Width") + 1);
		else
			snowWrapCenterWidth = (ops - 1) * 2;
		end
		print("Snow Barrier widths (no wrap): wrap=0 center=", snowWrapCenterWidth);
		return snowWrapBackWidth, snowWrapCenterWidth;
	end
	if ops == 5 then
		repeat
			snowWrapBackWidth = 2 * (Map.Rand(3, "Snow Wrap Back Width") + 1);
			snowWrapCenterWidth = 2 * (Map.Rand(3, "Snow Wrap Center Width") + 1);
		until snowWrapBackWidth < 6 or snowWrapCenterWidth < 6;
		print("Snow Wrap widths (random): wrap=", snowWrapBackWidth, " center=", snowWrapCenterWidth);
	else
		local n = (ops - 1) * 2;
		snowWrapBackWidth = n;
		snowWrapCenterWidth = n;
	end
	return snowWrapBackWidth, snowWrapCenterWidth;
end
------------------------------------------------------------------------------
local climateScaleResolved = false;
local climateScale = 0.8;
local climateVariation = nil;
function ResolveClimateScale()
	if climateScaleResolved then
		return climateScale, climateVariation;
	end
	climateScaleResolved = true;
	local iW, iH = Map.GetGridSize();
	local oneRow = 0.8 / (iH / 2);
	climateScale = 0.8 + (Map.Rand(3, "Climate Scale") - 1) * oneRow;
	if climateScale > 0.95 then
		climateScale = 0.95;
	end
	climateVariation = Fractal.Create(iW, iH, 3, Map.GetFractalFlags(), -1, -1);
	print("Climate scale:", climateScale);
	return climateScale, climateVariation;
end
------------------------------------------------------------------------------
function GetClimateLatitudeAtPlot(iX, iY)
	local scale, variation = ResolveClimateScale();
	local iW, iH = Map.GetGridSize();
	local lat = math.abs((iH / 2) - iY) / (iH / 2);
	lat = lat + (128 - variation:GetHeight(iX, iY)) / (255.0 * 5.0);
	lat = scale * (math.clamp(lat, 0, 1));
	return lat;
end
------------------------------------------------------------------------------
function GetSnowWrapWaterBounds(iW)
	local wrapN, centerN = ResolveSnowWrapWidths();
	local wrapHalf = wrapN / 2;
	local centerHalf = centerN / 2;
	local mid = math.floor(iW / 2);
	local minX = wrapHalf + 3;
	local maxX = mid - centerHalf - 4;
	return minX, maxX;
end
------------------------------------------------------------------------------
function WaterAllowedAtX(x)
	local iW = Map.GetGridSize();
	local wrapN, centerN = ResolveSnowWrapWidths();
	local wrapHalf = wrapN / 2;
	local centerHalf = centerN / 2;
	local mid = math.floor(iW / 2);
	if wrapHalf > 0 then
		if x <= (wrapHalf + 2) then
			return false
		end
		if x >= (iW - wrapHalf - 3) then
			return false
		end
	end
	if centerHalf > 0 then
		if x >= (mid - centerHalf - 3) and x <= (mid + centerHalf - 1 + 3) then
			return false
		end
	end
	return true
end
------------------------------------------------------------------------------
function ScrubWaterNearSnow()
	if IsSnowBarrier() == false then
		return
	end
	local iW, iH = Map.GetGridSize();
	local y = 0;
	while y < iH do
		local x = 0;
		while x < iW do
			if WaterAllowedAtX(x) == false then
				local plot = Map.GetPlot(x, y);
				if plot ~= nil and plot:GetPlotType() == PlotTypes.PLOT_OCEAN then
					plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
				end
			end
			x = x + 1;
		end
		y = y + 1;
	end
end
------------------------------------------------------------------------------
function GetSnowWrapColumns(iW)
	local cols = {};
	local wrapN, centerN = ResolveSnowWrapWidths();
	if wrapN > 0 then
		local half = wrapN / 2;
		for x = 0, half - 1 do
			table.insert(cols, x);
		end
		for x = iW - half, iW - 1 do
			table.insert(cols, x);
		end
	end
	if centerN > 0 then
		local half = centerN / 2;
		local mid = math.floor(iW / 2);
		for x = mid - half, mid + half - 1 do
			table.insert(cols, x);
		end
	end
	return cols;
end
------------------------------------------------------------------------------
function GetSnowWrapTundraColumns(iW)
	local cols = {};
	local wrapN, centerN = ResolveSnowWrapWidths();
	local mid = math.floor(iW / 2);
	if wrapN > 0 then
		local half = wrapN / 2;
		table.insert(cols, half);
		table.insert(cols, iW - half - 1);
	end
	if centerN > 0 then
		local half = centerN / 2;
		table.insert(cols, mid - half - 1);
		table.insert(cols, mid + half);
	end
	return cols;
end
------------------------------------------------------------------------------
function GetSnowWrapLandMountainXs(iW)
	local wrapN = ResolveSnowWrapWidths();
	local wrapHalf = wrapN / 2;
	local firstLand = wrapHalf + 1;
	local xWest = 3;
	if xWest < firstLand then
		xWest = firstLand;
	end
	return xWest, iW - 1 - xWest;
end
------------------------------------------------------------------------------
function ShapeNoWrapBackstrip(plotTypes, iW, iH)
	local evenN = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
	local oddN = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};
	local depth = 2;
	local y = 0;
	while y < iH do
		local step = Map.Rand(3, "NoWrap Coast Walk") - 1;
		depth = depth + step;
		if depth < 1 then
			depth = 1;
		end
		if depth > 3 then
			depth = 3;
		end
		local x = 0;
		while x <= 2 do
			local i = y * iW + x + 1;
			if x < depth then
				plotTypes[i] = PlotTypes.PLOT_OCEAN;
			elseif x <= 1 then
				plotTypes[i] = PlotTypes.PLOT_LAND;
			end
			x = x + 1;
		end
		y = y + 1;
	end
	local nIslands = 2 + Map.Rand(3, "NoWrap Back Islands");
	local placed = 0;
	local attempts = 0;
	while placed < nIslands and attempts < 50 do
		attempts = attempts + 1;
		local ySpan = iH - 2;
		if ySpan < 1 then
			ySpan = 1;
		end
		local iy = 1 + Map.Rand(ySpan, "NoWrap Island Y");
		local ix = Map.Rand(2, "NoWrap Island X");
		local i = iy * iW + ix + 1;
		if plotTypes[i] == PlotTypes.PLOT_OCEAN then
			local adjMainland = false;
			local dirs = evenN;
			if iy % 2 == 1 then
				dirs = oddN;
			end
			local d = 1;
			while d <= 6 do
				local nx = ix + dirs[d][1];
				local ny = iy + dirs[d][2];
				if ny >= 0 and ny < iH and nx >= 0 and nx < iW then
					if plotTypes[ny * iW + nx + 1] ~= PlotTypes.PLOT_OCEAN then
						if nx >= 2 then
							adjMainland = true;
						end
					end
				end
				d = d + 1;
			end
			if adjMainland == false then
				if Map.Rand(3, "NoWrap Island Hills") == 0 then
					plotTypes[i] = PlotTypes.PLOT_HILLS;
				else
					plotTypes[i] = PlotTypes.PLOT_LAND;
				end
				placed = placed + 1;
				if Map.Rand(2, "NoWrap Island Pair") == 0 then
					local pd = 1 + Map.Rand(6, "NoWrap Island PairDir");
					local px = ix + dirs[pd][1];
					local py = iy + dirs[pd][2];
					if py >= 1 and py < iH - 1 and px >= 0 and px <= 1 then
						local pi = py * iW + px + 1;
						if plotTypes[pi] == PlotTypes.PLOT_OCEAN then
							local pairMainland = false;
							local pdirs = evenN;
							if py % 2 == 1 then
								pdirs = oddN;
							end
							local e = 1;
							while e <= 6 do
								local ex = px + pdirs[e][1];
								local ey = py + pdirs[e][2];
								if ey >= 0 and ey < iH and ex >= 0 and ex < iW then
									if plotTypes[ey * iW + ex + 1] ~= PlotTypes.PLOT_OCEAN then
										if ex >= 2 then
											pairMainland = true;
										end
									end
								end
								e = e + 1;
							end
							if pairMainland == false then
								plotTypes[pi] = plotTypes[i];
							end
						end
					end
				end
			end
		end
	end
	y = 0;
	while y < iH do
		local x = 0;
		while x <= 3 do
			local mx = iW - x - 1;
			local my = iH - y - 1;
			plotTypes[my * iW + mx + 1] = plotTypes[y * iW + x + 1];
			x = x + 1;
		end
		y = y + 1;
	end
end
-------------------------------------------------------------------------------
local ASP_GenerateGlobalResourcePlotLists = AssignStartingPlots.GenerateGlobalResourcePlotLists;
function AssignStartingPlots:GenerateGlobalResourcePlotLists()
	ASP_GenerateGlobalResourcePlotLists(self);
	if IsSnowBarrier() == false then
		return
	end
	local iW, iH = Map.GetGridSize();
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local i = y * iW + x + 1;
			if self.playerCollisionData[i] ~= true then
				local plot = Map.GetPlot(x, y);
				if plot:GetPlotType() == PlotTypes.PLOT_OCEAN
					and plot:GetResourceType(-1) == -1
					and plot:GetFeatureType() ~= FeatureTypes.FEATURE_ICE
					and plot:GetFeatureType() ~= self.feature_atoll
					and plot:GetTerrainType() == TerrainTypes.TERRAIN_COAST
					and plot:IsLake() then
					table.insert(self.coast_list, i);
					if plot:IsAdjacentToLand() and isMiddle(x) then
						table.insert(self.front_coast_list, i);
					end
				end
			end
		end
	end
	self.coast_list = GetShuffledCopyOfTable(self.coast_list);
	self.front_coast_list = GetShuffledCopyOfTable(self.front_coast_list);
	self.coast_next_to_land_list = GetShuffledCopyOfTable(self.coast_next_to_land_list);
end
------------------------------------------------------------------------------
local ASP_ExaminePlotForNaturalWondersEligibility = AssignStartingPlots.ExaminePlotForNaturalWondersEligibility;
function AssignStartingPlots:ExaminePlotForNaturalWondersEligibility(x, y)
	if ASP_ExaminePlotForNaturalWondersEligibility(self, x, y) == false then
		return false
	end
	if IsSnowBarrier() then
		local iW = Map.GetGridSize();
		local snowCols = GetSnowWrapColumns(iW);
		local tundraCols = GetSnowWrapTundraColumns(iW);
		local i = 1;
		while snowCols[i] ~= nil do
			if x == snowCols[i] then
				return false
			end
			i = i + 1;
		end
		i = 1;
		while tundraCols[i] ~= nil do
			if x == tundraCols[i] then
				return false
			end
			i = i + 1;
		end
	end
	return true
end
------------------------------------------------------------------------------
function PurgeNearStartLakeFish()
	if IsSnowBarrier() == false then
		return
	end
	local fishID = GameInfoTypes["RESOURCE_FISH"];
	if fishID == nil then
		return
	end
	local iW, iH = Map.GetGridSize();
	local starts = {};
	for i = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		local player = Players[i];
		if player ~= nil and player:IsAlive() and player:GetStartingPlot() ~= nil then
			table.insert(starts, player:GetStartingPlot());
		end
	end
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local plot = Map.GetPlot(x, y);
			if plot:GetResourceType(-1) == fishID and plot:IsWater() then
				local area = plot:Area();
				if area ~= nil and area:GetNumTiles() <= 6 then
					for _, startPlot in ipairs(starts) do
						if Map.PlotDistance(x, y, startPlot:GetX(), startPlot:GetY()) <= 4 then
							plot:SetResourceType(-1);
							break
						end
					end
				end
			end
		end
	end
end
-------------------------------------------------------------------------------
function MultilayeredFractal:GeneratePlotsByRegion()
	-- Sirian's MultilayeredFractal controlling function.
	-- You -MUST- customize this function for each script using MultilayeredFractal.
	--
	-- This implementation is specific to West vs East.
	local iW, iH = Map.GetGridSize();
	local fracFlags = {};
	local SplitOps = Map.GetCustomOption(OPT_CENTER_SPLIT);

	-- Fill all rows with land plots.
	self.wholeworldPlotTypes = table.fill(PlotTypes.PLOT_LAND, iW * iH);

	if false then -- Ocean Strip
	
		-- Add strip of ocean to middle of map --- Always start with this for civ placements
		for y = 0, iH - 1 do
			for x = math.floor(iW / 2) - 2, math.floor(iW / 2) + 1 do
				local plotIndex = y * iW + x + 1;
				--if y >= math.floor(iH / 2) - 2 and y <= math.floor(iH / 2) + 1 then
					--if x == math.floor(iW / 2) or x == math.floor(iW / 2) - 1 then
						--self.wholeworldPlotTypes[plotIndex] = PlotTypes.PLOT_OCEAN;
					--end
				--else
					self.wholeworldPlotTypes[plotIndex] = PlotTypes.PLOT_OCEAN;
				--end
			end
		end
	elseif false then -- Landbridges
		
		-- Add strip of ocean to middle of map --- Always start with this for civ placements
		for y = 4, iH - 5 do
			for x = math.floor(iW / 2) - 2, math.floor(iW / 2) + 1 do
				local plotIndex = y * iW + x + 1;
				if y >= math.floor(iH / 2) - 2 and y <= math.floor(iH / 2) + 1 then
					if x == math.floor(iW / 2) or x == math.floor(iW / 2) - 1 then
						--self.wholeworldPlotTypes[plotIndex] = PlotTypes.PLOT_OCEAN;
					end
				else
					self.wholeworldPlotTypes[plotIndex] = PlotTypes.PLOT_OCEAN;
				end
			end
		end
	end
	if false then -- Barrier Islands
		
		-- Add strip of ocean to middle of map --- Always start with this for civ placements
		for y = 0, iH - 1 do
			for x = math.floor(iW / 2) - 2, math.floor(iW / 2) + 1 do
				local plotIndex = y * iW + x + 1;
					self.wholeworldPlotTypes[plotIndex] = PlotTypes.PLOT_OCEAN;
			end
		end
		local x_middle = math.floor(iW / 2) - 5;
		for y = 0, iH do
			local plotIndex = y * iW + x_middle + 1;
			self.wholeworldPlotTypes[plotIndex] = PlotTypes.PLOT_OCEAN;
		end
		local outer_half = {};
		for loop = 1, iH - 2 do
			table.insert(outer_half, loop);
		end
		local outer_shuffled = GetShuffledCopyOfTable(outer_half)
		local iNumOuterPerColumn = math.floor(iH * 0.67);
		local x_outer = math.floor((iW / 2) - 4);
		for loop = 1, iNumOuterPerColumn do
			local y_outer = outer_shuffled[loop];
			local i_outer_plot = y_outer * iW + x_outer + 1;
			self.wholeworldPlotTypes[i_outer_plot] = PlotTypes.PLOT_OCEAN;
		end
		local x_outerst = math.floor((iW / 2) - 3);
		local iNumOuterstPerColumn = math.floor(iH * 0.33);
		for loop = 1, iNumOuterstPerColumn do
			local y_outerst = outer_shuffled[loop];
			local i_outerst_plot = y_outerst * iW + x_outerst + 1;
			self.wholeworldPlotTypes[i_outerst_plot] = PlotTypes.PLOT_OCEAN;
		end
		local inner_half = {};
		for loop = 1, iH - 2 do
			table.insert(inner_half, loop);
		end
		local inner_shuffled = GetShuffledCopyOfTable(inner_half)
		local iNumInnerPerColumn = math.max(math.floor(iH * 0.33), math.floor((iH / 3) - 1));
		local x_inner = math.floor((iW / 2) - 6);	
		for loop = 1, iNumInnerPerColumn do
			local y_inner = inner_shuffled[loop];
			local i_inner_plot = y_inner * iW + x_inner + 1;
			self.wholeworldPlotTypes[i_inner_plot] = PlotTypes.PLOT_OCEAN;
		end
		local x_innerst = math.floor((iW / 2) - 7);
		local iNumInnerstPerColumn = math.floor(iH * 0.17);
		for loop = 1, iNumInnerstPerColumn do
			local y_innerst = inner_shuffled[loop];
			local i_innerst_plot = y_innerst * iW + x_innerst + 1;
			self.wholeworldPlotTypes[i_innerst_plot] = PlotTypes.PLOT_OCEAN;
		end
	end
	if not IsSnowWrapX() then
		for x = 0, 0 do
			for y = 1, iH - 2 do
				local i = y * iW + x + 1;
				self.wholeworldPlotTypes[i] = PlotTypes.PLOT_HILLS;
			end
		end
		

		for x = 0, 0 do
			local i = x + 1;
			self.wholeworldPlotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
			local i = (iH - 1) * iW + x + 1;
			self.wholeworldPlotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
		end
		local west_half = {};
		for loop = 1, iH - 2 do
			table.insert(west_half, loop);
		end
		local west_shuffled = GetShuffledCopyOfTable(west_half)
		local iNumMountainsPerColumn = math.max(math.floor(iH * 0.33), math.floor((iH / 3) - 1));
		local x_west = 3;
		if IsSnowNoWrap() then
			x_west = 2;
		end
		for loop = 1, iNumMountainsPerColumn do
			local y_west = west_shuffled[loop];
			local i_west_plot = y_west * iW + x_west + 1;
			self.wholeworldPlotTypes[i_west_plot] = PlotTypes.PLOT_OCEAN;
		end
		-- Add strips of ocean to the world borders.
		local rimW = 2;
		if IsSnowNoWrap() then
			rimW = 1;
		end
		for y = 0, iH do
			for x = 0, rimW do
				local plotIndex = y * iW + x + 1;
				self.wholeworldPlotTypes[plotIndex] = PlotTypes.PLOT_OCEAN;
			end
		end
		for y = 0, iH do
			for x = iW - 1 - rimW, iW do
				local plotIndex = y * iW + x + 1;
				self.wholeworldPlotTypes[plotIndex] = PlotTypes.PLOT_OCEAN;
			end
		end
	end

	-- Add lakes.
	local lakesFrac = Fractal.Create(iW, iH, lake_grain, fracFlags, 6, 6);
	local iLakesThreshold = lakesFrac:GetHeight(92);
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local i = y * iW + x + 1; -- add one because Lua arrays start at 1
			local lakeVal = lakesFrac:GetHeight(x, y);
			if lakeVal >= iLakesThreshold then
				--self.wholeworldPlotTypes[i] = PlotTypes.PLOT_OCEAN;
			end
		end
	end


	-- Land and water are set. Now apply hills and mountains.
	local world_age = DEF_WORLD_AGE;
	if world_age == 4 then
		world_age = 1 + Map.Rand(3, "Random World Age - Lua");
	end
	local args = {world_age = world_age};
	self:ApplyTectonics(args)
	
	if false then -- Skirmish
		for x = iW / 2 - 2, iW / 2 + 1 do
			for y = 1, iH - 2 do
				local i = y * iW + x + 1;
				self.wholeworldPlotTypes[i] = PlotTypes.PLOT_LAND;
			end
		end
		for x = iW / 2 - 2, iW / 2 + 1 do
			local i = x + 1;
			self.wholeworldPlotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
			local i = (iH - 1) * iW + x + 1;
			self.wholeworldPlotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
		end
		local west_half, east_half = {}, {};
		for loop = 1, iH - 2 do
			table.insert(west_half, loop);
			table.insert(east_half, loop);
		end
		local west_shuffled = GetShuffledCopyOfTable(west_half)
		local east_shuffled = GetShuffledCopyOfTable(east_half)
		local iNumMountainsPerColumn = math.max(math.floor(iH * 0.225), math.floor((iH / 4) - 1));
		local x_west, x_east = iW / 2 - 1, iW / 2;
		for loop = 1, iNumMountainsPerColumn do
			local y_west, y_east = west_shuffled[loop], iH - 1- west_shuffled[loop];
			local i_west_plot = y_west * iW + x_west + 1;
			local i_east_plot = y_east * iW + x_east + 1;
			self.wholeworldPlotTypes[i_west_plot] = PlotTypes.PLOT_MOUNTAIN;
			self.wholeworldPlotTypes[i_east_plot] = PlotTypes.PLOT_MOUNTAIN;
		end
	end
	if IsOldSnow() then
		for x = iW / 2 - 4, iW / 2 + 3 do
			for y = 0, iH - 1 do
				local i = y * iW + x + 1;
				self.wholeworldPlotTypes[i] = PlotTypes.PLOT_LAND;
			end
		end
		local west_half, east_half = {}, {};
		for loop = 1, iH - 2 do
			table.insert(west_half, loop);
			table.insert(east_half, loop);
		end
		local west_shuffled = GetShuffledCopyOfTable(west_half)
		local east_shuffled = GetShuffledCopyOfTable(east_half)

		local mountainOps = Map.GetCustomOption(OPT_FRONT_MOUNTAIN)
		local mountainDensity = .20 + .05 * mountainOps

		local iNumMountainsPerColumn = math.floor(iH * mountainDensity);
		local x_west, x_east = iW / 2 - 4, iW / 2 + 3;
		for loop = 1, iNumMountainsPerColumn do
			local y_west, y_east = west_shuffled[loop], iH - 1- west_shuffled[loop];
			local i_west_plot = y_west * iW + x_west + 1;
			local i_east_plot = y_east * iW + x_east + 1;
			self.wholeworldPlotTypes[i_west_plot] = PlotTypes.PLOT_MOUNTAIN;
			self.wholeworldPlotTypes[i_east_plot] = PlotTypes.PLOT_MOUNTAIN;
		end
	end
	if IsSnowBarrier() then
		local west_half = {};
		for loop = 1, iH - 2 do
			table.insert(west_half, loop);
		end
		local mountainOps = Map.GetCustomOption(OPT_FRONT_MOUNTAIN)
		local mountainDensity = .20 + .05 * mountainOps
		local iNumMountainsPerColumn = math.floor(iH * mountainDensity);

		local front_shuffled = GetShuffledCopyOfTable(west_half)
		local x_west, x_east = iW / 2 - 4, iW / 2 + 3;
		for loop = 1, iNumMountainsPerColumn do
			local y_west, y_east = front_shuffled[loop], iH - 1 - front_shuffled[loop];
			self.wholeworldPlotTypes[y_west * iW + x_west + 1] = PlotTypes.PLOT_MOUNTAIN;
			self.wholeworldPlotTypes[y_east * iW + x_east + 1] = PlotTypes.PLOT_MOUNTAIN;
		end

		if IsSnowWrapX() then
			local wrap_shuffled = GetShuffledCopyOfTable(west_half)
			local x_wrap_west, x_wrap_east = GetSnowWrapLandMountainXs(iW);
			for loop = 1, iNumMountainsPerColumn do
				local y_west, y_east = wrap_shuffled[loop], iH - 1 - wrap_shuffled[loop];
				self.wholeworldPlotTypes[y_west * iW + x_wrap_west + 1] = PlotTypes.PLOT_MOUNTAIN;
				self.wholeworldPlotTypes[y_east * iW + x_wrap_east + 1] = PlotTypes.PLOT_MOUNTAIN;
			end
		end

		-- Interior lakes + polar water. At least 3 columns from both snow seams.
		local minX, maxX = GetSnowWrapWaterBounds(iW);
		local function hexNeighbors(x, y)
			if y % 2 == 0 then
				return {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
			end
			return {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};
		end
		local polarIslandPlots = {};
		local polarRadius = 0;
		local polarCap = 0;
		local polarInland = 0;
		if minX <= maxX then
			local polarX = math.floor((minX + maxX) / 2);
			polarCap = Map.Rand(3, "Snow Wrap Polar Cap");
			if polarCap == 0 then
				polarCap = 0;
			else
				polarRadius = 3 + Map.Rand(3, "Snow Wrap Polar Inland");
				local maxIn = math.floor(iH / 4);
				if polarRadius > maxIn then
					polarRadius = maxIn;
				end
				if polarRadius < 3 then
					polarRadius = 3;
				end
				local polarY = 0;
				local yLo = 0;
				local yHi = polarRadius;
				if polarCap == 2 then
					polarY = iH - 1;
					yLo = iH - 1 - polarRadius;
					yHi = iH - 1;
				end
				local maxHalfW = math.min(polarX - minX, maxX - polarX);
				if maxHalfW < 1 then
					polarCap = 0;
				else
					local style = Map.Rand(3, "Snow Wrap Polar Shape");
					local halfW = 1;
					local inland = polarRadius;
					if style == 0 then
						halfW = 1 + Map.Rand(2, "Snow Wrap Polar SharpW");
						if halfW > maxHalfW then
							halfW = maxHalfW;
						end
					elseif style == 2 then
						halfW = maxHalfW;
						inland = 2 + Map.Rand(2, "Snow Wrap Polar WideIn");
						if polarCap == 1 then
							yHi = inland;
						else
							yLo = iH - 1 - inland;
						end
					else
						halfW = math.max(2, math.floor(maxHalfW / 2));
					end
					local seedX = polarX;
					if seedX < minX then
						seedX = minX;
					end
					if seedX > maxX then
						seedX = maxX;
					end
					local blob = {};
					table.insert(blob, {seedX, polarY});
					self.wholeworldPlotTypes[polarY * iW + seedX + 1] = PlotTypes.PLOT_OCEAN;
					local nBlob = 1;
					local target = 12 + Map.Rand(9, "Snow Wrap Polar Target");
					local step = 0;
					while nBlob < target do
						step = step + 1;
						if step > 80 then
							break
						end
						local candidates = {};
						local pIndex = 1;
						while pIndex <= nBlob do
							local p = blob[pIndex];
							local dirs = hexNeighbors(p[1], p[2]);
							local dIndex = 1;
							while dIndex <= 6 do
								local d = dirs[dIndex];
								local nx = p[1] + d[1];
								local ny = p[2] + d[2];
								local dx = nx - seedX;
								if dx < 0 then
									dx = 0 - dx;
								end
								if nx >= minX and nx <= maxX and ny >= yLo and ny <= yHi and dx <= halfW then
									local idx = ny * iW + nx + 1;
									if self.wholeworldPlotTypes[idx] ~= PlotTypes.PLOT_OCEAN then
										table.insert(candidates, {nx, ny, idx});
									end
								end
								dIndex = dIndex + 1;
							end
							pIndex = pIndex + 1;
						end
						local nCands = table.maxn(candidates);
						if nCands < 1 then
							break
						end
						local pick = candidates[Map.Rand(nCands, "Snow Wrap Polar Grow") + 1];
						self.wholeworldPlotTypes[pick[3]] = PlotTypes.PLOT_OCEAN;
						table.insert(blob, {pick[1], pick[2]});
						nBlob = nBlob + 1;
					end
					if nBlob >= 6 then
						local iIsland = 2;
						while iIsland <= nBlob do
							local t = blob[iIsland];
							local surrounded = true;
							local dirs = hexNeighbors(t[1], t[2]);
							local dIndex = 1;
							while dIndex <= 6 do
								local d = dirs[dIndex];
								local nx = t[1] + d[1];
								local ny = t[2] + d[2];
								if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
									if self.wholeworldPlotTypes[ny * iW + nx + 1] ~= PlotTypes.PLOT_OCEAN then
										surrounded = false;
									end
								end
								dIndex = dIndex + 1;
							end
							if surrounded == true then
								self.wholeworldPlotTypes[t[2] * iW + t[1] + 1] = PlotTypes.PLOT_HILLS;
								table.insert(polarIslandPlots, {t[1], t[2]});
								break
							end
							iIsland = iIsland + 1;
						end
					end
					polarInland = inland;
					print("Snow Wrap polar cap=" .. tostring(polarCap) .. " tiles=" .. tostring(nBlob));
				end
			end
		end
		-- Keep interior lakes off the polar cap that exists.
		local minY = 3;
		local maxY = iH - 4;
		if polarCap == 1 and polarInland > 0 then
			minY = polarInland + 2;
		elseif polarCap == 2 and polarInland > 0 then
			maxY = iH - 1 - (polarInland + 2);
		end
		local function inLakeRect(x, y)
			return x >= minX and x <= maxX and y >= minY and y <= maxY;
		end
		local function neighborsFit(x, y)
			for _, d in ipairs(hexNeighbors(x, y)) do
				if not inLakeRect(x + d[1], y + d[2]) then
					return false
				end
			end
			return true
		end
		if minX <= maxX and minY <= maxY then
			local nBodies = Map.Rand(4, "Snow Wrap Lake Count");
			for n = 1, nBodies do
				local lakeSize = 3 + Map.Rand(8, "Snow Wrap Lake Size");
				local circular = (Map.Rand(2, "Snow Wrap Lake Shape") == 0);
				local wantIsland = circular and lakeSize >= 6 and (Map.Rand(2, "Snow Wrap Lake Island") == 0);
				local seedX, seedY;
				for attempt = 1, 40 do
					local tx = minX + Map.Rand(maxX - minX + 1, "Snow Wrap Lake SeedX");
					local ty = minY + Map.Rand(maxY - minY + 1, "Snow Wrap Lake SeedY");
					local tidx = ty * iW + tx + 1;
					if self.wholeworldPlotTypes[tidx] ~= PlotTypes.PLOT_OCEAN then
						if (not wantIsland) or neighborsFit(tx, ty) then
							seedX, seedY = tx, ty;
							break
						end
					end
				end
				if seedX == nil and wantIsland then
					wantIsland = false;
					for attempt = 1, 40 do
						local tx = minX + Map.Rand(maxX - minX + 1, "Snow Wrap Lake SeedX");
						local ty = minY + Map.Rand(maxY - minY + 1, "Snow Wrap Lake SeedY");
						local tidx = ty * iW + tx + 1;
						if self.wholeworldPlotTypes[tidx] ~= PlotTypes.PLOT_OCEAN then
							seedX, seedY = tx, ty;
							break
						end
					end
				end
				if seedX ~= nil then
					if circular then
						local visited = {};
						local queue = {{seedX, seedY}};
						visited[seedY * iW + seedX] = true;
						local qi = 1;
						local painted = 0;
						while qi <= #queue and painted < lakeSize do
							local cx = queue[qi][1];
							local cy = queue[qi][2];
							qi = qi + 1;
							local skipSeed = wantIsland and cx == seedX and cy == seedY;
							if inLakeRect(cx, cy) then
								local idx = cy * iW + cx + 1;
								if (not skipSeed) and self.wholeworldPlotTypes[idx] ~= PlotTypes.PLOT_OCEAN then
									self.wholeworldPlotTypes[idx] = PlotTypes.PLOT_OCEAN;
									painted = painted + 1;
								end
								for _, d in ipairs(hexNeighbors(cx, cy)) do
									local nx = cx + d[1];
									local ny = cy + d[2];
									local nkey = ny * iW + nx;
									if inLakeRect(nx, ny) and visited[nkey] == nil then
										visited[nkey] = true;
										table.insert(queue, {nx, ny});
									end
								end
							end
						end
					else
						local blob = {{seedX, seedY}};
						self.wholeworldPlotTypes[seedY * iW + seedX + 1] = PlotTypes.PLOT_OCEAN;
						while #blob < lakeSize do
							local candidates = {};
							for _, p in ipairs(blob) do
								for _, d in ipairs(hexNeighbors(p[1], p[2])) do
									local nx = p[1] + d[1];
									local ny = p[2] + d[2];
									if inLakeRect(nx, ny) then
										local idx = ny * iW + nx + 1;
										if self.wholeworldPlotTypes[idx] ~= PlotTypes.PLOT_OCEAN then
											table.insert(candidates, {nx, ny, idx});
										end
									end
								end
							end
							if #candidates == 0 then
								break
							end
							local pick = candidates[Map.Rand(#candidates, "Snow Wrap Lake") + 1];
							self.wholeworldPlotTypes[pick[3]] = PlotTypes.PLOT_OCEAN;
							table.insert(blob, {pick[1], pick[2]});
						end
					end
				end
			end
		end
		for y = 0, iH - 1 do
			for x = 0, math.floor(iW / 2) - 1 do
				if self.wholeworldPlotTypes[y * iW + x + 1] == PlotTypes.PLOT_OCEAN then
					local mx = iW - x - 1;
					local my = iH - y - 1;
					self.wholeworldPlotTypes[my * iW + mx + 1] = PlotTypes.PLOT_OCEAN;
				end
			end
		end
		for _, p in ipairs(polarIslandPlots) do
			local mx = iW - p[1] - 1;
			local my = iH - p[2] - 1;
			self.wholeworldPlotTypes[my * iW + mx + 1] = self.wholeworldPlotTypes[p[2] * iW + p[1] + 1];
		end
	end
	if IsSnowNoWrap() then
		ShapeNoWrapBackstrip(self.wholeworldPlotTypes, iW, iH);
	end
	-- Plot Type generation completed. Return global plot array.
	return self.wholeworldPlotTypes
end
------------------------------------------------------------------------------
function GeneratePlotTypes()
	print("Setting Plot Types (Lua West vs East) ...");

	local layered_world = MultilayeredFractal.Create();
	local plot_list = layered_world:GeneratePlotsByRegion();
	local SplitOps = Map.GetCustomOption(OPT_CENTER_SPLIT);

	SetPlotTypes(plot_list);

	if IsOldSnow() then
		local plot_list = layered_world:GeneratePlotsByRegion();
		local iW, iH = Map.GetGridSize();
		local firstRingYIsEven = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
		local firstRingYIsOdd = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};
		for x = iW / 2 - 5, iW / 2 + 4 do
			for y = 1, iH - 2 do
				local plot = Map.GetPlot(x, y)
				if plot:IsFlatlands() then -- Check for adjacent Mountain plot; if found, change this plot to Hills.
					local isEvenY, search_table = true, {};
					if y / 2 > math.floor(y / 2) then
					isEvenY = false;
					end
					if isEvenY then
						search_table = firstRingYIsEven;
					else
						search_table = firstRingYIsOdd;
					end

					for loop, plot_adjustments in ipairs(search_table) do
						local searchX, searchY;
						searchX = x + plot_adjustments[1];
						searchY = y + plot_adjustments[2];
						local searchPlot = Map.GetPlot(searchX, searchY)
						local plotType = searchPlot:GetPlotType()
						if plotType == PlotTypes.PLOT_MOUNTAIN then
							plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false)
							break
						end
					end
				end
			end
		end
	end
	if false then -- Skirmish foothills
		local iW, iH = Map.GetGridSize();
		local firstRingYIsEven = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
		local firstRingYIsOdd = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};
		for x = iW / 2 - 2, iW / 2 + 1 do
			for y = 1, iH - 2 do
				local plot = Map.GetPlot(x, y)
				if plot:IsFlatlands() then -- Check for adjacent Mountain plot; if found, change this plot to Hills.
					local isEvenY, search_table = true, {};
					if y / 2 > math.floor(y / 2) then
					isEvenY = false;
					end
					if isEvenY then
						search_table = firstRingYIsEven;
					else
						search_table = firstRingYIsOdd;
					end

					for loop, plot_adjustments in ipairs(search_table) do
						local searchX, searchY;
						searchX = x + plot_adjustments[1];
						searchY = y + plot_adjustments[2];
						local searchPlot = Map.GetPlot(searchX, searchY)
						local plotType = searchPlot:GetPlotType()
						if plotType == PlotTypes.PLOT_MOUNTAIN then
							plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false)
							break
						end
					end
				end
			end
		end
	end
	if IsSnowBarrier() then
		local iW, iH = Map.GetGridSize();
		local firstRingYIsEven = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
		local firstRingYIsOdd = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};
		local function applyFoothills(xStart, xEnd)
			for x = xStart, xEnd do
				for y = 1, iH - 2 do
					local plot = Map.GetPlot(x, y)
					if plot ~= nil and plot:IsFlatlands() then
						local isEvenY, search_table = true, {};
						if y / 2 > math.floor(y / 2) then
							isEvenY = false;
						end
						if isEvenY then
							search_table = firstRingYIsEven;
						else
							search_table = firstRingYIsOdd;
						end
						for loop, plot_adjustments in ipairs(search_table) do
							local searchX = x + plot_adjustments[1];
							local searchY = y + plot_adjustments[2];
							local searchPlot = Map.GetPlot(searchX, searchY)
							if searchPlot ~= nil and searchPlot:GetPlotType() == PlotTypes.PLOT_MOUNTAIN then
								plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false)
								break
							end
						end
					end
				end
			end
		end
		applyFoothills(iW / 2 - 5, iW / 2 + 4)
		if IsSnowWrapX() then
			local x_wrap_west, x_wrap_east = GetSnowWrapLandMountainXs(iW);
			applyFoothills(x_wrap_west - 1, x_wrap_west + 1)
			applyFoothills(x_wrap_east - 1, x_wrap_east + 1)
		end
	end

	local args = {bExpandCoasts = false};
	GenerateCoasts(args);
end
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
function TerrainGenerator:GetLatitudeAtPlot(iX, iY)
	return GetClimateLatitudeAtPlot(iX, iY);
end
----------------------------------------------------------------------------------
function GenerateTerrain()
	print("Generating Terrain (Lua West vs East) ...");
	
	-- Get Temperature setting input by user.
	local temp = DEF_TEMPERATURE;
	if temp == 4 then
		temp = 1 + Map.Rand(3, "Random Temperature - Lua");
	end

	local args = {temperature = temp};
	local terraingen = TerrainGenerator.Create(args);

	terrainTypes = terraingen:GenerateTerrain();
	
	SetTerrainTypes(terrainTypes);
end
------------------------------------------------------------------------------



------------------------------------------------------------------------------
function FeatureGenerator:GetLatitudeAtPlot(iX, iY)
	return GetClimateLatitudeAtPlot(iX, iY);
end
------------------------------------------------------------------------------
function FeatureGenerator:AddIceAtPlot(plot, iX, iY, lat)
	return
end
------------------------------------------------------------------------------
function AddLakes()
	print("Map Generation - Adding Lakes");
	local numLakesAdded = 0;
	local lakePlotRand = 80;
	for i, plot in Plots() do
		if not plot:IsWater() then
			if not plot:IsCoastalLand() then
				if not plot:IsRiver() then
					local r = Map.Rand(lakePlotRand, "MapGenerator AddLakes");
					if r == 0 then
						local allow = true;
						if IsSnowBarrier() then
							if WaterAllowedAtX(plot:GetX()) == false then
								allow = false;
							end
						end
						if allow == true then
							plot:SetArea(-1);
							plot:SetPlotType(PlotTypes.PLOT_OCEAN);
							numLakesAdded = numLakesAdded + 1;
						end
					end
				end
			end
		end
	end
	ScrubWaterNearSnow();
	if numLakesAdded > 0 then
		print(tostring(numLakesAdded).." lakes added")
		Map.CalculateAreas();
	elseif IsSnowBarrier() then
		Map.CalculateAreas();
	end
end
------------------------------------------------------------------------------
function AddFeatures()
	print("Adding Features (Lua West vs East) ...");

	-- Get Rainfall setting input by user.
	local rain = DEF_RAINFALL;
	if rain == 4 then
		rain = 1 + Map.Rand(3, "Random Rainfall - Lua");
	end
	
	local args = {rainfall = rain}
	local featuregen = FeatureGenerator.Create(args);

	-- false = flatten coastal mountains to hills. Snow Wrap keeps peaks on water.
	featuregen:AddFeatures(IsSnowWrapX());
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------

function GetRiverValueAtPlot(plot)
	-- Custom method to force rivers to flow away from the map center.
	local iW, iH = Map.GetGridSize()
	local x = plot:GetX()
	local y = plot:GetY()
	local random_factor = Map.Rand(3, "River direction random factor - Skirmish LUA");
	local direction_influence_value = 0;--(math.abs(iW - (x - (iW / 2))) + ((math.abs(y - (iH / 2))) / 3)) * random_factor;

	local numPlots = PlotTypes.NUM_PLOT_TYPES;
	local sum = ((numPlots - plot:GetPlotType()) * 20) + direction_influence_value;

	local numDirections = DirectionTypes.NUM_DIRECTION_TYPES;
	for direction = 0, numDirections - 1 do
		local adjacentPlot = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);
		if (adjacentPlot ~= nil) then
			sum = sum + (numPlots - adjacentPlot:GetPlotType());
		else
			sum = sum + (numPlots * 10);
		end
	end
	sum = sum + Map.Rand(10, "River Rand");

	return sum;
end
------------------------------------------------------------------------------
function DoRiver(startPlot, thisFlowDirection, originalFlowDirection, riverID)
	-- Customizing to handle problems in top row of the map. Only this aspect has been altered.

	local iW, iH = Map.GetGridSize()
	thisFlowDirection = thisFlowDirection or FlowDirectionTypes.NO_FLOWDIRECTION;
	originalFlowDirection = originalFlowDirection or FlowDirectionTypes.NO_FLOWDIRECTION;

	-- pStartPlot = the plot at whose SE corner the river is starting
	if (riverID == nil) then
		riverID = nextRiverID;
		nextRiverID = nextRiverID + 1;
	end

	local otherRiverID = _rivers[startPlot]
	if (otherRiverID ~= nil and otherRiverID ~= riverID and originalFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then
		return; -- Another river already exists here; can't branch off of an existing river!
	end

	local riverPlot;
	
	local bestFlowDirection = FlowDirectionTypes.NO_FLOWDIRECTION;
	if (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTH) then
	
		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if ( adjacentPlot == nil or riverPlot:IsWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater() ) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetWOfRiver(true, thisFlowDirection);
		riverPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
		
	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHEAST) then
	
		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
		if ( adjacentPlot == nil or riverPlot:IsNWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater() ) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetNWOfRiver(true, thisFlowDirection);
		-- riverPlot does not change
	
	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST) then
	
		riverPlot = Map.PlotDirection(startPlot:GetX(), startPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if (riverPlot == nil) then
			return;
		end
		
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		if (adjacentPlot == nil or riverPlot:IsNEOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetNEOfRiver(true, thisFlowDirection);
		-- riverPlot does not change
	
	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTH) then
	
		riverPlot = Map.PlotDirection(startPlot:GetX(), startPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		if (riverPlot == nil) then
			return;
		end
		
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if (adjacentPlot == nil or riverPlot:IsWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end
		
		_rivers[riverPlot] = riverID;
		riverPlot:SetWOfRiver(true, thisFlowDirection);
		-- riverPlot does not change
	
	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST) then

		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
		if (adjacentPlot == nil or riverPlot:IsNWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end
		
		_rivers[riverPlot] = riverID;
		riverPlot:SetNWOfRiver(true, thisFlowDirection);
		-- riverPlot does not change

	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHWEST) then
		
		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		
		if ( adjacentPlot == nil or riverPlot:IsNEOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetNEOfRiver(true, thisFlowDirection);
		riverPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_WEST);

	else
		-- River is starting here, set the direction in the next step
		riverPlot = startPlot;		
	end

	if (riverPlot == nil or riverPlot:IsWater()) then
		-- The river has flowed off the edge of the map or into the ocean. All is well.
		return; 
	end

	-- Storing X,Y positions as locals to prevent redundant function calls.
	local riverPlotX = riverPlot:GetX();
	local riverPlotY = riverPlot:GetY();
	
	-- Table of methods used to determine the adjacent plot.
	local adjacentPlotFunctions = {
		[FlowDirectionTypes.FLOWDIRECTION_NORTH] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_NORTHWEST); 
		end,
		
		[FlowDirectionTypes.FLOWDIRECTION_NORTHEAST] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_NORTHEAST);
		end,
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_EAST);
		end,
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTH] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_SOUTHWEST);
		end,
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_WEST);
		end,
		
		[FlowDirectionTypes.FLOWDIRECTION_NORTHWEST] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_NORTHWEST);
		end	
	}
	
	if(bestFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then

		-- Attempt to calculate the best flow direction.
		local bestValue = math.huge;
		for flowDirection, getAdjacentPlot in pairs(adjacentPlotFunctions) do
			
			if (GetOppositeFlowDirection(flowDirection) ~= originalFlowDirection) then
				
				if (thisFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION or
					flowDirection == TurnRightFlowDirections[thisFlowDirection] or 
					flowDirection == TurnLeftFlowDirections[thisFlowDirection]) then
				
					local adjacentPlot = getAdjacentPlot();
					
					if (adjacentPlot ~= nil) then
					
						local value = GetRiverValueAtPlot(adjacentPlot);
						if (flowDirection == originalFlowDirection) then
							value = (value * 3) / 4;
						end
						
						if (value < bestValue) then
							bestValue = value;
							bestFlowDirection = flowDirection;
						end

					-- Custom addition for Highlands, to fix river problems in top row of the map. Any other all-land map may need similar special casing.
					elseif adjacentPlot == nil and riverPlotY == iH - 1 then -- Top row of map, needs special handling
						if flowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTH or
						   flowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHWEST or
						   flowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHEAST then
							
							local value = Map.Rand(5, "River Rand");
							if (flowDirection == originalFlowDirection) then
								value = (value * 3) / 4;
							end
							if (value < bestValue) then
								bestValue = value;
								bestFlowDirection = flowDirection;
							end
						end

					-- Custom addition for Highlands, to fix river problems in left column of the map. Any other all-land map may need similar special casing.
					elseif adjacentPlot == nil and riverPlotX == 0 then -- Left column of map, needs special handling
						if flowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTH or
						   flowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTH or
						   flowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHWEST or
						   flowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST then
							
							local value = Map.Rand(5, "River Rand");
							if (flowDirection == originalFlowDirection) then
								value = (value * 3) / 4;
							end
							if (value < bestValue) then
								bestValue = value;
								bestFlowDirection = flowDirection;
							end
						end
					end
				end
			end
		end
		
		-- Try a second pass allowing the river to "flow backwards".
		if(bestFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then
		
			local bestValue = math.huge;
			for flowDirection, getAdjacentPlot in pairs(adjacentPlotFunctions) do
			
				if (thisFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION or
					flowDirection == TurnRightFlowDirections[thisFlowDirection] or 
					flowDirection == TurnLeftFlowDirections[thisFlowDirection]) then
				
					local adjacentPlot = getAdjacentPlot();
					
					if (adjacentPlot ~= nil) then
						
						local value = GetRiverValueAtPlot(adjacentPlot);
						if (value < bestValue) then
							bestValue = value;
							bestFlowDirection = flowDirection;
						end
					end	
				end
			end
		end
	end
	
	--Recursively generate river.
	if (bestFlowDirection ~= FlowDirectionTypes.NO_FLOWDIRECTION) then
		if  (originalFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then
			originalFlowDirection = bestFlowDirection;
		end
		
		DoRiver(riverPlot, bestFlowDirection, originalFlowDirection, riverID);
	end
end
------------------------------------------------------------------------------
function AddRivers()

	-- Customization for Skirmish, to keep river starts away from buffer zone in middle columns of map, and set river "original flow direction".
	local iW, iH = Map.GetGridSize()
	print("Skirmish - Adding Rivers");
	local SplitOps = Map.GetCustomOption(OPT_CENTER_SPLIT)
	local passConditions = {
		function(plot)
			return plot:IsHills() or plot:IsMountain();
		end,
		
		function(plot)
			return (not plot:IsCoastalLand()) and (Map.Rand(8, "HBTMapGenerator AddRivers") == 0);
		end,
		
		function(plot)
			local area = plot:Area();
			local plotsPerRiverEdge = GameDefines["PLOTS_PER_RIVER_EDGE"];
			return (plot:IsHills() or plot:IsMountain()) and (area:GetNumRiverEdges() <	((area:GetNumTiles() / plotsPerRiverEdge) + 1));
		end,
		
		function(plot)
			local area = plot:Area();
			local plotsPerRiverEdge = GameDefines["PLOTS_PER_RIVER_EDGE"];
			return (area:GetNumRiverEdges() < (area:GetNumTiles() / plotsPerRiverEdge) + 1);
		end
	}
	for iPass, passCondition in ipairs(passConditions) do
		local riverSourceRange;
		local seaWaterRange;
		if (iPass <= 2) then
			riverSourceRange = GameDefines["RIVER_SOURCE_MIN_RIVER_RANGE"];
			seaWaterRange = GameDefines["RIVER_SOURCE_MIN_SEAWATER_RANGE"];
		else
			riverSourceRange = (GameDefines["RIVER_SOURCE_MIN_RIVER_RANGE"] / 2);
			seaWaterRange = (GameDefines["RIVER_SOURCE_MIN_SEAWATER_RANGE"] / 2);
		end
		for i, plot in Plots() do
			local current_x = plot:GetX()
			local current_y = plot:GetY()
			if current_y < 2 or current_y >= iH - 1 then
				-- Plot too close to north/south edge, ignore it.
			elseif IsSnowNoWrap() and (current_x < 2 or current_x >= iW - 2) then
				-- Plot too close to east/west 2-col ocean rims, ignore it.
			elseif IsSnowWrapX() == false and (current_x < 1 or current_x >= iW - 2) then
				-- Plot too close to east/west ocean rims, ignore it.
			elseif IsSnowWrapX() and (current_x < 4 or current_x >= iW - 4) then
				-- Plot in wrap-front buffer, ignore it.
			elseif current_x >= (iW / 2) - 3 and current_x <= (iW / 2) + 2 then
				-- Plot in buffer zone, ignore it.
			elseif (not plot:IsWater()) then
				if(passCondition(plot)) then
					if (not Map.FindWater(plot, riverSourceRange, true)) then
						if (not Map.FindWater(plot, seaWaterRange, false)) then
							local inlandCorner = plot:GetInlandCorner();
							if(inlandCorner) then
								local start_x = inlandCorner:GetX()
								local start_y = inlandCorner:GetY()
								local orig_direction;
								if IsSnowBarrier() then
									local lakeX = iW / 4;
									if start_x >= iW / 2 then
										lakeX = iW * 0.75;
									end
									if start_y < iH / 2 then
										if start_x < lakeX then
											orig_direction = FlowDirectionTypes.FLOWDIRECTION_NORTHEAST;
										else
											orig_direction = FlowDirectionTypes.FLOWDIRECTION_NORTHWEST;
										end
									else
										if start_x < lakeX then
											orig_direction = FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST;
										else
											orig_direction = FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST;
										end
									end
								elseif start_y < iH / 2 then -- South half of map
									if start_x < iW / 2 then -- West half of map
										orig_direction = FlowDirectionTypes.FLOWDIRECTION_NORTHWEST;
									else -- East half
										orig_direction = FlowDirectionTypes.FLOWDIRECTION_NORTHEAST;
									end
								else -- North half of map
									if start_x < iW / 2 then -- West half of map
										orig_direction = FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST;
									else -- NE corner
										orig_direction = FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST;
									end
								end
								DoRiver(inlandCorner, nil, orig_direction, nil);
							end
						end
					end
				end			
			end
		end
	end		
end
------------------------------------------------------------------------------------------------------------------------------------------------------------
function AssignStartingPlots:GenerateRegions(args)
	print("Map Generation - Dividing the map in to Regions");
	-- This is a customized version for West vs East.
	-- This version is tailored for handling two-teams play.
	local args = args or {};
	local iW, iH = Map.GetGridSize();
	local res = DEF_RESOURCES;
	if res == 9 then
		res = 1 + Map.Rand(3, "Random Resources Option - Lua");
	end

	local setback = DEF_FRONTLINE-1;

	local setforward = DEF_BACK-1;

	local setrange = setforward + setback;

	print("Moveback: ", setback);

	local setmiddle = DEF_TOPBOTTOM-1;

	self.resource_setting = res; -- Each map script has to pass in parameter for Resource setting chosen by user.
	self.method = 3; -- Flag the map as using a Rectangular division method.

	-- Determine number of civilizations and city states present in this game.
	self.iNumCivs, self.iNumCityStates, self.player_ID_list, self.bTeamGame, self.teams_with_major_civs, self.number_civs_per_team = GetPlayerAndTeamInfo()
	self.iNumCityStatesUnassigned = self.iNumCityStates;
	print("-"); print("Civs:", self.iNumCivs); print("City States:", self.iNumCityStates);

	-- Determine number of teams (of Major Civs only, not City States) present in this game.
	iNumTeams = table.maxn(self.teams_with_major_civs);				-- GLOBAL
	print("-"); print("Teams:", iNumTeams);

	-- Fetch team setting.
	local team_setting = DEF_TEAM

	-- If two teams are present, use team-oriented handling of start points, one team west, one east.
	if iNumTeams == 2 and team_setting == 1 then
		print("-"); print("Number of Teams present is two! Using custom team start placement for West vs East."); print("-");
		
		-- ToDo: Correctly identify team IDs and how many Civs are on each team.
		-- Also need to shuffle the teams so its random who starts on which half.
		local shuffled_team_list = GetShuffledCopyOfTable(self.teams_with_major_civs)
		teamWestID = self.teams_with_major_civs[1];							-- GLOBAL
		teamEastID = self.teams_with_major_civs[2]; 						-- GLOBAL
		iNumCivsInWest = self.number_civs_per_team[teamWestID];		-- GLOBAL
		iNumCivsInEast = self.number_civs_per_team[teamEastID];		-- GLOBAL

		-- Process the team in the west.
		self.inhabited_WestX = 0 + setforward;
		self.inhabited_SouthY = 0 + setmiddle;
		self.inhabited_Width = (math.floor(iW / 2)) - setrange;
		self.inhabited_Height = iH - 2 * setmiddle;
		if IsSnowBarrier() then
			local wrapN, centerN = ResolveSnowWrapWidths();
			local wrapHalf = wrapN / 2;
			local centerHalf = centerN / 2;
			local mid = math.floor(iW / 2);
			local backPad = wrapHalf - 1;
			if backPad < 0 then
				backPad = 0;
			end
			self.inhabited_WestX = setforward + backPad;
			self.inhabited_Width = (mid - centerHalf) - setback - 1 - self.inhabited_WestX + 1;
		end
		-- Obtain "Start Placement Fertility" inside the rectangle.
		-- Data returned is: fertility table, sum of all fertility, plot count.
		local fert_table, fertCount, plotCount = self:MeasureStartPlacementFertilityInRectangle(self.inhabited_WestX, 
		                                         self.inhabited_SouthY, self.inhabited_Width, self.inhabited_Height)
		-- Assemble the Rectangle data table:
		local rect_table = {self.inhabited_WestX, self.inhabited_SouthY, self.inhabited_Width, 
		                    self.inhabited_Height, -1, fertCount, plotCount}; -- AreaID -1 means ignore area IDs.
		-- Divide the rectangle.
		self:DivideIntoRegions(iNumCivsInWest, fert_table, rect_table)

		-- Process the team in the east.
		self.inhabited_WestX = (math.floor(iW / 2)) + setback;
		self.inhabited_SouthY = 0 + setmiddle;
		self.inhabited_Width = math.floor(iW / 2) - setrange;
		self.inhabited_Height = iH - 2 * setmiddle;
		if IsSnowBarrier() then
			local wrapN, centerN = ResolveSnowWrapWidths();
			local wrapHalf = wrapN / 2;
			local centerHalf = centerN / 2;
			local mid = math.floor(iW / 2);
			self.inhabited_WestX = (mid + centerHalf) + setback;
			local lastEast = iW - setforward - 1;
			if wrapHalf > 1 then
				lastEast = iW - setforward - wrapHalf;
			end
			self.inhabited_Width = lastEast - self.inhabited_WestX + 1;
		end
		-- Obtain "Start Placement Fertility" inside the rectangle.
		-- Data returned is: fertility table, sum of all fertility, plot count.
		local fert_table, fertCount, plotCount = self:MeasureStartPlacementFertilityInRectangle(self.inhabited_WestX, 
		                                         self.inhabited_SouthY, self.inhabited_Width, self.inhabited_Height)
		-- Assemble the Rectangle data table:
		local rect_table = {self.inhabited_WestX, self.inhabited_SouthY, self.inhabited_Width, 
		                    self.inhabited_Height, -1, fertCount, plotCount}; -- AreaID -1 means ignore area IDs.
		-- Divide the rectangle.
		self:DivideIntoRegions(iNumCivsInEast, fert_table, rect_table)
		-- The regions have been defined.

	-- If number of teams is any number other than two, use standard One Landmass division.
	else	
		print("-"); print("Dividing the map at random."); print("-");
		self.method = 2;	
		local best_areas = {};
		local globalFertilityOfLands = {};

		-- Obtain info on all landmasses for comparision purposes.
		local iGlobalFertilityOfLands = 0;
		local iNumLandPlots = 0;
		local iNumLandAreas = 0;
		local land_area_IDs = {};
		local land_area_plots = {};
		local land_area_fert = {};
		-- Cycle through all plots in the world, checking their Start Placement Fertility and AreaID.
		for x = 0, iW - 1 do
			for y = 0, iH - 1 do
				local i = y * iW + x + 1;
				local plot = Map.GetPlot(x, y);
				if not plot:IsWater() then -- Land plot, process it.
					iNumLandPlots = iNumLandPlots + 1;
					local iArea = plot:GetArea();
					local plotFertility = self:MeasureStartPlacementFertilityOfPlot(x, y, true); -- Check for coastal land is enabled.
					iGlobalFertilityOfLands = iGlobalFertilityOfLands + plotFertility;
					--
					if TestMembership(land_area_IDs, iArea) == false then -- This plot is the first detected in its AreaID.
						iNumLandAreas = iNumLandAreas + 1;
						table.insert(land_area_IDs, iArea);
						land_area_plots[iArea] = 1;
						land_area_fert[iArea] = plotFertility;
					else -- This AreaID already known.
						land_area_plots[iArea] = land_area_plots[iArea] + 1;
						land_area_fert[iArea] = land_area_fert[iArea] + plotFertility;
					end
				end
			end
		end
		
		-- Sort areas, achieving a list of AreaIDs with best areas first.
		--
		-- Fertility data in land_area_fert is stored with areaID index keys.
		-- Need to generate a version of this table with indices of 1 to n, where n is number of land areas.
		local interim_table = {};
		for loop_index, data_entry in pairs(land_area_fert) do
			table.insert(interim_table, data_entry);
		end
		-- Sort the fertility values stored in the interim table. Sort order in Lua is lowest to highest.
		table.sort(interim_table);
		-- If less players than landmasses, we will ignore the extra landmasses.
		local iNumRelevantLandAreas = math.min(iNumLandAreas, self.iNumCivs);
		-- Now re-match the AreaID numbers with their corresponding fertility values
		-- by comparing the original fertility table with the sorted interim table.
		-- During this comparison, best_areas will be constructed from sorted AreaIDs, richest stored first.
		local best_areas = {};
		-- Currently, the best yields are at the end of the interim table. We need to step backward from there.
		local end_of_interim_table = table.maxn(interim_table);
		-- We may not need all entries in the table. Process only iNumRelevantLandAreas worth of table entries.
		for areaTestLoop = end_of_interim_table, (end_of_interim_table - iNumRelevantLandAreas + 1), -1 do
			for loop_index, AreaID in ipairs(land_area_IDs) do
				if interim_table[areaTestLoop] == land_area_fert[land_area_IDs[loop_index]] then
					table.insert(best_areas, AreaID);
					table.remove(land_area_IDs, landLoop);
					break
				end
			end
		end

		-- Assign continents to receive start plots. Record number of civs assigned to each landmass.
		local inhabitedAreaIDs = {};
		local numberOfCivsPerArea = table.fill(0, iNumRelevantLandAreas); -- Indexed in synch with best_areas. Use same index to match values from each table.
		for civToAssign = 1, self.iNumCivs do
			local bestRemainingArea;
			local bestRemainingFertility = 0;
			local bestAreaTableIndex;
			-- Loop through areas, find the one with the best remaining fertility (civs added 
			-- to a landmass reduces its fertility rating for subsequent civs).
			for area_loop, AreaID in ipairs(best_areas) do
				local thisLandmassCurrentFertility = land_area_fert[AreaID] / (1 + numberOfCivsPerArea[area_loop]);
				if thisLandmassCurrentFertility > bestRemainingFertility then
					bestRemainingArea = AreaID;
					bestRemainingFertility = thisLandmassCurrentFertility;
					bestAreaTableIndex = area_loop;
				end
			end
			-- Record results for this pass. (A landmass has been assigned to receive one more start point than it previously had).
			numberOfCivsPerArea[bestAreaTableIndex] = numberOfCivsPerArea[bestAreaTableIndex] + 1;
			if TestMembership(inhabitedAreaIDs, bestRemainingArea) == false then
				table.insert(inhabitedAreaIDs, bestRemainingArea);
			end
		end
				
		-- Loop through the list of inhabited landmasses, dividing each landmass in to regions.
		-- Note that it is OK to divide a continent with one civ on it: this will assign the whole
		-- of the landmass to a single region, and is the easiest method of recording such a region.
		local iNumInhabitedLandmasses = table.maxn(inhabitedAreaIDs);
		for loop, currentLandmassID in ipairs(inhabitedAreaIDs) do
			-- Obtain the boundaries of and data for this landmass.
			local landmass_data = ObtainLandmassBoundaries(currentLandmassID);
			local iWestX = landmass_data[1];
			local iSouthY = landmass_data[2];
			local iEastX = landmass_data[3];
			local iNorthY = landmass_data[4];
			local iWidth = landmass_data[5];
			local iHeight = landmass_data[6];
			local wrapsX = landmass_data[7];
			local wrapsY = landmass_data[8];
			-- Obtain "Start Placement Fertility" of the current landmass. (Necessary to do this
			-- again because the fert_table can't be built prior to finding boundaries, and we had
			-- to ID the proper landmasses via fertility to be able to figure out their boundaries.
			local fert_table, fertCount, plotCount = self:MeasureStartPlacementFertilityOfLandmass(currentLandmassID, 
		  	                                         iWestX, iEastX, iSouthY, iNorthY, wrapsX, wrapsY);
			-- Assemble the rectangle data for this landmass.
			local rect_table = {iWestX, iSouthY, iWidth, iHeight, currentLandmassID, fertCount, plotCount};
			-- Divide this landmass in to number of regions equal to civs assigned here.
			iNumCivsOnThisLandmass = numberOfCivsPerArea[loop];
			if iNumCivsOnThisLandmass > 0 and iNumCivsOnThisLandmass <= 22 then -- valid number of civs.
				self:DivideIntoRegions(iNumCivsOnThisLandmass, fert_table, rect_table)
			else
				print("Invalid number of civs assigned to a landmass: ", iNumCivsOnThisLandmass);
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:BalanceAndAssign()
	-- This function determines what level of Bonus Resource support a location
	-- may need, identifies compatibility with civ-specific biases, and places starts.

	-- Normalize each start plot location.
	local iNumStarts = table.maxn(self.startingPlots);
	for region_number = 1, iNumStarts do
		print("Normalize Region: ", region_number);
		self:NormalizeStartLocation(region_number)
	end

	-- Assign Civs to start plots.
	local team_setting = DEF_TEAM
	if iNumTeams == 2 and team_setting == 1 then
		-- Two teams, place one in the west half, other in east -- even if team membership totals are uneven.
		print("-"); print("This is a team game with two teams! Place one team in West, other in East."); print("-");
		local playerList, westList, eastList = {}, {}, {};
		for loop = 1, self.iNumCivs do
			local player_ID = self.player_ID_list[loop];
			table.insert(playerList, player_ID);
			local player = Players[player_ID];
			local team_ID = player:GetTeam()
			if team_ID == teamWestID then
				print("Player #", player_ID, "belongs to Team #", team_ID, "and will be placed in the North.");
				table.insert(westList, player_ID);
			elseif team_ID == teamEastID then
				print("Player #", player_ID, "belongs to Team #", team_ID, "and will be placed in the South.");
				table.insert(eastList, player_ID);
			else
				print("* ERROR * - Player #", player_ID, "belongs to Team #", team_ID, "which is neither West nor East!");
			end
		end
		
		-- Debug
		if table.maxn(westList) ~= iNumCivsInWest then
			print("-"); print("*** ERROR! *** . . . Mismatch between number of Civs on West team and number of civs assigned to west locations.");
		end
		if table.maxn(eastList) ~= iNumCivsInEast then
			print("-"); print("*** ERROR! *** . . . Mismatch between number of Civs on East team and number of civs assigned to east locations.");
		end
		
		local westListShuffled = GetShuffledCopyOfTable(westList)
		local eastListShuffled = GetShuffledCopyOfTable(eastList)
		for region_number, player_ID in ipairs(westListShuffled) do
			local x = self.startingPlots[region_number][1];
			local y = self.startingPlots[region_number][2];
			local start_plot = Map.GetPlot(x, y)
			local player = Players[player_ID]
			player:SetStartingPlot(start_plot)
		end
		for loop, player_ID in ipairs(eastListShuffled) do
			local x = self.startingPlots[loop + iNumCivsInWest][1];
			local y = self.startingPlots[loop + iNumCivsInWest][2];
			local start_plot = Map.GetPlot(x, y)
			local player = Players[player_ID]
			player:SetStartingPlot(start_plot)
		end
	else
		print("-"); print("This game does not have specific start zone assignments."); print("-");
		local playerList = {};
		for loop = 1, self.iNumCivs do
			local player_ID = self.player_ID_list[loop];
			table.insert(playerList, player_ID);
		end
		local playerListShuffled = GetShuffledCopyOfTable(playerList)
		for region_number, player_ID in ipairs(playerListShuffled) do
			local x = self.startingPlots[region_number][1];
			local y = self.startingPlots[region_number][2];
			local start_plot = Map.GetPlot(x, y)
			local player = Players[player_ID]
			player:SetStartingPlot(start_plot)
		end
		-- If this is a team game (any team has more than one Civ in it) then make 
		-- sure team members start near each other if possible. (This may scramble 
		-- Civ biases in some cases, but there is no cure).
		if self.bTeamGame == true and team_setting ~= 2 then
			print("However, this IS a team game, so we will try to group team members together."); print("-");
			self:NormalizeTeamLocations()
		end
	end
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function AssignStartingPlots:CanPlaceCityStateAt(x, y, area_ID, force_it, ignore_collisions)
	-- Overriding default city state placement to prevent city states from being placed too close to map edges.
	
	--disable city states
	if 1<2 then
		return false
	end

	local iW, iH = Map.GetGridSize();
	local plot = Map.GetPlot(x, y)
	local area = plot:GetArea()
	
	-- Adding this check for West vs East.
	if x < 1 or x >= iW - 1 or y < 1 or y >= iH - 1 then
		return false
	end
	--
	
	if area ~= area_ID and area_ID ~= -1 then
		return false
	end
	local plotType = plot:GetPlotType()
	if plotType == PlotTypes.PLOT_OCEAN or plotType == PlotTypes.PLOT_MOUNTAIN then
		return false
	end
	local terrainType = plot:GetTerrainType()
	if terrainType == TerrainTypes.TERRAIN_SNOW then
		return false
	end
	local plotIndex = y * iW + x + 1;
	if self.cityStateData[plotIndex] > 0 and force_it == false then
		return false
	end
	local plotIndex = y * iW + x + 1;
	if self.playerCollisionData[plotIndex] == true and ignore_collisions == false then
		--print("-"); print("City State candidate plot rejected: collided with already-placed civ or City State at", x, y);
		return false
	end
	return true
end
------------------------------------------------------------------------------------------------------------------------------------------------------------
function SetDivide()

	local SplitOps = Map.GetCustomOption(OPT_CENTER_SPLIT);
	local iW, iH = Map.GetGridSize();

	if false then -- Landbridges
		-- check landbridges have no lakes or moutains

		--check bottom land bridge
		for y = 0, 2 do
			for x = math.floor(iW / 2) - 4, math.floor(iW / 2) + 3 do
				local plot = Map.GetPlot(x, y)
				
				--check for mountain or lake
				if plot:GetPlotType() == PlotTypes.PLOT_MOUNTAIN then
					plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false);
				elseif plot:IsLake() then
					plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
				end
			end
		end

		--check the top landbridge
		for y = (iH-3), (iH-1) do
			for x = math.floor(iW / 2) - 4, math.floor(iW / 2) + 3 do
				local plot = Map.GetPlot(x, y)
				
				--check for mountain or lake
				if plot:GetPlotType() == PlotTypes.PLOT_MOUNTAIN then
					plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false);
				elseif plot:IsLake() then
					plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
				end
			end
		end

		--check the middle landbridge
		for y = math.floor(iH / 2) - 1, math.floor(iH / 2) + 1 do
			for x = math.floor(iW / 2) - 4, math.floor(iW / 2) + 3 do
				local plot = Map.GetPlot(x, y)
				
				--check for mountain or lake
				if plot:GetPlotType() == PlotTypes.PLOT_MOUNTAIN then
					plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false);
				elseif plot:IsLake() then
					plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
				end
			end
		end
	elseif false then -- Marsh
		--Marsh
		
		-- Add strip of marsh to middle of map
		for y = 0, iH - 1 do
			for x = math.floor(iW / 2) - 2, math.floor(iW / 2) + 1 do
				local plot = Map.GetPlot(x, y)
				plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
				plot:SetTerrainType(TerrainTypes.TERRAIN_GRASS, false, false);
				plot:SetFeatureType(FeatureTypes.FEATURE_MARSH, -1);
			end
		end
	elseif IsOldSnow() then
		--Snow

		-- Add strip of tundra to middle of map
		for y = 0, iH - 1 do
			for x = math.floor(iW / 2) - 3, math.floor(iW / 2) + 2 do
				local plot = Map.GetPlot(x, y)
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
				plot:SetTerrainType(TerrainTypes.TERRAIN_TUNDRA, false, false);
			end
		end
		-- Add strip of snow to middle of map
		for y = 0, iH - 1 do
			for x = math.floor(iW / 2) - 2, math.floor(iW / 2) + 1 do
				local plot = Map.GetPlot(x, y)
				if plot:GetPlotType() == PlotTypes.PLOT_MOUNTAIN then
					plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false);
				elseif plot:IsLake() then
					plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
				end
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
				plot:SetTerrainType(TerrainTypes.TERRAIN_SNOW, false, false);
			end
		end
	elseif IsSnowBarrier() then
		local tundraCols = GetSnowWrapTundraColumns(iW);
		local snowCols = GetSnowWrapColumns(iW);
		local mirrored = (DEF_MIRRORED == 1);
		local snowPlots = {};
		for y = 0, iH - 1 do
			for _, x in ipairs(tundraCols) do
				local plot = Map.GetPlot(x, y)
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
				plot:SetTerrainType(TerrainTypes.TERRAIN_TUNDRA, false, false);
			end
			for _, x in ipairs(snowCols) do
				local plot = Map.GetPlot(x, y)
				if plot:IsWater() then
					plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
				end
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
				plot:SetTerrainType(TerrainTypes.TERRAIN_SNOW, false, false);
				if (not mirrored) or (x <= iW * 0.5) then
					table.insert(snowPlots, plot);
				end
			end
		end
		local shuffled = GetShuffledCopyOfTable(snowPlots);
		local n = #shuffled;
		local nMountain = math.floor(n * 0.01 + 0.5);
		local nHill = math.floor(n * 0.19 + 0.5);
		if nMountain + nHill > n then
			nHill = n - nMountain;
		end
		for i, plot in ipairs(shuffled) do
			if i <= nMountain then
				plot:SetPlotType(PlotTypes.PLOT_MOUNTAIN, false, false);
			elseif i <= nMountain + nHill then
				plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false);
			else
				plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
			end
		end
	end
end

------------------------------------------------------------------------------
function getMirroredPlot(plot)
	local iW, iH = Map.GetGridSize();
	local x = iW - plot:GetX() - 1;
	local y = iH - plot:GetY() - 1;
	print("mirror x/y=",x,y);
	local mirrorPlot = Map.GetPlot(x, y);
	return mirrorPlot;
end
------------------------------------------------------------------------------
function isValidPlayer(pPlayer)
	return  pPlayer ~= nil and pPlayer:GetStartingPlot() ~= nil and pPlayer:IsAlive();
end
------------------------------------------------------------------------------
function StartPlotSystem()
	-- Get Resources setting input by user.
	local res = DEF_RESOURCES;
	if res == 9 then
		res = 1 + Map.Rand(3, "Random Resources Option - Lua");
	end

	print("Creating start plot database.");
	local start_plot_database = AssignStartingPlots.Create()

	print("Dividing the map in to Regions.");
	print("Resource Setting: ", res);
	local args = {
		resources = res,
		};
	start_plot_database:GenerateRegions()

	-- need a way to add the middle split options here
	print("Setting divide section of map");
	SetDivide()

	print("Choosing start locations for civilizations.");
	start_plot_database:ChooseLocations()
	
	print("Normalizing start locations and assigning them to Players.");
	start_plot_database:BalanceAndAssign()

	--print("Placing Natural Wonders.");
	--start_plot_database:PlaceNaturalWonders()

	print("Placing Natural Wonders.");
	local wonders = DEF_NATURAL_WONDERS
	if wonders == 16 then
		wonders = 2 + Map.Rand(4, "Number of Wonders 2-5 - Lua");
	elseif wonders == 14 then
		wonders = Map.Rand(13, "Number of Wonders To Spawn - Lua");
	else
		wonders = wonders - 1;
	end

	print("########## Wonders ##########");
	print("Natural Wonders To Place: ", wonders);

	local wonderargs = {
		wonderamt = wonders,
	};

	start_plot_database:PlaceNaturalWonders(wonderargs)

	print("Placing Resources and City States.");
	start_plot_database:PlaceResourcesAndCityStates()
	
	if IsOldSnow() then
		local iW, iH = Map.GetGridSize()
		for x = math.floor(iW / 2) - 2, (iW / 2) + 1 do
			for y = 0, iH - 1 do
				local plot = Map.GetPlot(x, y)
				plot:SetWOfRiver(false,FlowDirectionTypes.NO_FLOWDIRECTION)
				plot:SetNWOfRiver(false,FlowDirectionTypes.NO_FLOWDIRECTION)
				plot:SetNEOfRiver(false,FlowDirectionTypes.NO_FLOWDIRECTION)
			end
		end
	end
	if IsSnowBarrier() then
		local iW, iH = Map.GetGridSize()
		local snowCols = GetSnowWrapColumns(iW);
		for _, x in ipairs(snowCols) do
			for y = 0, iH - 1 do
				local plot = Map.GetPlot(x, y)
				plot:SetWOfRiver(false,FlowDirectionTypes.NO_FLOWDIRECTION)
				plot:SetNWOfRiver(false,FlowDirectionTypes.NO_FLOWDIRECTION)
				plot:SetNEOfRiver(false,FlowDirectionTypes.NO_FLOWDIRECTION)
			end
		end
	end
	PurgeNearStartLakeFish();
	if DEF_MIRRORED == 1 then
	------------------------------------------------------------------------------
	----------------------- INCLUDE getMirroredPlot()-----------------------------
	----------------- Copyright 2010  (c)  Leszek Deska --------------------------
	------------------------------------------------------------------------------
	-- mirrorize plot types, terrain, resource, natural wonders, ruins (ruins doesn't work)
	local iW, iH = Map.GetGridSize()
	print("iW/iH=",iW, iH)
	for x = 0, iW * 0.5 do
		for y = 0, iH - 1 do
			if( iW-x-y%2 ~= x ) then
				print("x/y=",x,y);
				local plot = Map.GetPlot(x, y);
				local mirrorPlot = getMirroredPlot(plot);
				local plotType = plot:GetPlotType();
				local terrainType = plot:GetTerrainType();
				local featureType = plot:GetFeatureType();
				local improvementType = plot:GetImprovementType();
				local resourceType = plot:GetResourceType(-1)
				mirrorPlot:SetPlotType(plotType,false,false)
				mirrorPlot:SetTerrainType(terrainType,false,false)
				mirrorPlot:SetFeatureType(featureType)
				mirrorPlot:SetResourceType(resourceType,plot:GetNumResource())
				mirrorPlot:SetImprovementType(improvementType)
			end
		end
	end
	-- rivers
	-- mirrorize rivers
	--rivers
	for x = math.floor(iW / 2)+1, iW - 1 do
		for y = 0, iH - 1 do
			local plot = Map.GetPlot(x, y)
			plot:SetWOfRiver(false,FlowDirectionTypes.NO_FLOWDIRECTION)
			plot:SetNWOfRiver(false,FlowDirectionTypes.NO_FLOWDIRECTION)
			plot:SetNEOfRiver(false,FlowDirectionTypes.NO_FLOWDIRECTION)
		end
	end
	for y = 0, iH - 1 do
		for x = 0, iW * 0.5 do
		    if ( x < (iW/2 + 1) ) then
            	local plot = Map.GetPlot(x, y);
				if ( plot:IsWOfRiver() ) then
					local mirrorPlot = getMirroredPlot(plot);
					mirrorPlot = Map.PlotDirection(mirrorPlot:GetX(), mirrorPlot:GetY(), DirectionTypes.DIRECTION_WEST);
					local dir = FlowDirectionTypes.FLOWDIRECTION_NORTH;
					if( plot:GetRiverEFlowDirection() == FlowDirectionTypes.FLOWDIRECTION_NORTH ) then
						dir = FlowDirectionTypes.FLOWDIRECTION_SOUTH;
					end
					mirrorPlot:SetWOfRiver(true, dir);
				end
				if ( plot:IsNWOfRiver() ) then
					local mirrorPlot = getMirroredPlot(plot);
					mirrorPlot = Map.PlotDirection(mirrorPlot:GetX(), mirrorPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
					local dir = FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST;
					if( plot:GetRiverSEFlowDirection() == FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST) then
						dir = FlowDirectionTypes.FLOWDIRECTION_NORTHEAST;
					end;
					mirrorPlot:SetNWOfRiver(true, dir);
				end
				if ( plot:IsNEOfRiver() ) then
					local mirrorPlot = getMirroredPlot(plot);
					mirrorPlot = Map.PlotDirection(mirrorPlot:GetX(), mirrorPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
					local dir = FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST;
					if( plot:GetRiverSWFlowDirection() == FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST) then
						dir = FlowDirectionTypes.FLOWDIRECTION_NORTHWEST;
					end;
					mirrorPlot:SetNEOfRiver(true, dir);
				end
			end
		end
	end
	-- mirrorize starting positions
	local playerStartPlot;
	local searchMode = 0;
	for i = 0, GameDefines.MAX_MAJOR_CIVS + GameDefines.MAX_MINOR_CIVS - 1 do
		local player = Players[i];
		if (isValidPlayer(player)) then
			if player:IsEverAlive() then
				if( searchMode == 0 ) then
					searchMode = 1;
					player = Players[i];
					playerStartPlot = player:GetStartingPlot();
				else
					searchMode = 0;
					player = Players[i];
					player:SetStartingPlot(getMirroredPlot(playerStartPlot));
				end
			end
		end
	end
		Map:RecalculateAreas();
		Game.SetOption(1, true);
	
	end
end
------------------------------------------------------------------------------

