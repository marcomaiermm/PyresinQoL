local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("editMode", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local editor = context.pages.main

    local pixelPerfect = Register(editor, "PixelPerfectEditMode", "pixelPerfectEditMode", Settings.VarType.Boolean,
        L.pixelPerfect, false, module.UpdatePixelPerfectMode)
    AddControl(editor, Settings.CreateCheckboxInitializer(pixelPerfect, nil, L.pixelPerfectHelp))
end)
