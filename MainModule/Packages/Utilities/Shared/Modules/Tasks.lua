--[[

	Description: Task utilities
	Author: Sceleratis
	Date: 12/04/2021

--]]

local Root, Utilities

local TrackedTasks = {}
local TaskSchedulers = {}
local ObjectMethods = {
	--// Task methods
	Task = {
		Trigger = function(self, ...)
			self.Event:Fire(...)
		end;

		Delete = function(self)
			if not self.Properties.Temporary then
				TaskSchedulers[self.Name] = nil
			end

			self.Running = false
			self.Event:Disconnect()
		end;
	}
}

--// Tasks
local Tasks = table.freeze{
	TrackTask = function(self, name, func, ...)
		local index = RandomString()
		local isThread = string.sub(name, 1, 7) == "Thread:"

		local data = {
			Name = name;
			Status = "Waiting";
			Function = func;
			isThread = isThread;
			Created = os.time();
			Index = index;
		}

		local function taskFunc(...)
			TrackedTasks[index] = data
			data.Status = "Running"
			data.Returns = {pcall(func, ...)}

			if not data.Returns[1] then
				data.Status = "Errored"
			else
				data.Status = "Finished"
			end

			TrackedTasks[index] = nil
			return unpack(data.Returns)
		end

		if isThread then
			data.Thread = coroutine.create(taskFunc)
			return coroutine.resume(data.Thread, ...) --select(2, coroutine.resume(data.Thread, ...))
		else
			return taskFunc(...)
		end
	end;

	EventTask = function(self, name, func)
		local newTask = self.TrackTask
		return function(...)
			return newTask(name, func, ...)
		end
	end;

	GetTasks = function()
		return TrackedTasks
	end;

	TaskScheduler = function(self, taskName, props)
		local props = props or {}
		if not props.Temporary and TaskSchedulers[taskName] then return TaskSchedulers[taskName] end

		local new = {
			Name = taskName;
			Running = true;
			Properties = props;
			LinkedTasks = {};
			RunnerEvent = Instance.new("BindableEvent");
			Trigger = ObjectMethods.Task.Trigger;
			Delete = ObjectMethods.Task.Delete;
		}

		new.Event = new.RunnerEvent.Event:Connect(function(...)
			for i, v in pairs(new.LinkedTasks) do
				if select(2, pcall(v)) then
					table.remove(new.LinkedTasks, i);
				end
			end
		end)

		if props.Interval then
			while wait(props.Interval) and new.Running do
				new:Trigger(os.time())
			end
		end

		if not props.Temporary then
			TaskSchedulers[taskName] = new
		end

		return new
	end;
}

return table.freeze {
	Init = function(cRoot, cUtilities)
		Root = cRoot
		Utilities = cUtilities
		Utilities.Tasks = Tasks
	end;
}
