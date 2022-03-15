--[[

	Description: Responsible for UI
	Author: Expertcoderz
	Date: 03/15/2022

--]]

local Root, Utilities, Service, Package;

local function assert(value: any?, errorMessage: string?): any?
	--// More performant than vanilla assert
	return if value then value else error(errorMessage or "assertion failed!", 2)
end

local RemoteCommands = {
	UI_LoadModule = function(data, ...)
		Root.DebugWarn("LOAD UI MODULE", data, ...)
		return Root.UI:MountInterface(data, ...);
	end;
}

local UI = table.freeze {
	_WrappedObjectStore = setmetatable({} :: {Instance:WrappedObject}, {
		__mode = "k",
		__newindex = function(s, i, v)
			assert(typeof(i) == "Instance", "Only Instances are allowed as keys for items in WrappedObjectStore, got "..typeof(i))
			rawset(s, i, v)
		end}),
	_ActiveInterfaces = {} :: {[string]:InterfaceData},

	ClassInfoStore = {} :: {[string]:ClassInfo},
	UserConfiguration = {},

	Themes = {},

	IsWrappedObj = function(self, obj: any): boolean
		return typeof(obj) == "userdata" and getmetatable(obj) == "AdonisUI_InstanceProxy"
	end,
	IsWrappedSignal = function(self, signal: any): boolean
		return typeof(signal) == "userdata" and getmetatable(signal) == "AdonisUI_ScriptSignal"
	end,

	UnWrap = function(self, fake: any): any
		if type(fake) == "table" then
			local real = {}
			for k, v in pairs(fake) do
				real[k] = self:UnWrap(v)
			end
			return real
		elseif self:IsWrappedObj(fake) then
			return fake._objectRef
		elseif self:IsWrappedSignal(fake) then
			return fake.bindable
		end
		return fake
	end,

	getSignal = function(self, obj: WrappedObject, eventName: string, realSignal: RBXScriptSignal?): ScriptSignal
		local signal = obj._data.scriptSignals[eventName]
		if not signal then
			local realSignalConnection = realSignal and realSignal:Connect(function(...)
				return signal:Fire(...)
			end)

			signal = newproxy(true)
			local meta = getmetatable(signal)

			meta.__metatable = "AdonisUI_ScriptSignal"
			meta.__type = "AdonisUIScriptSignal"
			meta.__tostring = function() return "Signal "..eventName end
			meta.__index = {
				bindable = Instance.new("BindableEvent"),
				activeConnections = {},

				Connect = function(s, callback)
					local conn = s.bindable.Event:Connect(function(...)
						return callback(unpack(self:Wrap({...})))
					end)
					s.activeConnections[conn] = conn.Connected
					return conn
				end,
				ConnectOnce = function(s, callback)
					local conn; conn = s:Connect(function(...)
						conn:Disconnect()
						s.activeConnections[conn] = nil
						return callback(...)
					end)
					return conn
				end,
				ConnectParallel = function(s, callback)
					local conn = s.bindable.Event:ConnectParallel(function(...)
						return callback(unpack(self:Wrap({...})))
					end)
					s.activeConnections[conn] = conn.Connected
					return conn
				end,
				Destroy = function(s)
					s:DisconnectAll()
					if realSignalConnection then
						realSignalConnection:Disconnect()
					end
					s.bindable:Destroy()
					obj._data.scriptSignals[eventName] = nil
				end,
				DisconnectAll = function(s)
					for conn in pairs(s.activeConnections) do
						conn:Disconnect()
						s.activeConnections[conn] = nil
					end
				end,
				Fire = function(s, ...)
					for conn in pairs(s.activeConnections) do
						--// only fire when connections exist
						return s.bindable:Fire(unpack(self:UnWrap({...})))
					end
				end,
				Wait = function(s)
					return unpack(self:Wrap({s.bindable.Event:Wait()}))
				end,
			}

			obj._data.scriptSignals[eventName] = signal
		end
		return signal
	end,

	getClassInfo = function(self, classOrObj: Class|Object): ClassInfo?
		if not classOrObj then return nil end

		local className: string = if type(classOrObj) == "string" then classOrObj
			elseif self:IsWrappedObj(classOrObj) then (classOrObj::WrappedObject).Class
			else (classOrObj::ClassInfo).ClassName or ("ANONYMOUS_"..Utilities:RandomString())

		local classInfo: ClassInfo = if not self.ClassInfoStore[className] then if type(classOrObj) == "table" then classOrObj else {ClassName =  className}
		else self.ClassInfoStore[className]
			classInfo.Members, classInfo.Events = classInfo.Members or {}, classInfo.Events or {}

			for ind, func in pairs({
				--// Extended instance functionality
				Add = function(obj, tree)
					tree.Parent = obj._objectRef
					return self:Construct(tree)
				end,
				AssociateEvent = function(obj, event, callback)
					local connection = event:Connect(callback)
					obj._data.associatedEventsConnections[connection] = event
					return connection
				end,
				Tween = function(obj, props, tweenInfo)
					local tween = Service.TweenService:Create(obj._objectRef, tweenInfo or TweenInfo.new(0.5), props)
					tween:Play()
					return tween
				end,
				TweenTransparency = function(obj, targetTransparency, tweenInfo, includeTextAndImages, recursive)
					tweenInfo = if tweenInfo and typeof(tweenInfo) == "TweenInfo" then tweenInfo
						elseif tweenInfo then TweenInfo.new(tweenInfo)
						else TweenInfo.new(0.5)
					
					for _, v in pairs(if recursive ~= false then Utilities:AddRange(obj._objectRef:GetDescendants(), obj._objectRef) else {obj._objectRef}) do
						if v:IsA("GuiObject") then
							task.spawn(function()
								local props = {BackgroundTransparency = targetTransparency}
								if includeTextAndImages ~= false then
									if v:IsA("ImageLabel") or v:IsA("ImageButton") then
										props.ImageTransparency = targetTransparency
									elseif v:IsA("TextLabel") or v:IsA("TextButton") then
										props.TextTransparency = targetTransparency
									end
								end
								Service.TweenService:Create(v, tweenInfo, props):Play()
							end)
						end
					end
				end,
				AddToDebris = function(obj, lifetime)
					Service.Debris:AddItem(obj._objectRef, lifetime or 5)
				end,
				SelectChildren = function(obj, callback, recursive, single)
					if type(callback) == "string" then
						local name = callback
						callback = function(c) return c.Name == name end
					end
					local selected = {}
					for _, child in ipairs(if recursive then obj:GetDescendants() else obj:GetChildren()) do
						if callback(child) then
							if single then return child end
							table.insert(selected, child)
						end
					end
					return if single then nil else selected
				end,
				SelectAncestors = function(obj, callback, single)
					if type(callback) == "string" then
						local name = callback
						callback = function(a) return a.Name == name end
					end
					local selected, current = {}, obj.Parent
					while current do
						if callback(current) then
							if single then return current end
							table.insert(selected, current)
						end
						current = current.Parent
					end
					return if single then nil else selected
				end,
				WaitForChildOfClass = function(obj, className, timeout)
					assert(className, "Argument 1 missing or nil")
					local child = obj:FindFirstChildOfClass(className)
					if not child then
						local timeleft = timeout or math.huge
						if not timeout then
							task.delay(5, function()
								if not child then
									warn(string.format("Infinite yield possible on '%s:WaitForChildOfClass(\"%s\")'", obj.Name, className))
								end
							end)
						end
						repeat
							timeleft -= task.wait()
							child = obj and obj:FindFirstChildOfClass(className)
						until child or timeleft <= 0 or not obj
					end
					return self:Wrap(child)
				end,
				WaitForChildWhichIsA = function(obj, className, timeout)
					assert(className, "Argument 1 missing or nil")
					local child = obj:FindFirstChildWhichIsA(className)
					if not child then
						local timeleft = timeout or math.huge
						if not timeout then
							task.delay(5, function()
								if not child then
									warn(string.format("Infinite yield possible on '%s:WaitForChildWhichIsA(\"%s\")'", obj.Name, className))
								end
							end)
						end
						repeat
							timeleft -= task.wait()
							child = obj and obj:FindFirstChildWhichIsA(className)
						until child or timeleft <= 0 or not obj
					end
					return self:Wrap(child)
				end,

				--// Wrapped/overwritten methods
				IsA = function(obj, className)
					assert(className, "Argument 1 missing or nil")
					return obj.Class == className or (obj._objectRef:IsA(className) and obj._objectRef.ClassName ~= className)
				end,

				GetFullName = function(obj)
					local ancestors, current = {obj.Name}, obj.Parent
					while current do
						if current._objectRef ~= game then
							table.insert(ancestors, 1, current.Name)
						end
						current = current.Parent
					end
					return table.concat(ancestors, ".")
				end,
				GetChildren = function(obj)
					local children = {}
					for _, child in ipairs(obj._containerRef:GetChildren()) do
						if not child:GetAttribute("__IGNORE") then
							table.insert(children, self:Wrap(child))
						end
					end
					return children
				end,
				GetDescendants = function(obj)
					local descendants = {}
					for _, desc in ipairs(obj._containerRef:GetDescendants()) do
						if not desc:GetAttribute("__IGNORE") then
							table.insert(descendants, self:Wrap(desc))
						end
					end
					return descendants
				end,
				ClearAllChildren = function(obj)
					for _, child in pairs(obj:GetChildren()) do
						child:Destroy()
					end
				end,
				Clone = function(obj, newParent)
					local cloned = obj._objectRef:Clone()
					cloned.Parent = self:UnWrap(newParent)
					local cInfo = self:getClassInfo(obj)
					cloned = self:Wrap(cloned, cInfo)
					if cInfo.Initialize then
						cInfo.Initialize(cloned, cloned._objectRef, Root)
					end
					return cloned
				end,
				Destroy = function(obj)
					if not obj._data.destroyed then
						obj._data.destroyed = false
						obj.Destroying:Fire()
						--obj.Parent = nil
						for conn in pairs(obj._data.associatedEventsConnections) do
							conn:Disconnect()
						end
						obj._data.associatedEventsConnections = {}
						for _, signal in pairs(obj._data.scriptSignals) do
							signal:Destroy()
						end
						for _, desc in pairs(obj._objectRef:GetDescendants()) do
							desc:Destroy()
						end
						obj._objectRef:Destroy()
						self._WrappedObjectStore[obj._objectRef] = nil
					end
				end,
				FindFirstAncestor = function(obj, name)
					assert(name, "Argument 1 missing or nil")
					return obj:SelectAncestors(name, true)
				end,
				FindFirstAncestorOfClass = function(obj, className)
					assert(className, "Argument 1 missing or nil")
					return obj:SelectAncestors(function(a) return a.Class == className end, true)
				end,
				FindFirstAncestorWhichIsA = function(obj, className)
					assert(className, "Argument 1 missing or nil")
					return obj:SelectAncestors(function(a) return a:IsA(className) end, true)
				end,
				FindFirstChild = function(obj, name, recursive)
					assert(name, "Argument 1 missing or nil")
					return obj:SelectChildren(name, recursive, true)
				end,
				FindFirstChildOfClass = function(obj, className, recursive)
					assert(className, "Argument 1 missing or nil")
					return obj:SelectChildren(function(c) return c.Class == className end, recursive, true)
				end,
				FindFirstChildWhichIsA = function(obj, className, recursive)
					assert(className, "Argument 1 missing or nil")
					return obj:SelectChildren(function(c) return c:IsA(className) end, recursive, true)
				end,
				GetPropertyChangedSignal = function(obj, propName)
					assert(propName, "Argument 1 missing or nil")
					assert(self:getClassInfo(obj).Members[propName] or pcall(function() return obj._objectRef[propName] end), propName.." is not a valid property name.")
					return self:getSignal(obj, propName.."Changed")
				end,
				WaitForChild = function(obj, ...)
					return self:Wrap(obj._containerRef:WaitForChild(...))
				end,
				} :: {[string]:(WrappedObject, ...any)->(any?)})
			do
				if not classInfo.Members[ind] then
					classInfo.Members[ind] = func
				end
			end

			for _, eventName in pairs({"ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "Destroying"}) do
				if not table.find(classInfo.Events, eventName) then
					table.insert(classInfo.Events, eventName)
				end
			end

			return classInfo
		end,

		Wrap = function(self, real: any, classInfo: ClassInfo): WrappedObject|any
			if type(real) == "function" then
				local wrapped = function(obj: WrappedObject, ...)
					local args = self:UnWrap({...})
					local results = self:Wrap({real(obj._objectRef, unpack(args))}, obj.Class)
					return unpack(results)
				end
				return wrapped
			elseif type(real) == "table" then
				local wrapped = {}
				for k, v in pairs(real) do
					wrapped[k] = self:Wrap(v, classInfo)
				end
				return wrapped
			elseif typeof(real) ~= "Instance" then
				return real
			elseif self._WrappedObjectStore[real] then
				return self._WrappedObjectStore[real]
			end

			classInfo = self:getClassInfo(classInfo) or self:getClassInfo(real.ClassName)
			local className = classInfo.ClassName or real.ClassName

			local obj = newproxy(true) :: WrappedObject
			local metatable = getmetatable(obj)

			local objData = {
				classInfo = classInfo,
				scriptSignals = {},
				associatedEventsConnections = {},
				instance = real,
				container = if classInfo.ContainerPath then classInfo.ContainerPath(real, obj) else real,
				destroyed = false
			}

			metatable.__metatable = "AdonisUI_InstanceProxy"
			metatable.__type = "AdonisUIInstance"
			metatable.__tostring = function() return real.Name end
			metatable.__newindex = function(_, ind: string, val: any)
				assert(type(ind) == "string", string.format("Attempt to index %s with %s (string expected)", className, typeof(ind)))
				local memberInfo = classInfo.Members[ind]
				if memberInfo and type(memberInfo) == "table" then
					assert(memberInfo.Update or memberInfo.Path or not memberInfo.Read, ind.." is a read-only property of "..className)
					local gotType = typeof(self:UnWrap(val))
					if memberInfo.Type and memberInfo.Type ~= "any" then
						local expectedType = memberInfo.Type
						assert(gotType == expectedType or (gotType == "EnumItem" and val.EnumType == expectedType), string.format("Invalid type for %s (%s expected, got %s)", ind, tostring(expectedType), if gotType == "EnumItem" then "Enum."..tostring(val.EnumType) else gotType))
					end
					if memberInfo.Path then
						local target, prop = memberInfo.Path(real, obj)
						target[prop] = val
					end
					if memberInfo.Update then
						memberInfo.Update(real, obj, val)
					elseif not memberInfo.Path then
						objData["__"..ind] = val
					end
				elseif ind == "Parent" then
					local newParent = self:Wrap(val)
					if newParent ~= obj.Parent then
						local oldParent = obj.Parent
						task.spawn(function()
							local current = oldParent
							while current do
								current.DescendantRemoving:Fire(obj)
								current = current.Parent
							end
						end)
						real.Parent = if newParent then newParent._containerRef else nil
						if oldParent then
							oldParent.ChildRemoved:Fire(obj)
						end
						task.spawn(function()
							local current = obj.Parent
							if current then
								current.ChildAdded:Fire(obj)
								while current do
									current.DescendantAdded:Fire(obj)
									current = current.Parent
								end
							end
						end)
					end
				elseif pcall(function() return real[ind] end) then
					real[ind] = if self:IsWrappedObj(val) then val._objectRef else val
				else
					error(string.format("%s is not a valid member of %s \"%s\"", tostring(ind), className, real:GetFullName()), 2)
				end

				self:getSignal(obj, "Changed"):Fire(ind, val)
				self:getSignal(obj, ind.."Changed"):Fire(val)
			end
			metatable.__index = function(_, ind: string)
				assert(type(ind) == "string", string.format("Attempt to index %s with %s (string expected)", className, typeof(ind)))

				local stuff = {
					_AdonisUI = self,
					_data = objData,
					Class = className, ClassName = className,
					_objectRef = real,
					_containerRef = objData.container
				}
				if stuff[ind] then
					return stuff[ind]
				elseif ind == "Parent" then
					local current = real.Parent
					while current and current:GetAttribute("__IGNORE") do
						current = current.Parent
					end
					return self:Wrap(current)
				end

				local memberInfo = classInfo.Members[ind]
				if memberInfo then
					--// ind points to a custom member
					if type(memberInfo) == "table" then
						--// custom member is a property
						if memberInfo.Read then
							return memberInfo.Read(real, obj)
						elseif memberInfo.Path then
							return memberInfo.Path(real, obj)[select(2, memberInfo.Path(real, obj))]
						end
						return objData["__"..ind]
					end
					--// custom member is a method
					return function(s, ...)
						assert(s == obj, "Expected ':' not '.' calling member function "..ind)
						return memberInfo(s, ...)
					end
				elseif objData.scriptSignals[ind] or table.find(classInfo.Events, ind) then
					--// custom instance event
					return self:getSignal(obj, ind)
				elseif pcall(function() return real[ind] end) then
					if typeof(real[ind]) == "RBXScriptSignal" then
						--// vanilla instance event
						return self:getSignal(obj, ind, real[ind])
					end
					--// vanilla instance member property/method or child
					if typeof(real[ind]) ~= "Instance" or not real[ind]:GetAttribute("__IGNORE") or not real[ind]:IsDescendantOf(real) then
						return self:Wrap(real[ind])
					else
						--// fallback child
						local child = obj:FindFirstChild(ind)
						if child then
							return child
						end
					end
				end
				--// nonexistent member index
				error(string.format("%s is not a valid member of %s \"%s\"", tostring(ind), className, real:GetFullName()), 2)
				return nil
			end

			self._WrappedObjectStore[real] = obj
			return obj
		end,

		Construct = function(self, tree: {[string]:any}, classOverride: ClassInfo?, makingCustomObj: boolean?)
			tree = type(tree) == "table" and tree or {Class = tostring(tree)}
			assert(tree.Class, "Class not specified")
			tree.Name = tree.Name or tree.Class

			local classInfo: ClassInfo =  self:getClassInfo(tree.Class)

			local real: Instance = if classInfo.Prefabricated then classInfo.Prefabricated:Clone()
				elseif type(classInfo.Structure) == "table" then self:Construct(classInfo.Structure, classInfo, true)
				else Instance.new(classInfo.ClassName)

			for memberName, memberInfo in pairs(classInfo.Members) do
				if type(memberInfo) == "table" and tree[memberName] == nil and memberInfo.Default ~= nil then
					tree[memberName] = memberInfo.Default
				end
			end

			if classInfo.Prefabricated then
				for _, v in pairs(real:GetDescendants()) do
					v:SetAttribute("__IGNORE", classOverride and classOverride.ClassName or classInfo.ClassName)
				end
			end

			real.Name = tree.Name

			local obj = self:Wrap(real, self:getClassInfo(classOverride or classInfo))

			local eventsToConnect = {}

			local parent = tree.Parent
			local autoExec = tree.Run
			tree.Parent, tree.Name, tree.Run = nil, nil, nil

			if classInfo.Initialize then
				classInfo.Initialize(obj, real, Root)
			end

			for ind, val in pairs(tree) do
				if ind == "Class" then continue end
				if ind == "Children" then
					for name, child in pairs(val) do
						if type(name) == "string" then
							child.Name = name
						end
						child.Parent = real

						child = self:Construct(child, nil, makingCustomObj)
						if makingCustomObj then
							child:SetAttribute("__IGNORE", self:getClassInfo(classOverride or tree.Class).ClassName)
						end
					end
				elseif self:IsWrappedSignal(obj[ind]) then
					eventsToConnect[ind] = val
				else
					obj[ind] = val
				end
			end
			for eventName, callback in pairs(eventsToConnect) do
				local conn; conn = self:getSignal(obj, eventName):Connect(function(...)
					return callback(obj, conn, ...)
				end)
			end
			if parent then
				obj.Parent = parent
			end

			if autoExec then
				task.defer(autoExec, obj, real)
			end
			
			if classInfo.PostInitialize then
				task.defer(classInfo.PostInitialize, obj, real)
			end

			return obj
		end,

		MountInterface = function(self, treeOrObject: {[string]:any}|Object, parent: Object?, doThemeRefresh: boolean?): (WrappedObject, string)
			local interface = if type(treeOrObject) == "table" then self:Construct(treeOrObject) else self:Wrap(treeOrObject)

			local name = interface.Name
			local id = nil
			repeat
				id = Utilities:RandomString(6)
			until not self._ActiveInterfaces[id]

			interface.Name = "AdonisUI_"..id

			self._ActiveInterfaces[id] = {
				InterfaceObject = interface,
				InterfaceName = name,
				InterfaceId = id,

				doThemeRefresh = if doThemeRefresh == false then false else true
			}
			interface.AncestryChanged:Connect(function(_, newParent)
				if not newParent then
					self._ActiveInterfaces[id] = nil
				end
			end)

			interface.Parent = parent or self:GetPlayerGui()
			return interface, id
		end,

		GetInterfaceById = function(self, interfaceId: string, presentObjects: boolean?): InterfaceData|WrappedObject?
			local data = self._ActiveInterfaces[interfaceId]

			if data then
				if data.InterfaceObject then
					return if presentObjects then data.InterfaceObject else data
				end
				self._ActiveInterfaces[interfaceId] = nil
			end

			return nil
		end,
		UnmountInterfaceById = function(self, interfaceId: string): boolean
			local interface = self:GetInterfaceById(interfaceId)

			if interface then
				interface.InterfaceObject:Destroy()
				self._ActiveInterfaces[interfaceId] = nil
				return true
			end

			return false
		end,

		GetInterfacesByClass = function(self, className: string, presentObjects: boolean?): {InterfaceData|WrappedObject}
			local interfaces = {}

			for id, data in pairs(self._ActiveInterfaces) do
				if data.InterfaceObject and data.InterfaceObject:IsA(className) then
					table.insert(interfaces, presentObjects and data.InterfaceObject or data)
				end
			end

			return interfaces
		end,
		UnmountInterfacesByClass = function(self, className: string): number
			local count = 0

			for id, data in pairs(self:GetInterfacesByClass(className)) do
				data.InterfaceObject:Destroy()
				self._ActiveInterfaces[id] = nil
				count += 1
			end

			return count
		end,

		FindFirstInterfaceByName = function(self, interfaceName: string, presentObject: boolean?): InterfaceData|WrappedObject?
			for id, data in pairs(self._ActiveInterfaces) do
				if data.InterfaceName == interfaceName then
					return if presentObject then data.InterfaceObject else data
				end
			end

			return nil
		end,
		GetInterfacesByName = function(self, interfaceName: string, presentObjects: boolean?): {InterfaceData|WrappedObject}
			local interfaces = {}

			for id, data in pairs(self._ActiveInterfaces) do
				if data.InterfaceName == interfaceName then
					table.insert(interfaces, presentObjects and data.InterfaceObject or data)
				end
			end

			return interfaces
		end,
		UnmountInterfacesByName = function(self, interfaceName: string): number
			local count = 0

			for id, data in pairs(self:GetInterfacesByName(interfaceName)) do
				data.InterfaceObject:Destroy()
				self._ActiveInterfaces[id] = nil
				count += 1
			end

			return count
		end,

		GetActiveInterfaces = function(self): {[string]:InterfaceData}
			return self._ActiveInterfaces
		end,

		ApplyTheme = function(self, themeName: string)
			if self.Themes[themeName] then
				for class, info in pairs(self.Themes[themeName]) do
					self.ClassInfoStore[class] = info
				end
				for id, data in pairs(self._ActiveInterfaces) do
					if data.doThemeRefresh then
						--// update existing interface elements???
					end
				end
				Root.DebugWarn("Applied theme: "..themeName)
			else
				Root.Warn("Theme", themeName, "does not exist")
			end
		end,

		RegisterTheme = function(self, themeName: string, classTable: {[string]:any})
			if self.Themes[themeName] then
				Root.Warn("Theme", themeName, "already exists, overwriting...")
			end
			self.Themes[themeName] = classTable
		end,

		GetPlayerGui = function(self)
			return Service.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		end,
}

type WrappedObject = {
	Class: string,
	ClassName: string,
	Parent: WrappedObject?,

	_data: {
		classInfo: ClassInfo,
		scriptSignals: {[string]:ScriptSignal},
		associatedEventsConnections: {[RBXScriptConnection]:ScriptSignal|RBXScriptSignal},
		instance: Instance,
		container: Instance,
		destroyed: boolean
	},
	_objectRef: Instance,
	_containerRef: Instance,

	_AdonisUI: typeof(UI),

	[string]: any
}
type ClassMemberInfo = {
	Type: string?,
	Default: any?,
	Read: (Instance, WrappedObject)->(any)?,
	Update: (WrappedObject, any, Instance)->(any)?,
	Path: (Instance, WrappedObject)->(Instance)?,
}
type ClassInfo = {
	ClassName: string,
	Members: {[string]:ClassMemberInfo},
	Events: {string},
	Structure: {[string]:any}?,
	Prefabricated: Instance?,
	ContainerPath: (Instance, WrappedObject)->(Instance),
	Initialize: (WrappedObject, Instance, typeof(Root))->()?,
	PostInitialize: (WrappedObject, Instance)->()?
}
type ScriptSignal = {
	bindable: BindableEvent,
	activeConnnections: {RBXScriptConnection},

	Connect: (ScriptSignal, (any)->())->(RBXScriptConnection),
	ConnectOnce: (ScriptSignal, (any)->())->(RBXScriptConnection),
	ConnectParallel: (ScriptSignal, (any)->())->(RBXScriptConnection),
	Destroy: (ScriptSignal)->(),
	DisconnectAll: (ScriptSignal)->(),
	Fire: (any)->(),
	Wait: (ScriptSignal)->(any)
}
type InterfaceData = {
	InterfaceObject: WrappedObject,
	InterfaceName: string,
	InterfaceId: string,

	doThemeRefresh: boolean
}
type Object = WrappedObject|Instance
type Class = ClassInfo|string

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Utilities = Root.Utilities
		Package = cPackage
		Service = Root.Utilities.Services

		--// Do init
		Root.UI = UI
		Utilities:MergeTables(Root.Remote.Commands, RemoteCommands)
	end;

	AfterInit = function(Root, Package)
		--// Do after-init

		UI:ApplyTheme("UI.Default")

		local testWindow = UI:MountInterface({
			Class = "Window",
			Children = {
				{
					Class = "Checkbox",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Text = "",
					DynamicSize = true, --// custom property of custom class Checkbox (resizes according to text)

					-- Events --
					--// NOTE: these are essentially the same as doing:
					--// testWindow.Checkbox.Checked/Unchecked/Toggled:Connect
					--// OR testWindow.Checkbox:GetPropertyChangedSignal("IsChecked"):Connect
					Checked = function(self) --// self is the checkbox
						Root.Warn("Checked.", self)
					end,
					Unchecked = function(self)
						Root.Warn("Unchecked.", self)
					end,
					Toggled = function(self, conn, isChecked)
						self.Text = if isChecked then "HELLO!" else ""
					end,
					--// Alternatively ("PropertyChanged"):
					--[[IsCheckedChanged = function(self, conn, isChecked)
						
					end,]]
				},
				{
					Class = "TextLabel",
					Text = "what", 
					Size = UDim2.fromOffset(100, 30)
				}
			}
		})

		testWindow.Minimized:ConnectOnce(function() --// yes
			Root.Warn("First minimize")
		end)

		testWindow.Closing:Connect(function()
			Root.Warn("Bye!")
		end)
	end;
}
