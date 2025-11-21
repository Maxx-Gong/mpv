-- visualizer.lua (bars version)
-- MPV audio visualizer with bar-style spectrum

local opts = {
    mode = "noalbumart",  -- off | noalbumart | novideo | force
    name = "bars",         -- bars | off
    quality = "high",  -- high | veryhigh
    height = 8,            -- [4 .. 12]
    forcewindow = true,    -- true | false
}

if not (mp.get_property("options/lavfi-complex", "") == "") then
    return
end

local options = require 'mp.options'
local msg     = require 'mp.msg'

local function get_visualizer(name, quality)
    local w, h, fps

    if quality == "high" then
        w = 1920
        fps = 60
    elseif quality == "veryhigh" then
        w = 2560
        fps = 60
    else
        msg.log("error", "invalid quality")
        return ""
    end

    h = w * opts.height / 12

    if name == "bars" then
        -- simple bar-style visualizer
        return "[aid1] asplit [ao]," ..
               "aformat=channel_layouts=stereo," ..
               "showfreqs=" ..
                   "size=" .. w .. "x" .. h .. ":" ..
                   "mode=bar:" ..
                   "ascale=sqrt:" ..
                   "fscale=lin:" ..
                   "win_size=128:" ..
                --    "bar_w=8:" ..
                    -- "bar_g=4:" ..
                   "colors=0x00FFAA|0x66CCFF," ..
                --    "bar_h=18:" ..
                --    "axis=0," ..
               "format=yuv420p [vo]"
    elseif name == "off" then
        local hasvideo = false
        for _, track in ipairs(mp.get_property_native("track-list")) do
            if track.type == "video" then
                hasvideo = true
                break
            end
        end
        if hasvideo then
            return "[aid1] asetpts=PTS [ao]; [vid1] setpts=PTS [vo]"
        else
            return "[aid1] asetpts=PTS [ao];" ..
                "color=c=black:s=" .. w .. "x" .. h .. "," ..
                "format=yuv420p [vo]"
        end
    end

    msg.log("error", "invalid visualizer name")
    return ""
end

local function select_visualizer(vtrack, atrack)
    if atrack == nil or opts.mode == "off" then
        return ""
    elseif opts.mode == "force" then
        return get_visualizer(opts.name, opts.quality)
    elseif opts.mode == "noalbumart" then
        if vtrack == nil then
            mp.commandv("set", "osd-level", "3")
            return get_visualizer(opts.name, opts.quality)
        end
        return ""
    elseif opts.mode == "novideo" then
        if vtrack == nil or vtrack.albumart then
            return get_visualizer(opts.name, opts.quality)
        end
        return ""
    end
    msg.log("error", "invalid mode")
    return ""
end

local function visualizer_hook()
    local atrack = mp.get_property_native("current-tracks/audio")
    local vtrack = mp.get_property_native("current-tracks/video")
    if not atrack and not vtrack then
        for _, track in ipairs(mp.get_property_native("track-list")) do
            if track.type == "audio" then atrack = track end
            if track.type == "video" and mp.get_property("vid") ~= "no" then vtrack = track end
        end
    end
    local lavfi = select_visualizer(vtrack, atrack)
    if lavfi ~= "" and lavfi ~= mp.get_property("lavfi-complex", "") then
        mp.set_property("file-local-options/lavfi-complex", lavfi)
    end
end

options.read_options(opts, nil, visualizer_hook)
opts.height = math.min(12, math.max(4, opts.height))
opts.height = math.floor(opts.height)

if not opts.forcewindow and mp.get_property('force-window') == "no" then
    return
end

mp.add_hook("on_preloaded", 50, visualizer_hook)
mp.observe_property("current-tracks/audio", "native", visualizer_hook)
mp.observe_property("current-tracks/video", "native", visualizer_hook)
