--!A cross-platform build utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2018, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        checker.lua
--

-- imports
import("core.base.option")
import("detect.sdks.find_xcode")
import("detect.sdks.find_xcode_sdkvers")
import("detect.sdks.find_cuda")
import("lib.detect.find_tool")

-- find the given tool
function _toolchain_check(config, toolkind, toolinfo)

    -- get the program 
    local program = config.get(toolkind)
    if not program then

        -- get name and attempt to get `$(env XX)`
        local name = vformat(toolinfo.name)
        if #name == 0 then
            return 
        end

        -- get cross
        local cross = toolinfo.cross or ""

        -- attempt to check it 
        if not program then
            local tool = find_tool(name, {program = cross .. name, pathes = config.get("toolchains"), check = toolinfo.check})
            if tool then
                program = tool.program
            end
        end

        -- check ok?
        if program then 
            config.set(toolkind, program) 
        end

        -- trace
        if option.get("verbose") then
            if program then
                cprint("checking for %s (%s) ... ${green}%s", toolinfo.description, toolkind, path.filename(program))
            else
                cprint("checking for %s (%s: ${red}%s${clear}) ... ${red}no", toolinfo.description, toolkind, name)
            end
        end
    end

    -- ok?
    return program
end

-- check all for the given config kind
function check(kind, checkers)

    -- init config name
    local confignames = {config = "core.project.config", global = "core.base.global"}

    -- import config module
    local config = import(confignames[kind])

    -- check all
    for _, checker in ipairs(checkers[kind]) do

        -- has arguments?
        local args = {}
        if type(checker) == "table" then
            for idx, arg in ipairs(checker) do
                if idx == 1 then
                    checker = arg
                else
                    table.insert(args, arg)
                end
            end
        end

        -- check it
        checker(config, unpack(args))
    end
end

-- check the architecture
function check_arch(config, default)

    -- get the architecture
    local arch = config.get("arch")
    if not arch then

        -- init the default architecture
        config.set("arch", default or os.arch())

        -- trace
        cprint("checking for the architecture ... ${green}%s", config.get("arch"))
    end
end

-- check the xcode application directory
function check_xcode(config, optional)

    -- get the xcode directory
    local xcode_dir = config.get("xcode")
    if not xcode_dir then

        -- check ok? update it
        xcode_dir = find_xcode()
        if xcode_dir then

            -- save it
            config.set("xcode", xcode_dir)

            -- trace
            cprint("checking for the Xcode application directory ... ${green}%s", xcode_dir)

        elseif not optional then

            -- failed
            cprint("checking for the Xcode application directory ... ${red}no")
            cprint("${bright red}please run:")
            cprint("${red}    - xmake config --xcode_dir=xxx")
            cprint("${red}or  - xmake global --xcode_dir=xxx")
            raise()
        end
    end
end

-- check the xcode sdk version
function check_xcode_sdkver(config, optional)

    -- get the xcode sdk version
    local xcode_sdkver = config.get("xcode_sdkver")
    if not xcode_sdkver then

        -- check ok? update it
        xcode_sdkver = find_xcode_sdkvers({xcode_dir = config.get("xcode"), plat = config.get("plat"), arch = config.get("arch")})[1]
        if xcode_sdkver then
            
            -- save it
            config.set("xcode_sdkver", xcode_sdkver)

            -- trace
            cprint("checking for the Xcode SDK version for %s ... ${green}%s", config.get("plat"), xcode_sdkver)

        elseif not optional then

            -- failed
            cprint("checking for the Xcode SDK version for %s ... ${red}no", config.get("plat"))
            cprint("${bright red}please run:")
            cprint("${red}    - xmake config --xcode_sdkver=xxx")
            cprint("${red}or  - xmake global --xcode_sdkver=xxx")
            raise()
        end
    end

    -- get target minver
    local target_minver = config.get("target_minver")
    if not target_minver then
        config.set("target_minver", xcode_sdkver)
    end
end

-- check the cuda sdk toolchains
function check_cuda(config)

    -- get the cuda directory
    local cuda_dir = config.get("cuda")
    if not cuda_dir then

        -- check ok? update it
        local toolchains = find_cuda()
        if toolchains then

            -- save it
            config.set("cuda", toolchains.cudadir)

            -- trace
            cprint("checking for the Cuda SDK directory ... ${green}%s", toolchains.cudadir)
        end
    end
end

-- insert toolchain
function toolchain_insert(toolchains, toolkind, cross, name, description, check)

    -- insert to the given toolchain
    toolchains[toolkind] = toolchains[toolkind] or {}
    table.insert(toolchains[toolkind], {cross = cross, name = name, description = description, check = check})
end

-- check the toolchain 
function toolchain_check(config_or_kind, toolkind, toolchains)

    -- init config name
    local confignames = {config = "core.project.config", global = "core.base.global"}

    -- import config module
    local config = config_or_kind
    if type(config_or_kind) == "string" then
        config = import(confignames[config_or_kind])
    end

    -- load toolchains if be function
    if type(toolchains) == "function" then
        toolchains = toolchains(config)
    end

    -- check this toolchain
    for _, toolinfo in ipairs(toolchains[toolkind]) do
        if _toolchain_check(config, toolkind, toolinfo) then
            break
        end
    end

    -- save config
    config.save()
end

