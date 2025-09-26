local LrApplication     = import 'LrApplication'
local LrDialogs         = import 'LrDialogs'
local LrTasks           = import 'LrTasks'
local LrView            = import 'LrView'
local LrBinding         = import 'LrBinding'
local LrFunctionContext = import 'LrFunctionContext'

-- load preferences
local function loadPrefs()
    local f = io.open(_PLUGIN.path .. "/prefs.lua", "r")
    if f then
        local chunk = f:read("*a")
        f:close()
        local ok, prefs = pcall(loadstring("return " .. chunk))
        if ok and type(prefs) == "table" then
            return prefs
        end
    end
    return { mode = "time+distance", timeTolerance = 60, distanceTolerance = 50 }
end

-- save preferences
local function savePrefs(prefs)
    local f = io.open(_PLUGIN.path .. "/prefs.lua", "w")
    if f then
        f:write("return {\n")
        f:write(string.format("    mode = %q,\n", prefs.mode))
        f:write(string.format("    timeTolerance = %d,\n", prefs.timeTolerance))
        f:write(string.format("    distanceTolerance = %d,\n", prefs.distanceTolerance))
        f:write("}\n")
        f:close()
    end
end

-- Haversine formula (meters)
local function haversine(lat1, lon1, lat2, lon2)
    local R = 6371000
    local rad = math.rad
    local dLat = rad(lat2 - lat1)
    local dLon = rad(lon2 - lon1)
    local a = math.sin(dLat/2)^2 +
              math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLon/2)^2
    local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c
end

LrTasks.startAsyncTask(function()
    local catalog = LrApplication.activeCatalog()
    local photos = catalog:getTargetPhotos()

    if #photos == 0 then
        LrDialogs.message("No photos selected", "Please select some photos to process.")
        return
    end

    local prefs = loadPrefs()

    -- settings dialog
    local f = LrView.osFactory()
    local bind
    LrFunctionContext.callWithContext("GPSPropagatorSettings", function(context)
        bind = LrBinding.makePropertyTable(context)
        bind.mode = prefs.mode
        bind.timeTolerance = tostring(prefs.timeTolerance)
        bind.distanceTolerance = tostring(prefs.distanceTolerance)
    end)

    local settingsUI = f:column {
        spacing = f:control_spacing(),
        f:row {
            f:static_text { title = "Mode:" },
            f:popup_menu {
                items = { "time-only", "time+distance" },
                value = LrView.bind("mode"),
                width = 200,
            },
        },
        f:row {
            f:static_text { title = "Time tolerance (seconds):" },
            f:edit_field { value = LrView.bind("timeTolerance"), width_in_digits = 6 },
        },
        f:row {
            f:static_text { title = "Distance tolerance (yards):" },
            f:edit_field { value = LrView.bind("distanceTolerance"), width_in_digits = 6 },
        },
    }

    local result = LrDialogs.presentModalDialog {
        title = "GPS Propagation Settings",
        contents = settingsUI,
        actionVerb = "OK",
    }
    if result ~= "ok" then return end

    prefs.mode = bind.mode
    prefs.timeTolerance = tonumber(bind.timeTolerance) or 60
    prefs.distanceTolerance = tonumber(bind.distanceTolerance) or 50
    savePrefs(prefs)

    local TIME_TOLERANCE = prefs.timeTolerance
    local DISTANCE_TOLERANCE = prefs.distanceTolerance * 0.9144 -- yards → meters

    -- build photo sequence
    local sequence = {}
    for _, photo in ipairs(photos) do
        local captureTime = photo:getRawMetadata('dateTimeOriginal')
        if captureTime then
            table.insert(sequence, {
                photo = photo,
                time  = captureTime,
                gps   = photo:getRawMetadata('gps'),
            })
        end
    end
    table.sort(sequence, function(a,b) return a.time < b.time end)

    -- dry run: preview updates
    local previewUpdates = {}
    local lastTagged = nil
    local i = 1
    while i <= #sequence do
        local item = sequence[i]
        if item.gps then
            lastTagged = item
            i = i + 1
        else
            if lastTagged then
                if math.abs(item.time - lastTagged.time) <= TIME_TOLERANCE then
                    table.insert(previewUpdates, {photo=item.photo, gps=lastTagged.gps, donor=lastTagged.photo})
                    i = i + 1
                elseif prefs.mode == "time+distance" then
                    local j = i + 1
                    while j <= #sequence and not sequence[j].gps do
                        j = j + 1
                    end
                    if j <= #sequence then
                        local nextTagged = sequence[j]
                        local dist = haversine(
                            lastTagged.gps.latitude, lastTagged.gps.longitude,
                            nextTagged.gps.latitude, nextTagged.gps.longitude
                        )
                        if dist <= DISTANCE_TOLERANCE then
                            for k = i, j-1 do
                                table.insert(previewUpdates, {
                                    photo = sequence[k].photo,
                                    gps = lastTagged.gps,
                                    donor = lastTagged.photo,
                                })
                            end
                            i = j
                        else
                            i = j
                        end
                    else
                        break
                    end
                else
                    i = i + 1
                end
            else
                i = i + 1
            end
        end
    end

    if #previewUpdates == 0 then
        LrDialogs.message("No photos to update", "No untagged photos matched your criteria.")
        return
    end

    -- build preview UI with checkboxes
    local previewUI
    local previewBind
    LrFunctionContext.callWithContext("GPSPreview", function(context)
        local f = LrView.osFactory()
        previewBind = LrBinding.makePropertyTable(context)
        local rows = {}

        for idx, u in ipairs(previewUpdates) do
            previewBind["row" .. idx] = true -- default checked

            local targetName = u.photo:getFormattedMetadata("fileName")
            local donorName  = u.donor:getFormattedMetadata("fileName")
            local lat = string.format("%.6f", u.gps.latitude or 0)
            local lon = string.format("%.6f", u.gps.longitude or 0)

            table.insert(rows,
                f:row {
                    spacing = f:control_spacing(),

                    -- Checkbox
                    f:checkbox {
                        title = "",
                        value = LrView.bind("row" .. idx),
                    },

                    -- Donor (GPS source, left)
                    f:column {
                        f:catalog_photo {
                            photo = u.donor,
                            width = 128,
                            height = 128,
                        },
                        f:static_text { title = "Donor: " .. donorName },
                        f:static_text { title = "GPS: (" .. lat .. ", " .. lon .. ")" },
                    },

                    -- Arrow
                    f:static_text {
                        title = "⮕",
                        width = 40,
                        alignment = 'center',
                    },

                    -- Target (to be updated, right)
                    f:column {
                        f:catalog_photo {
                            photo = u.photo,
                            width = 128,
                            height = 128,
                        },
                        f:static_text { title = "Target: " .. targetName },
                    },
                }
            )
        end

        previewUI = f:scrolled_view {
            width = 780,
            height = 500,
            f:column(rows),
        }
    end)

    local confirm = LrDialogs.presentModalDialog {
        title = "Preview GPS Updates",
        contents = previewUI,
        actionVerb = "Apply",
    }
    if confirm ~= "ok" then return end

    -- apply updates (only checked ones)
    local updated = 0
    catalog:withWriteAccessDo("Propagate GPS", function()
        for idx, u in ipairs(previewUpdates) do
            if previewBind["row" .. idx] then
                u.photo:setRawMetadata('gps', u.gps)
                updated = updated + 1
            end
        end
    end)

    LrDialogs.message("GPS Propagation Complete", string.format("%d photos updated.", updated))
end)
