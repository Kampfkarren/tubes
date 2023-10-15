local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ServerState = require(ReplicatedStorage.Demo.ServerState)
local Tubes = require(ReplicatedStorage.Packages.Tubes)

local e = React.createElement

local function createNextOrder()
	local layoutOrder = 0

	return function()
		layoutOrder += 1
		return layoutOrder
	end
end

local function ChatWindow(props: {
	channelId: string?,
})
	local userId = Tubes.useLocalUserId()

	local defaultState = React.useMemo(function()
		local newDefaultState = table.clone(ServerState.defaultState)

		newDefaultState.members = {
			[tostring(userId)] = {
				name = "LocalPlayer",
			},
		}

		return newDefaultState
	end, {})

	local serverState, sendEvent =
		Tubes.useChannel(props.channelId, ServerState.process, defaultState, ServerState.serializers)

	local nextOrder = createNextOrder()

	local memberNames = {}
	if serverState == nil then
		table.insert(memberNames, "Still connecting...")
	else
		for _, member in serverState.members do
			table.insert(memberNames, member.name)
		end
	end

	local chatMessages: { [string]: React.ReactNode } = {}
	if serverState ~= nil then
		for index, message in serverState.messages do
			chatMessages["Message" .. index] = e("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				LayoutOrder = index,
				RichText = true,
				Text = `<b>{message.name}:</b> {message.contents}`,
				TextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.fromScale(1, 0),
			})
		end
	end

	local topbarHeight, setTopbarHeight = React.useState(GuiService.TopbarInset.Height)
	React.useEffect(function()
		local connection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
			setTopbarHeight(GuiService.TopbarInset.Height)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	return e("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8 + topbarHeight),
		}),

		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		Members = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			LayoutOrder = nextOrder(),
			Text = `Members: {table.concat(memberNames, ", ")}`,
			TextSize = 32,
			Size = UDim2.new(1, 0, 0, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Chats = e("ScrollingFrame", {
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.new(0.92, 0.92, 0.92),
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 1, -100),
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
		}, chatMessages),

		ChatInput = e("Frame", {
			BackgroundColor3 = Color3.new(0.92, 0.92, 0.92),
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 40),
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),

			ChatBox = e("TextBox", {
				BackgroundTransparency = 1,
				ClearTextOnFocus = false,
				Font = Enum.Font.Gotham,
				PlaceholderText = "Enter your chat...",
				Size = UDim2.new(1, -64, 1, 0),
				Text = "",
				TextSize = 32,
				TextXAlignment = Enum.TextXAlignment.Left,

				[React.Event.FocusLost] = function(textBox: TextBox)
					sendEvent({
						type = "chat",
						contents = textBox.Text,
					})

					textBox.Text = ""
				end,
			}),
		}),
	})
end

return ChatWindow
