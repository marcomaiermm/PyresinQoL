-- Expected failures run only in the runner's dedicated rejection process.
local UI = PyresinQoLUITest
local previousHandler = geterrorhandler()
for _, kind in ipairs({ "timer", "update", "cleanup", "cleanup-timer" }) do
    local restored, callbackFrame = false, nil
    local sentinel = "ui-harness-" .. kind .. "-sentinel"
    UI.Flow("intentional " .. kind .. " failure", {
        function()
            if kind == "timer" then
                C_Timer.After(0, function() error(sentinel) end)
            elseif kind == "update" then
                callbackFrame = CreateFrame("Frame")
                callbackFrame:SetScript("OnUpdate", function(self)
                    self:SetScript("OnUpdate", nil)
                    error(sentinel)
                end)
            end
        end,
    }, function()
        restored = true
        if callbackFrame then callbackFrame:SetScript("OnUpdate", nil); callbackFrame:Hide() end
        if kind == "cleanup" then error(sentinel) end
        if kind == "cleanup-timer" then C_Timer.After(0, function() error(sentinel) end) end
    end)
    async_test("restores handler after " .. kind, function(done)
        done(function()
            assert(restored, "Cleanup was skipped")
            assertEquals(previousHandler, geterrorhandler())
            assertFalse(PyresinQoLSettingsFrame:IsShown())
        end)
    end)
    UI.Flow("usable after " .. kind, {
        function(canvas, sidebar, list)
            assertTrue(canvas:IsVisible())
            UI.PageButton(sidebar, "FPS & Latency"):Click()
            assertEquals("FPS & Latency", list.Header.Title:GetText())
        end,
    })
end
async_test("all recovery flows completed", function(done)
    done(function()
        assertEquals(previousHandler, geterrorhandler())
        assertFalse(PyresinQoLSettingsFrame:IsShown())
        print("ui-harness-recovery-complete")
    end)
end)
