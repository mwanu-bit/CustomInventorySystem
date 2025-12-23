
-----[[SERVICES]]-----
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

--Remove the default roblox gui
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

------[[VARIABLES]]-----
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

--// Ui
local PlayerGui = Player:WaitForChild("PlayerGui")

local ToolButtonTemplate = ReplicatedStorage.Assets.UiTemplates.toolButtonTemplate
local CustomInventoryFolder = PlayerGui:WaitForChild("MainGui"):WaitForChild("CustomInventory")

local hotBarFrame :Frame = CustomInventoryFolder:WaitForChild("hotBar")
local Inventory   :ImageLabel = CustomInventoryFolder:WaitForChild("Inventory")
local SearchBox :TextBox= Inventory:WaitForChild("SearchBox")

local EmptyButtonTemplate = ReplicatedStorage.Assets.UiTemplates:WaitForChild("emptyButtonTemplate")

local KeyBoard_Inputs = {
    Enum.KeyCode.One;
    Enum.KeyCode.Two;
    Enum.KeyCode.Three;
    Enum.KeyCode.Four;
    Enum.KeyCode.Five;
    Enum.KeyCode.Six;
    Enum.KeyCode.Seven;
    Enum.KeyCode.Eight;
    Enum.KeyCode.Nine
}

local TOUCH_INPUT_SENSITIVITY = 40

------[[SYSTEM STATE]]-----
local SlotNumber = 9
local Buttons = {}
local EquippedTool = nil
local CurrentDragButton = nil
local BackPackConn = nil
local CharacterConn = nil
local ToolConns = {}
local HasInitialized = false

------[[BUTTON CLASS]]-----
local ButtonClass = {}
ButtonClass.__index = ButtonClass

function ButtonClass.new(button :TextButton, tool :Tool)
    local self = setmetatable({}, ButtonClass)

    self.Button = button
    self.Tool = tool

    self.Equipped = false
    self.is_Dragging = false

    self.DragStartPosition = nil
    self.DragFrame = nil  -- We store a temporary Drag Frame

    self.Button.toolName.Text = tool.Name
    self.Button.Name = tool.Name

    if tool.TextureId then
        self.Button.toolIcon.Image = tool.TextureId
        self.Button.toolIcon.Visible = true
    end
    tool:SetAttribute("Processed",true)

    local RemainingSlots = SlotNumber
    if RemainingSlots > 0 then

        local UsedUpSlots = 9 - RemainingSlots
        local LayoutOrder = math.clamp(UsedUpSlots + 1,1,9)

        self.Button.LayoutOrder = LayoutOrder
        self.Button.toolNumber.Text = LayoutOrder

        SlotNumber -= 1
        self.Button.Parent = hotBarFrame

    else
        self.Button.Parent = Inventory.Frame

    end

    Buttons[self.Button] = self
    self:On_Input()

    self.Tool.Destroying:Connect(function()
        self:CleanUp()
    end)

    return self
end

------[[FUNCTIONS]]-----
--Function is called to reorganize ethe hotbar
local function Organize_HotBar()
    local HotBarButtons = {}

    for i,v in ipairs(hotBarFrame:GetChildren()) do
        if v:IsA("ImageButton") then
            table.insert(HotBarButtons,v)
        end
    end

    table.sort(HotBarButtons,function(a,b)
        return a.LayoutOrder < b.LayoutOrder
    end)


    for i,Button in ipairs(HotBarButtons) do
        if Button:IsA("ImageButton") then
            Button.LayoutOrder = i
            Button.toolNumber.Text = Button.LayoutOrder
        end
    end
end

--Function is called when the player inputs  [``] to open the inventory
local function OpenInventory()
    if not Inventory then
        return
    end

    Inventory.Visible = not Inventory.Visible
    if Inventory.Visible then
        local HotBarButtons = {}

        for i,v in ipairs(hotBarFrame:GetChildren()) do
            if v:IsA("ImageButton") then
                table.insert(HotBarButtons,v)
            end
        end

        local Remaining_to_fill = 9 - #HotBarButtons
        if Remaining_to_fill > 0 then
            for i = 1,Remaining_to_fill do
                local LayoutOrder = #HotBarButtons + 1

                local EmptyButton = EmptyButtonTemplate:Clone()
                EmptyButton.Visible = true

                EmptyButton.LayoutOrder = LayoutOrder

                EmptyButton.toolNumber.Text = LayoutOrder
                EmptyButton.Parent = hotBarFrame

                table.insert(HotBarButtons,EmptyButton)
            end
        end

    else
        for _,Button in ipairs(hotBarFrame:GetChildren()) do
            if Button.Name == "emptyButtonTemplate" then
                Button:Destroy()
            end
        end

        Organize_HotBar()
    end
