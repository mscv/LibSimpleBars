--[[
Name: LibSimpleBars-1.0
Author: mscv
Inspired By: LibCandyBar-3.0 for WoW
Dependencies: none
Description: LibSimpleBars is a simple library allowing for standardized creation and manipulation of timer bars.

License: LibSimpleBars-1.0 is hereby placed in the Public Domain.

Usage:

local lsb = Apollo.GetPackage("LibSimpleBars-1.0").tPackage

local id, wndParent, intWidth, intHeight = 1, nil, 200, 20
local newBar = lsb.CreateBar(id, wndParent, intWidth, intHeight)

newBar:SetLabel("Yay!")
newBar:SetDuration(60)
newBar:Start()

All methods for bar manipulation may be used on running bars as well.

]]--


local MAJOR, MINOR = "LibSimpleBars-1.0", 4 
-- Get a reference to the package information if any
local APkg = Apollo.GetPackage(MAJOR)
-- If there was an older version loaded we need to see if this is newer
if APkg and (APkg.nVersion or 0) >= MINOR then
	return -- no upgrade needed
end

require "Apollo"
require "ApolloTimer"
require "GameLib"
require "XmlDoc"

local Apollo, ApolloTimer, XmlDoc = Apollo, ApolloTimer, XmlDoc

local max, strformat, getTime = math.max, string.format, GameLib.GetGameTime


-----------------------------------------------------------------------------------------------
-- LibSimpleBars Module Definition
-----------------------------------------------------------------------------------------------
local LibSimpleBars = APkg and APkg.tPackage or {}

local _bars = {}
local _timer

--------------------
--  Bar Object  --
--------------------
do
	local barPrototype = {}
	local mt = {__index = barPrototype}

	-- Bar table & XMLdoc template
	local BAR_TEMPLATE_TABLE = { {

		__XmlNode = "Form",
		Name = "BarTemplate",
		Class = "Window",
		Template = "Default",

		LAnchorOffset = 0,
		LAnchorPoint = 0,
		TAnchorOffset = 0,
		TAnchorPoint = 0,
		RAnchorOffset = 400,
		RAnchorPoint = 0,
		BAnchorOffset = 25,
		BAnchorPoint = 0,

		BGColor = "xkcdBlack",
		IgnoreMouse = "1",
		NoClip = "1",
		Picture = "1",
		RelativeToClient = "1",
		Sprite = "BasicSprites:WhiteFill",
		SwallowMouseClicks = "1",
		{
		  __XmlNode = "Control",
		  Name = "Icon",
		  Class = "Window",
		  Template = "Default",

		  LAnchorOffset = 0,
		  LAnchorPoint = 0,
		  TAnchorOffset = 0,
		  TAnchorPoint = 0,
		  RAnchorOffset = 0,
		  RAnchorPoint = 0,
		  BAnchorOffset = 25,
		  BAnchorPoint = 0,

		  MaintainAspectRatio = "1",
		  NewWindowDepth = 1,
		  Picture = "1",
		  RelativeToClient = "1",
		  TooltipType = "OnCursor"
		},
		{
		  __XmlNode = "Control",
		  Name = "Label",
		  Class = "Window",
		  Template = "Default",

		  LAnchorOffset = 5,
		  LAnchorPoint = 0,
		  TAnchorOffset = 0,
		  TAnchorPoint = 0,
		  RAnchorOffset = 0,
		  RAnchorPoint = 1,
		  BAnchorOffset = 0,
		  BAnchorPoint = 1,

		  AutoScaleText = "1",
		  BGColor = "UI_WindowBGDefault",
		  DT_VCENTER = "1",
		  IgnoreMouse = "1",
		  NewWindowDepth = 1,
		  RelativeToClient = "1",
		},
		{
		  __XmlNode = "Control",
		  Name = "Duration",
		  Class = "Window",
		  Template = "Default",

		  LAnchorOffset = "",
		  LAnchorPoint = 0,
		  TAnchorOffset = 0,
		  TAnchorPoint = 0,
		  RAnchorOffset = -5,
		  RAnchorPoint = 1,
		  BAnchorOffset = 0,
		  BAnchorPoint = 1,

		  DT_RIGHT = "1",
		  DT_VCENTER = "1",
		  IgnoreMouse = "1",
		  NewWindowDepth = 1,
		  RelativeToClient = "1",
		},
		{
		  __XmlNode = "Control",
		  Name = "ProgressBar",
		  Class = "ProgressBar",
		  Template = "Default",

		  LAnchorOffset = 0,
		  LAnchorPoint = 0,
		  TAnchorOffset = 0,
		  TAnchorPoint = 0,
		  RAnchorOffset = 0,
		  RAnchorPoint = 1,
		  BAnchorOffset = 0,
		  BAnchorPoint = 1,

		  BarColor = "blue",
		  IgnoreMouse = "1",
		  MaintainAspectRatio = "1",
		  ProgressFull = "BasicSprites:WhiteFill",
		  RelativeToClient = "1",
		  TestAlpha = 1,
		},
	  },
	  __XmlNode = "Forms"
	}

	local BAR_TEMPLATE_XMLDOC = XmlDoc.CreateFromTable(BAR_TEMPLATE_TABLE)


	
