local _, ns = ...

function ns.InitializeDatabase()
    PyresinQoLDB = PyresinQoLDB or {}
    local threat = PyresinQoLDB.targetThreat
    if threat == false then
        PyresinQoLDB.targetThreat = "off"
    elseif threat ~= "off" and threat ~= "auto" and threat ~= "combat" and threat ~= "always" then
        PyresinQoLDB.targetThreat = "auto"
    end
    if PyresinQoLDB.showPerformance ~= nil then
        if PyresinQoLDB.showFPS == nil then PyresinQoLDB.showFPS = PyresinQoLDB.showPerformance end
        if PyresinQoLDB.showLatency == nil then PyresinQoLDB.showLatency = PyresinQoLDB.showPerformance end
        PyresinQoLDB.showPerformance = nil
    end
end