end

--Function sets up tehs earch box
local function SetUpSearchBox()
    local InventoryButtons = {}
    local IsFocused = false

    SearchBox.Focused:Connect(function()
        IsFocused = true
        for _,Button in ipairs(Inventory.Frame:GetChildren()) do
            if Button:IsA("ImageButton") then
                InventoryButtons[Button.Name] = Button
            end
        end
    end)

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        if not IsFocused then
            return
        end

        local SearchBoxText = SearchBox.Text
        local TextAmount = #SearchBoxText

        for ButtonName,Button in pairs(InventoryButtons) do
            local ButtonNameText = string.sub(ButtonName,1,TextAmount)
            if ButtonNameText ~= SearchBoxText then
                Button.Parent = nil
            else
                Button.Parent = Inventory.Frame
            end
        end
    end)

    SearchBox.FocusLost:Connect(function(enterPressed)
        for _,Button in ipairs(Inventory.Frame:GetChildren()) do
            if Button:IsA("ImageButton") then
                Button.Parent = Inventory.Frame
            end
        end
        IsFocused = false
    end)
end

--Function sets up a toool added to the players back pack
local function SetupTool(Tool:Tool)
    if not Tool:IsA("Tool") then
        return
    end

    local already_processed = Tool:GetAttribute("Processed")
    if already_processed then
        return
    end

    local ClonedButton = ToolButtonTemplate:Clone()
    ClonedButton.Visible = true

    local ButtonObj = ButtonClass.new(ClonedButton,Tool)
    return ButtonObj
end

--INIT()
local function initialize()
    local Character = Player.Character or Player.CharacterAdded:Wait()

    local Backpack = Player:WaitForChild("Backpack")
    local StarterGear = Player:WaitForChild("StarterGear")

    for _,Tool in ipairs(Backpack:GetChildren()) do
        SetupTool(Tool)
    end

    BackPackConn = Backpack.ChildAdded:Connect(function(Child)
        SetupTool(Child)
    end)

    CharacterConn = Character.ChildAdded:Connect(function(Child)
        if not Child:IsA("Tool") then
            return
        end

        local ButtonObj = SetupTool(Child)
        if not ButtonObj then
            return
        end

        ButtonObj:On_ButtonClick(true)        
    end)

    HasInitialized = true

end

-- A reset function to hanle player death
local function Reset()

    for _,ToolConnection in pairs(ToolConns) do
        for _,Connection in ipairs(ToolConnection) do
            Connection:Disconnect()            
        end
    end

    table.clear(ToolConns)

    table.clear(Buttons)
    SlotNumber = 9

    EquippedTool = nil
    CurrentDragButton = nil

    if BackPackConn then
        BackPackConn:Disconnect()
        BackPackConn = nil
    end

    if CharacterConn then
        CharacterConn:Disconnect()
        CharacterConn = nil
    end

end

------[[CLASS METHODS]]-----
--Function equip or unequips the tool when its corresponding button is clicked
function ButtonClass:On_ButtonClick(Is_New:boolean)
    if self.is_Dragging then
        return
    end

    local Character = Player.Character or Player.CharacterAdded:Wait()
    local Humanoid :Humanoid = Character and Character:WaitForChild("Humanoid")

    if not Humanoid then 
        return
    end

    if EquippedTool  then
        if not Is_New then
            Humanoid:UnequipTools()
        end

        local ToolObj = EquippedTool

        ToolObj.Button.BackgroundColor3 = Color3.new(0,0,0)
        ToolObj.Equipped = false     

        EquippedTool = nil

        if ToolObj == self then
            return
        end

    end


    if Is_New then
        if (self.Button.Parent == hotBarFrame) then
            self.Equipped = true

            self.Button.BackgroundColor3 = Color3.new(0.639216, 0.639216, 0.639216)
            EquippedTool = self
            return
        end   
    end

    Humanoid:UnequipTools()

    if not self.Equipped then
        Humanoid:EquipTool(self.Tool)
        self.Equipped = true
        self.Button.BackgroundColor3 = Color3.new(0.639216, 0.639216, 0.639216)
        EquippedTool = self
    end

end