-- Set bar label
	function barPrototype:SetLabel(strText)
		self.wndLabel:SetText(strText)
	end

-- Set whether the bar should fill up instead of draining, default: false
	function barPrototype:SetFill(blFill)
		self.fill = blFill
		self:SetValue(self.timeElapsed)
	end

-- Set the bar's total duration in seconds.
	function barPrototype:SetDuration(intSeconds)
		self.timeTotal = intSeconds
		self.timeRemaining = max(0, self.timeTotal - self.timeElapsed)
		self.wndProgressBar:SetMax(self.timeTotal)
		self:SetValue(self.timeElapsed)
	end

-- Start the bar
	function barPrototype:Start()
		self.isRunning = true
		_timer:Start()
	end

-- Destroy the bar
	function barPrototype:Stop()
		if self.onFinishCallbacks then
			for _, cb in pairs(self.onFinishCallbacks) do
				cb.object[cb.method](cb.object, self)
			end
		end

		self.wndFrame:Destroy()
		_bars[self.id] = nil

	end

-- Set whether the bar should show time remaining, default: true
	function barPrototype:SetTimeVisibility(blVisible)
		self.wndDuration:Show(blVisible)
		self.showRemaining = blVisible
	end

-- Set the bar's elapsed time
	function barPrototype:SetValue(intElapsed)
		self.timeElapsed = intElapsed
		self.timeRemaining = max(0, self.timeTotal - self.timeElapsed)

		self.wndProgressBar:SetProgress(self.fill and self.timeElapsed or self.timeRemaining)
		if self.showRemaining then
			self.wndDuration:SetText(strformat("%.1fs", self.timeRemaining))
		end
	end

-- Set the bar's width
	function barPrototype:SetWidth(intWidth)
		local left, top, right, bottom = self.wndFrame:GetAnchorOffsets()
		self.wndFrame:SetAnchorOffsets(left, top, left + intWidth, bottom)
	end

-- Seth the bar's height. Also called on icon changes to reset anchor offsets
	function barPrototype:SetHeight(intHeight)
		if intHeight == nil then
			_,_,_,intHeight = self.wndIcon:GetAnchorOffsets()
		end
		
		local left, top, right, bottom = self.wndFrame:GetAnchorOffsets()
		self.wndFrame:SetAnchorOffsets(left, top, right, top + intHeight)

		local left, top, right, bottom = self.wndIcon:GetAnchorOffsets()
		if self.wndIcon:GetSprite() ~= "" then
			self.wndIcon:SetAnchorOffsets(left, top, intHeight, intHeight)
		else
			self.wndIcon:SetAnchorOffsets(left, top, 0, intHeight)
			intHeight = 0
		end

		local left, top, right, bottom = self.wndProgressBar:GetAnchorOffsets()
		self.wndProgressBar:SetAnchorOffsets(intHeight, top, right, bottom)

		local left, top, right, bottom = self.wndLabel:GetAnchorOffsets()
		self.wndLabel:SetAnchorOffsets(intHeight + 5, top, right, bottom)

	end

