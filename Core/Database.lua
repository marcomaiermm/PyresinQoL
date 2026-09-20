local _, ns = ...

function ns.InitializeDatabase()
    PyresinQoLDB = PyresinQoLDB or {}
    if PyresinQoLDB.showPerformance ~= nil then
        if PyresinQoLDB.showFPS == nil then PyresinQoLDB.showFPS = PyresinQoLDB.showPerformance end
        if PyresinQoLDB.showLatency == nil then PyresinQoLDB.showLatency = PyresinQoLDB.showPerformance end
        PyresinQoLDB.showPerformance = nil
    end
end