function ButtonClass:On_DragEnd()
    local Button = self.Button
    self.is_Dragging = false

    -- Destroy the drag frame
    if self.DragFrame then
        self.DragFrame:Destroy()
        self.DragFrame = nil
    end

    -- Get UI objects at mouse position
    local guisAtPos = PlayerGui:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y)

    -- Track where to put the button
    local NewParent = nil
    local NewLayoutOrder = nil
    local Handled = false

    if guisAtPos then
        for _,gui in ipairs(guisAtPos) do
            -- Skip the drag frame and button itself
            if gui == self.DragFrame or gui == Button then
                continue
            end

            -- Check for Inventory drop
            if gui.Name == "Inventory" then
                if not Inventory.Visible then
                    continue
                end

                NewParent = Inventory.Frame
                NewLayoutOrder = 0
                Button.toolNumber.Text = ""
                SlotNumber += 1

                -- Add empty button to hotbar
                local TotalItemsInHotbar = 0
                for _,Item in ipairs(hotBarFrame:GetChildren()) do
                    if Item:IsA("ImageButton") then
                        TotalItemsInHotbar += 1
                    end
                end

                if TotalItemsInHotbar < 9 then
                    local EmptyButton = EmptyButtonTemplate:Clone()
                    EmptyButton.Visible = true
                    EmptyButton.LayoutOrder = TotalItemsInHotbar + 1
                    EmptyButton.toolNumber.Text = EmptyButton.LayoutOrder
                    EmptyButton.Parent = hotBarFrame
                end

                Handled = true
                break

                -- Check for hotbar button swap
            elseif gui:IsA("ImageButton") and gui.Parent == hotBarFrame then
                local targetLayoutOrder = gui.LayoutOrder

                -- If coming from hotbar, swap positions
                if Button.Parent == hotBarFrame then
                    if gui == Button then
                        continue
                    end

                    -- Swap layout orders
                    local currentLayoutOrder = Button.LayoutOrder
                    gui.LayoutOrder = currentLayoutOrder
                    gui.toolNumber.Text = tostring(currentLayoutOrder)

                    Button.LayoutOrder = targetLayoutOrder
                    Button.toolNumber.Text = tostring(targetLayoutOrder)

                    Organize_HotBar()

                    -- If coming from inventory, replace
                elseif Button.Parent == Inventory.Frame then
                    if not Inventory.Visible then
                        continue
                    end

                    NewParent = hotBarFrame
                    NewLayoutOrder = targetLayoutOrder
                    Button.toolNumber.Text = tostring(targetLayoutOrder)

                    -- Move displaced button to inventory
                    if gui.Name == "emptyButtonTemplate" then
                        gui:Destroy()
                    else
                        gui.toolNumber.Text = ""
                        gui.LayoutOrder = 0
                        gui.Parent = Inventory.Frame
                    end

                    SlotNumber -= 1
                end

                Handled = true
                break

                -- Check for hotbar frame drop (empty spot)
            elseif gui == hotBarFrame then
                -- Check if already in hotbar
                if Button.Parent == hotBarFrame then
                    continue
                end

                -- Find empty spot
                local TotalItemsInHotbar = 0
                local occupiedSlots = {}

                for _,Item in ipairs(hotBarFrame:GetChildren()) do
                    if Item:IsA("ImageButton") then
                        TotalItemsInHotbar += 1
                        occupiedSlots[Item.LayoutOrder] = true
                    end
                end

                if TotalItemsInHotbar >= 9 then
                    continue
                end

                -- Find first empty layout order
                for i = 1, 9 do
                    if not occupiedSlots[i] then
                        NewParent = hotBarFrame
                        NewLayoutOrder = i
                        Button.toolNumber.Text = tostring(i)
                        SlotNumber -= 1
                        Handled = true
                        break
                    end
                end

                if Handled then break end
            end
        end
    end

    -- Reset button properties
    Button.SizeConstraint = Enum.SizeConstraint.RelativeYY
    Button.Size = UDim2.fromScale(1,1)

    -- Move button to new parent if handled
    if Handled and NewParent then
        Button.Parent = NewParent
        if NewLayoutOrder then
            Button.LayoutOrder = NewLayoutOrder
        end
    else
        -- Return to original parent
        if Button.Parent ~= hotBarFrame and Button.Parent ~= Inventory.Frame then
            Button.Parent = (Button.toolNumber.Text == "" and Inventory.Frame) or hotBarFrame
        end
    end

    Organize_HotBar()
end

