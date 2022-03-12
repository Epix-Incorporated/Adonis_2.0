--[[

	Description: Task utilities
	Author: Sceleratis
	Date: 12/04/2021

--]]

local Root, Utilities

local ActiveTasks = {}
local TaskSchedulers = {}
local ObjectMethods = { Task = {}; TaskScheduler = {}; }
local Tasks = { ActiveTasks = ActiveTasks }

--// Class definitions

--- Task object
--- @class Task
--- @server
--- @client
--- @tag Utilities


--- Responsible for Task scheduling functionality.
--- @class TaskScheduler
--- @server
--- @client
--- @tag Utilities


--- Whether or not this TaskScheduler should be added to the TaskSchedulers table for future use.
--- @prop Temporary boolean
--- @within TaskScheduler


--- TaskScheduler name.
--- @prop name string
--- @within TaskScheduler


--- Indicates whether this TaskScheduler is currently running/allowed to run.
--- @prop Running boolean
--- @within TaskScheduler


--- TaskSchedulerProperties
--- @prop Properties TaskSchedulerProperties
--- @within TaskScheduler


--- Tasks associated with this TaskScheduler.
--- @prop LinkedTasks table
--- @within TaskScheduler


--- Underlying BindableEvent used by TaskScheduler.
--- @prop RunnerEvent BindableEvent
--- @within TaskScheduler


--- TaskScheduler Properties
--- @interface TaskSchedulerProperties
--- @within Utilities.Tasks
--- @field Interval integer -- Task run interval


--- Task related utility methods.
--- @class Utilities.Tasks
--- @server
--- @client
--- @tag Utilities
--- @tag Package: System.Utilities



--// Object methods
--//// TaskScheduler object methods

--- Fires TaskScheduler event
--- @method Trigger
--- @within TaskScheduler
--- @param ... any
function ObjectMethods.TaskScheduler.Trigger(self, ...)
	self.Event:Fire(...)
end


--- Deletes associated TaskScheduler
--- @method Delete
--- @within TaskScheduler
function ObjectMethods.TaskScheduler.Delete(self)
	if not self.Properties.Temporary then
		TaskSchedulers[self.Name] = nil
	end

	if self.Thread then
		self:Close()
	end

	self.Running = false
	self.Event:Disconnect()
end



--//// Task object methods
--- Runs the task function
--- @method RunTaskFunction
--- @within Task
--- @param ... any
--- @return ... -- Task function result
function ObjectMethods.Task.RunTaskFunction(self, ...)
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
end


--- Resumes suspended task
--- @method Resume
--- @within Task
function ObjectMethods.Task.Resume(self)
	if self.Thread then
		Utilities.Events.TaskResumed:Fire(self)
		return coroutine.resume(self.Thread)
	else
		Utilities.Warn("Cannot resume non-thread task:", self.Index, self)
	end
end


--- Yields running task
--- @method Yield
--- @within Task
function ObjectMethods.Task.Yield(self)
	if self.Thread then
		coroutine.yield(self.Thread)
		Utilities.Events.TaskYielded:Fire(self)
	else
		Utilities.Warn("Cannot yield non-thread task:", self.Index, self)
	end
end


--- Stops running task
--- @method Stop
--- @within Task
function ObjectMethods.Task.Stop(self)
	if self.Thread then
		coroutine.close(self.Thread)
		Utilities.Events.TaskStopped:Fire(self)
	else
		Utilities.Warn("Cannot stop non-thread task:", self.Index, self)
	end
end



--//// Task utility methods

--- Responsible for the creation of new Tasks.
--- @method NewTask
--- @within Utilities.Tasks
--- @param name string -- Task name
--- @param func function -- Task function
--- @param ... any -- Task arguments
--- @return result
function Tasks.NewTask(self, name: string, func, ...)
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
end


--- Returns function which creates a new task on each call and passes arguments in. For use with events.
--- @method EventTask
--- @within Utilities.Tasks
--- @param name string -- Task name
--- @param func function -- Task function
function Tasks.EventTask(self, name: string, func)
	local newTask = self.NewTask
	return function(...)
		return newTask(self, name, func, ...)
	end
end


--- Returns ActiveTasks table.
--- @method GetActiveTasks
--- @within Utilities.Tasks
--- @return ActiveTasks
function Tasks.GetActiveTasks(self)
	return ActiveTasks
end


--- Creates a new TaskScheduler
--- @method TaskScheduler
--- @within Utilities.Tasks
--- @param taskName string -- Task name
--- @param props TaskSchedulerProperties -- Task properties
function Tasks.TaskScheduler(self, taskName: string, props)
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
end


--//// Return initializer
return table.freeze {
	Init = function(cRoot, cUtilities)
		Root = cRoot
		Utilities = cUtilities
		Utilities.Tasks = Tasks
	end;
}
