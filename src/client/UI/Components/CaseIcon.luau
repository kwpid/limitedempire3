-- a case's icon: the shared case image (CaseData.caseImage) tinted with the case color, with the case's featured
-- item on the front as an emblem. a case with its own image (icon in CaseData) shows that instead, untinted.
-- props: case, size (UDim2), position?, anchorPoint?, zIndex?, emblem? (default true, off for tiny icons)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ItemRegistry = require(ReplicatedStorage.Shared.Items.ItemRegistry)
local CaseData = require(ReplicatedStorage.Shared.Cases.CaseData)

local e = React.createElement

-- where the emblem sits on the case image, as a fraction of the icon size. tune these to fit the case art
local EMBLEM_SIZE = 0.5
local EMBLEM_POSITION = Vector2.new(0.5, 0.56)

local function CaseIcon(props)
	local case = props.case
	local zIndex = props.zIndex or 1
	local custom = case.image ~= nil

	return e("ImageLabel", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		Image = if custom then case.image else `rbxassetid://{CaseData.caseImage}`,
		ImageColor3 = if custom then Color3.new(1, 1, 1) else case.color,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = zIndex,
	}, {
		Emblem = if not custom and props.emblem ~= false
			then e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(EMBLEM_POSITION.X, EMBLEM_POSITION.Y),
				Size = UDim2.fromScale(EMBLEM_SIZE, EMBLEM_SIZE),
				BackgroundTransparency = 1,
				Image = ItemRegistry.thumbnail(case.iconAssetId, 150),
				ZIndex = zIndex + 1,
			})
			else nil,
	})
end

return CaseIcon