function ButtonClass:On_Drag()
    local Button = self.Button

    if EquippedTool then
        local ToolObj = EquippedTool
        if ToolObj == self then
            local Character = Player.Character or Player.CharacterAdded:Wait()
            local Humanoid :Humanoid = Character and Character:WaitForChild("Humanoid")

            Humanoid:UnequipTools()

            ToolObj.Button.BackgroundColor3 = Color3.new(0,0,0)
            EquippedTool = nil
        end
    end

    self.is_Dragging = true

    -- Create drag frame 
    self.DragFrame = Button:Clone()
    self.DragFrame.Size = UDim2.fromScale(0.063,0.1)
    self.DragFrame.Parent = PlayerGui
    self.DragFrame.ZIndex = 100  -- Ensure it's on top

    -- Make original button semi-transparent
    Button.ImageTransparency = 0.5
    Button.toolIcon.ImageTransparency = 0.5
    Button.toolName.TextTransparency = 0.5
    Button.toolNumber.TextTransparency = 0.5

    self.dragConn = nil
    self.dragConn = RunService.Heartbeat:Connect(function()
        if not self.is_Dragging or not self.DragFrame then 
            self.dragConn:Disconnect()
            self.dragConn = nil
            return
        end

        self.DragFrame.Position = UDim2.fromOffset(Mouse.X - 25, Mouse.Y - 25)
    end)
end

-- Function to handle button input
function ButtonClass:On_Input()

    self.MouseMoveConnection = nil
    self.MouseButton1Connection = nil

    local Button :ImageButton = self.Button
    if not Button then
        return
    end

    self.MouseButton1Connection = Button.MouseButton1Down:Connect(function()
        self.is_Dragging = false
        self.DragStartPosition = nil

        CurrentDragButton = self
        self.DragStartPosition = Vector2.new(Mouse.X,Mouse.Y) 

        self.MouseMoveConnection = RunService.Heartbeat:Connect(function()
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                self.MouseMoveConnection:Disconnect()
                return
            end

            local CurrentMousePos = Vector2.new(Mouse.X,Mouse.Y)
            local distance = (CurrentMousePos - self.DragStartPosition).Magnitude

            if distance > TOUCH_INPUT_SENSITIVITY or not self.Button then 
                self.MouseMoveConnection:Disconnect()
                self:On_Drag()
            end
        end)

    end)

end

--Method cleans up teh whole class
function ButtonClass:CleanUp()
    if EquippedTool == self then
        EquippedTool = nil
    end

    if CurrentDragButton == self then
        CurrentDragButton = nil
    end

    if self.MouseButton1Connection then
        self.MouseButton1Connection:Disconnect()
        self.MouseButton1Connection = nil
    end

    if self.MouseMoveConnection then
        self.MouseMoveConnection:Disconnect()
        self.MouseMoveConnection = nil
    end

    if self.dragConn then
        self.dragConn:Disconnect()
        self.dragConn = nil
    end

    if self.DragFrame then
        self.DragFrame:Destroy()
        self.DragFrame = nil
    end

    if self.Button then
        self.Button:Destroy()
        self.Button = nil               
    end

    self.Tool = nil
end



------[[INPUT HANDLERS]]-----
UserInputService.InputBegan:Connect(function(Input,Processed)
    if not Input then 
        return
    end

    if Input.KeyCode == Enum.KeyCode.Backquote then
        --Opens our inventory
        OpenInventory()
        return
    end

    local numberInput = table.find(KeyBoard_Inputs,Input.KeyCode)
    if not numberInput then
        return
    end

    local ButtonObj = nil
    for _,Button in ipairs(hotBarFrame:GetChildren()) do
        if Button:IsA("ImageButton")  and Button.LayoutOrder == numberInput then
            ButtonObj = Buttons[Button]
            break
        end
    end

    if not ButtonObj then
        return
    end

    ButtonObj:On_ButtonClick()
end)

UserInputService.InputEnded:Connect(function(Input,Processed)
    local ButtonObj = CurrentDragButton
    if not ButtonObj then 
        return
    end

    local Button = ButtonObj.Button

    if not Input or Input.UserInputType ~= Enum.UserInputType.MouseButton1 or not ButtonObj.DragStartPosition then
        return
    end

    local DragEndPosition = Vector2.new(Mouse.X,Mouse.Y)
    local distance = (DragEndPosition - ButtonObj.DragStartPosition).Magnitude

    -- If the input ends and the player was dragging we call on drag end
    if ButtonObj.is_Dragging then
        ButtonObj:On_DragEnd()

        -- Reset transparency
        Button.ImageTransparency = 0
        Button.toolIcon.ImageTransparency = 0
        Button.toolName.TextTransparency = 0
        Button.toolNumber.TextTransparency = 0

    elseif distance <= TOUCH_INPUT_SENSITIVITY then 
        -- Clicked, not dragged
        ButtonObj:On_ButtonClick()

    end
end)

------[[INITIALIZATION]]-----
initialize()
SetUpSearchBox()

--Reintializes the whole system if the player respawns
Player.CharacterAdded:Connect(function(Character)
    if HasInitialized then
        Reset()
        initialize()
    end

end)
