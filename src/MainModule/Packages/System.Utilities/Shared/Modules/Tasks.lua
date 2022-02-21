--[[

	Description: Task utilities
	Author: Sceleratis
	Date: 12/04/2021

--]]

local Root, Utilities

local ActiveTasks = {}
local TaskSchedulers = {}
local ObjectMethods = {
	--// TaskScheduler methods
	TaskScheduler = {
		Trigger = function(self, ...)
			self.Event:Fire(...)
		end;

		Delete = function(self)
			if not self.Properties.Temporary then
				TaskSchedulers[self.Name] = nil
			end

			if self.Thread then
				self:Close()
			end

			self.Running = false
			self.Event:Disconnect()
		end;
	};

	--// Task methods
	Task = {
		RunTaskFunction = function(self, ...)
			ActiveTasks[self.Index] = self

			Utilities.Events.TaskStarted:Fire(self, ...)

			self.Status = "Running"
			self.Running = true
			self.Returns = {pcall(self.Function, ...)}
			self.Running = false

			if not self.Returns[1] then
				self.Status = "Errored"
			else
				self.Status = "Finished"
			end

			Utilities.Events.TaskEnded:Fire(self, ...)

			ActiveTasks[self.Index] = nil
			return unpack(self.Returns)
		end;

		Resume = function(self)
			if self.Thread then
				Utilities.Events.TaskResumed:Fire(self)
				return coroutine.resume(self.Thread)
			else
				Utilities.Warn("Cannot resume non-thread task:", self.Index, self)
			end
		end;

		Yield = function(self)
			if self.Thread then
				coroutine.yield(self.Thread)
				Utilities.Events.TaskYielded:Fire(self)
			else
				Utilities.Warn("Cannot yield non-thread task:", self.Index, self)
			end
		end;

		Stop = function(self)
			if self.Thread then
				coroutine.close(self.Thread)
				Utilities.Events.TaskStopped:Fire(self)
			else
				Utilities.Warn("Cannot stop non-thread task:", self.Index, self)
			end
		end;
	}
}

--// Tasks
local Tasks = {
	ActiveTasks = ActiveTasks;

	NewTask = function(self, name, func, ...)
		local index = Utilities:RandomString()
		local isThread = string.sub(name, 1, 7) == "Thread:"
		local data = {
			Name = name;
			Status = "Waiting";
			Function = func;
			isThread = isThread;
			Created = os.time();
			Index = index;
		}

		Utilities:MergeTables(data, ObjectMethods.Task)
		Utilities.Events.TaskCreated:Fire(data)

		if isThread then
			data.Thread = coroutine.create(data.RunTaskFunction)
			return data, coroutine.resume(data.Thread, data, ...)
		else
			return data:RunTaskFunction(...)
		end
	end;

	EventTask = function(self, name, func)
		local newTask = self.NewTask
		return function(...)
			return newTask(self, name, func, ...)
		end
	end;

	GetActiveTasks = function()
		return ActiveTasks
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
		}

		Utilities:MergeTables(new, ObjectMethods.TaskScheduler)

		new.Event = new.RunnerEvent.Event:Connect(function(...)
			for i, v in pairs(new.LinkedTasks) do
				if select(2, pcall(v)) then
					table.remove(new.LinkedTasks, i);
				end
			end
		end)

		if props.Interval then
			while task.wait(props.Interval) and new.Running do
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