-- Set the bar's icon
	function barPrototype:SetIcon(strSprite)
		strSprite = strSprite or ""
		self.wndIcon:SetSprite(strSprite)
		self:SetHeight()
	end

-- Set the bar's font
	function barPrototype:SetFont(strFont)
		self.wndLabel:SetFont(strFont)
		self.wndDuration:SetFont(strFont)
	end

-- Set the bar's text color
	function barPrototype:SetTextColor(strColor)
		self.wndLabel:SetTextColor(strColor)
		self.wndDuration:SetTextColor(strColor)
	end
	
-- Set the bar's backdrop texture & color
	function barPrototype:SetTextureBG(strSprite, strColor)
		if strSprite then
			self.wndFrame:SetSprite(strSprite)
		end
		self.wndFrame:SetBGColor(strColor)
	end

-- Set the bar's texture & color
	function barPrototype:SetTextureBar(strSprite, strColor)
		if strSprite then
			self.wndProgressBar:SetFullSprite(strSprite)
		end
		self.wndProgressBar:SetBarColor(strColor)
	end

-- Add callbacks firing on bar update
	function barPrototype:AddOnUpdateCallback(strMethod, objSelf)
		self.onUpdateCallbacks[#self.onUpdateCallbacks+1] = { method = strMethod, object = objSelf }
	end

-- Add callbacks firing on bar stop
	function barPrototype:AddOnFinishCallback(strMethod, objSelf)
		self.onFinishCallbacks[#self.onFinishCallbacks+1] = { method = strMethod, object = objSelf }
	end

-- Bar factory
	function LibSimpleBars.CreateBar(intId, wndParent, intWidth, intHeight)

		-- just destroy it
		if _bars[intId] ~= nil then
			_bars[intId]:Stop()
		end
		
		local wndFrame = Apollo.LoadForm(BAR_TEMPLATE_XMLDOC, "BarTemplate", wndParent, self)
		
		wndFrame:SetData({ barId = intId })
		
		local newBar = setmetatable( {
			id = intId,
			wndFrame = wndFrame,
			wndLabel = wndFrame:FindChild("Label"),
			wndDuration = wndFrame:FindChild("Duration"),
			wndIcon = wndFrame:FindChild("Icon"),
			wndProgressBar = wndFrame:FindChild("ProgressBar"),
			
			fill = false,
			showRemaining = true,
			timeElapsed = 0,
			onUpdateCallbacks = {},
			onFinishCallbacks = {},
		}, mt )

		if intWidth ~= nil then
			newBar:SetWidth(intWidth)
		end
		
		if intHeight ~= nil then
			newBar:SetHeight(intHeight)
		end

		_bars[intId] = newBar
		
		return _bars[intId]

		end
end

--------------------
--  Library functions  --
--------------------

do
	local BAR_UPDATE_FREQUENCY = 0.1 
	local _lastUpdate

	-- should really be a local function, but ApolloTimer is dumb
	function LibSimpleBars:_ProcessBars()
		local currentTime = getTime()
		
		local diff = _lastUpdate and ( currentTime - _lastUpdate ) or BAR_UPDATE_FREQUENCY -- on first run after stop, difference estimated
		for _, bar in next, _bars do
			if bar.isRunning ~= nil then
				if bar.timeRemaining <= diff then
					bar:Stop()
				else
					bar:SetValue(bar.timeElapsed + diff)
					if bar.onUpdateCallbacks then
						for _, cb in next, bar.onUpdateCallbacks do
							cb.object[cb.method](cb.object, bar)
						end
					end
				end
			end
		end

		if next(_bars) == nil then
			_timer:Stop()
			_lastUpdate = nil
		else
			_lastUpdate = currentTime
		end
	end

	-- Retrieve existing bar object
	function LibSimpleBars.GetBar(id)
		return _bars[id]
	end

	function LibSimpleBars:OnLoad()
		_timer = ApolloTimer.Create(BAR_UPDATE_FREQUENCY, true, "_ProcessBars", self)
		_timer:Stop()
	end
end

Apollo.RegisterPackage(LibSimpleBars, MAJOR, MINOR, {})
