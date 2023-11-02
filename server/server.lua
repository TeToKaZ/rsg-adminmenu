local RSGCore = exports['rsg-core']:GetCoreObject()
local savedCoords = {}
-----------------------------------------------------------------------
-- version checker
-----------------------------------------------------------------------
local function versionCheckPrint(_type, log)
    local color = _type == 'success' and '^2' or '^1'

    print(('^5['..GetCurrentResourceName()..']%s %s^7'):format(color, log))
end

local function CheckVersion()
    PerformHttpRequest('https://raw.githubusercontent.com/Rexshack-RedM/rsg-adminmenu/main/version.txt', function(err, text, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

        if not text then 
            versionCheckPrint('error', 'Currently unable to run a version check.')
            return 
        end

        --versionCheckPrint('success', ('Current Version: %s'):format(currentVersion))
        --versionCheckPrint('success', ('Latest Version: %s'):format(text))
        
        if text == currentVersion then
            versionCheckPrint('success', 'You are running the latest version.')
        else
            versionCheckPrint('error', ('You are currently running an outdated version, please update to version %s'):format(text))
        end
    end)
end

-----------------------------------------------------------------------

local permissions = {
    ["revive"] = "admin",
    ["inventory"] = "admin",
    ["kick"] = "admin",
    ["ban"] = "admin",
    ["goto"] = "admin",
    ["bring"] = "admin",
    ["freeze"] = "admin",
    ["spectate"] = "admin",
    ["wildattack"] = "admin",
    ["setonfire"] = "admin",
    ["giveitem"] = "admin",
    ["playerinfo"] = "admin",
}

RSGCore.Commands.Add('admin', Lang:t('lang_100'), {}, false, function(source)
    local src = source
    TriggerClientEvent('rsg-adminmenu:client:openadminmenu', src)
end, 'admin')

-- get players
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayers', function(source, cb)
    local src = source
    local players = {}
    for k,v in pairs(RSGCore.Functions.GetPlayers()) do
        local target = GetPlayerPed(v)
        local ped = RSGCore.Functions.GetPlayer(v)
        players[#players + 1] = {
        name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname .. ' | (' .. GetPlayerName(v) .. ')',
        id = v,
        coords = GetEntityCoords(target),
        citizenid = ped.PlayerData.citizenid,
        sources = GetPlayerPed(ped.PlayerData.source),
        sourceplayer = ped.PlayerData.source
        }
    end

    table.sort(players, function(a, b)
        return a.id < b.id
    end)

    cb(players)
end)

RSGCore.Commands.Add('bring', 'Bring a player to you (Admin only)', { { name = 'id', help = 'Player ID' }, }, true, function(source, args)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['bring']) or IsPlayerAceAllowed(src, 'command')  then
        if args[1] then
            local admin = GetPlayerPed(src)
            local coords = GetEntityCoords(admin)
            local target = GetPlayerPed(tonumber(args[1]))
            SetEntityCoords(target, coords)
            savedCoords[tonumber(args[1])]= GetEntityCoords(target)
        end
    else
        BanPlayer(src)
    end
end, 'mod')

RSGCore.Commands.Add('bringback', 'Bring back a player (Admin only)', { { name = 'id', help = 'Player ID' }, }, true, function(source, args)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['bring']) or IsPlayerAceAllowed(src, 'command')  then
        if args[1] then
            local coords = savedCoords[tonumber(args[1])]
            local target = GetPlayerPed(tonumber(args[1]))
            SetEntityCoords(target, coords)
        end
    else
        BanPlayer(src)
    end
end, 'mod')

RSGCore.Commands.Add('goto', 'Teleport yourself to the player (Admin only)', { { name = 'id/x', help = 'ID of player or X position' }, { name = 'y', help = 'Y position' }, { name = 'z', help = 'Z position' } }, false, function(source, args)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['goto']) or IsPlayerAceAllowed(src, 'command')  then
        if args[1] and not args[2] and not args[3] then
            local target = GetPlayerPed(tonumber(args[1]))
            if target ~= 0 then
                local coords = GetEntityCoords(target)
                TriggerClientEvent('RSGCore:Command:TeleportToPlayer', source, coords)
            end
        else
            if args[1] and args[2] and args[3] then
                local x = tonumber((args[1]:gsub(",",""))) + .0
                local y = tonumber((args[2]:gsub(",",""))) + .0
                local z = tonumber((args[3]:gsub(",",""))) + .0
                if x ~= 0 and y ~= 0 and z ~= 0 then
                    TriggerClientEvent('RSGCore:Command:TeleportToCoords', source, x, y, z)
                end
            end
        end
    else
        BanPlayer(src)
    end
end, 'mod')

RSGCore.Commands.Add('spawnwildhorse', 'Spawn Wild Horse (Admin only)', {{ name = "model", help = " Horse Model" }, { name = 'Coat', help = '0 - 5' }}, false, function(source, args)
    if RSGCore.Functions.HasPermission(src, permissions['spawnhorse']) or IsPlayerAceAllowed(src, 'command')  then
        local horseModel = args[1] -- The model name for the horse
        local outfit = tonumber(args[2]) or 0 -- The outfit index for the horse (default: 0)
        local freezeTime = 20000 -- The time to freeze the horse in milliseconds (50 seconds)
        local timeout = 10000 -- Set a timeout of 10 seconds for model loading

        print('Requesting model: ' .. horseModel)
        RequestModel(horseModel)
        local startTime = GetGameTimer() -- Get the start time
        while not HasModelLoaded(horseModel) do
            Wait(10)
            print('Waiting for model to load...')
            if GetGameTimer() - startTime > timeout then
                print('Model loading timeout. Aborting...')
                return -- Exit the function
            end
        end
        print('Model loaded successfully')

        local player = PlayerId()
        local playerCoords = GetEntityCoords(PlayerPedId())
        local horse = CreatePed(horseModel, playerCoords.x, playerCoords.y + 5.0, playerCoords.z, true, true, true)

        if DoesEntityExist(horse) then
            print('Horse entity created')
            Citizen.InvokeNative(0x77FF8D35EEC6BBC4, horse, outfit, false)
            print('Outfit applied to the horse')
            
            -- Freeze the horse for the specified duration
            FreezeEntityPosition(horse, true)
            Wait(freezeTime)
            FreezeEntityPosition(horse, false)
            print('Horse unfrozen')

            -- Make the horse untamed and wild
            Citizen.InvokeNative(0xAEB97D84CDF3C00B, horse, true) -- _SET_ANIMAL_IS_WILD
        end
    else
        BanPlayer(src)
    end
end, 'mod')

-----------------------------------------------------------------------
-- revive player
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:playerrevive', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['revive']) or IsPlayerAceAllowed(src, 'command')  then
        TriggerClientEvent('rsg-medic:client:adminRevive', player.id)
    else
        --BanPlayer(src)
        TriggerClientEvent('ox_lib:notify', source, {title = Lang:t('lang_101'), description = Lang:t('lang_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- open players inventory
-----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:openinventory', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['inventory']) or IsPlayerAceAllowed(src, 'command') then
        TriggerClientEvent('rsg-adminmenu:client:openinventory', src, player.id)
    else
        --BanPlayer(src)
        TriggerClientEvent('ox_lib:notify', source, {title = Lang:t('lang_101'), description = Lang:t('lang_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- kick player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:kickplayer', function(player, reason)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['kick']) or IsPlayerAceAllowed(src, 'command')  then
        TriggerEvent('rsg-log:server:CreateLog', 'bans', 'Player Kicked', 'red', string.format('%s was kicked by %s for %s', GetPlayerName(player), GetPlayerName(src), reason), true)
        DropPlayer(player, Lang:t('lang_103') .. ':\n' .. reason .. '\n\n' .. Lang:t('lang_104') .. RSGCore.Config.Server.Discord)
    else
        --BanPlayer(src)
        TriggerClientEvent('ox_lib:notify', source, {title = Lang:t('lang_101'), description = Lang:t('lang_102'), type = 'inform' })
    end
end)

-----------------------------------------------------------------------
-- ban player
----------------------------------------------------------------------
local function BanPlayer(src)
    MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        GetPlayerName(src),
        RSGCore.Functions.GetIdentifier(src, 'license'),
        RSGCore.Functions.GetIdentifier(src, 'discord'),
        RSGCore.Functions.GetIdentifier(src, 'ip'),
        "system banned you",
        2524608000,
        'rsg-adminmenu'
    })
    TriggerEvent('rsg-log:server:CreateLog', 'adminmenu', 'Player Banned', 'red', string.format('%s was banned by %s for %s', GetPlayerName(src), 'rsg-adminmenu', "system banned you for inappropriate use"), true)
    DropPlayer(src, Lang:t('lang_105'))
end

RegisterNetEvent('rsg-adminmenu:server:banplayer', function(player, time, reason)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['ban']) or IsPlayerAceAllowed(src, 'command') then
        time = tonumber(time)
        local banTime = tonumber(os.time() + time)
        if banTime > 2524608000 then
            banTime = 2524608000
        end
        local timeTable = os.date('*t', banTime)
        MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            GetPlayerName(player),
            RSGCore.Functions.GetIdentifier(player, 'license'),
            RSGCore.Functions.GetIdentifier(player, 'discord'),
            RSGCore.Functions.GetIdentifier(player, 'ip'),
            reason,
            banTime,
            GetPlayerName(src)
        })
        TriggerClientEvent('chat:addMessage', -1, {
            template = "<div class=chat-message server'><strong>ANNOUNCEMENT | {0} has been banned:</strong> {1}</div>",
            args = {GetPlayerName(player), reason}
        })
        TriggerEvent('rsg-log:server:CreateLog', 'bans', 'Player Banned', 'red', string.format('%s was banned by %s for %s', GetPlayerName(player), GetPlayerName(src), reason), true)
        if banTime >= 2524608000 then
            DropPlayer(player, Lang:t('lang_106') .. '\n' .. reason .. '\n\n'..Lang:t('lang_107')..'\n'..Lang:t('lang_108') .. RSGCore.Config.Server.Discord)
        else
            DropPlayer(player, Lang:t('lang_106') .. '\n' .. reason .. '\n\n'..Lang:t('lang_109') .. timeTable['day'] .. '/' .. timeTable['month'] .. '/' .. timeTable['year'] .. ' ' .. timeTable['hour'] .. ':' .. timeTable['min'] .. '\n' ..('lang_110') .. RSGCore.Config.Server.Discord)
        end
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------
-- goto player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:gotoplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['goto']) or IsPlayerAceAllowed(src, 'command') then
        local admin = GetPlayerPed(src)
        local coords = GetEntityCoords(GetPlayerPed(player.id))
        SetEntityCoords(admin, coords)
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------
-- bring player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:bringplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['bring']) or IsPlayerAceAllowed(src, 'command') then
        local admin = GetPlayerPed(src)
        local coords = GetEntityCoords(admin)
        local target = GetPlayerPed(player.id)
        SetEntityCoords(target, coords)
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------
-- send back player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:sendback', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['sendback']) or IsPlayerAceAllowed(src, 'command') then
        local admin = GetPlayerPed(src)
        local coors = savedCoords[tonumber(player.id)]
        local target = GetPlayerPed(player.id)
        SetEntityCoords(target, coords)
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------
-- freeze player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:freezeplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['freeze']) or IsPlayerAceAllowed(src, 'command') then
        local target = GetPlayerPed(player.id)
        if not frozen then
            frozen = true
            Citizen.InvokeNative(0x7D9EFB7AD6B19754, target, true)
            TriggerClientEvent('ox_lib:notify', source, {title = Lang:t('lang_111'), description = Lang:t('lang_112')..player.name, type = 'inform' })
        else
            frozen = false
            Citizen.InvokeNative(0x7D9EFB7AD6B19754, target, false)
            TriggerClientEvent('ox_lib:notify', source, {title = Lang:t('lang_113'), description = Lang:t('lang_114')..player.name, type = 'inform' })
        end
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------
-- spectate player
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:spectateplayer', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['spectate']) or IsPlayerAceAllowed(src, 'command') then
        local targetped = GetPlayerPed(player.id)
        local coords = GetEntityCoords(targetped)
        TriggerClientEvent('rsg-adminmenu:client:spectateplayer', src, player.id, coords)
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------
-- wild attack
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:wildattack', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['wildattack']) or IsPlayerAceAllowed(src, 'command') then
        TriggerClientEvent('rsg-adminmenu:client:wildattack', src, player.id)
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------
-- set player on fire
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:playerfire', function(player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['setonfire']) or IsPlayerAceAllowed(src, 'command') then
        TriggerClientEvent('rsg-adminmenu:client:playerfire', src, player.id)
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------
-- give item
----------------------------------------------------------------------
RegisterNetEvent('rsg-adminmenu:server:giveitem', function(player, item, amount)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['giveitem']) or IsPlayerAceAllowed(src, 'command') then
        local id = player
        local Player = RSGCore.Functions.GetPlayer(id)
        local amount = amount
        Player.Functions.AddItem(item, amount)
        TriggerClientEvent('ox_lib:notify', source, {title = Lang:t('lang_135'), description = Lang:t('lang_136'), type = 'inform' })
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------
-- player info
----------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-adminmenu:server:getplayerinfo', function(source, cb, player)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['playerinfo']) or IsPlayerAceAllowed(src, 'command') then
        
        local id = player.id
        local Player     = RSGCore.Functions.GetPlayer(id)
        local firstname  = Player.PlayerData.charinfo.firstname
        local lastname   = Player.PlayerData.charinfo.lastname
        local job        = Player.PlayerData.job.label
        local grade      = Player.PlayerData.job.grade.level
        local cash       = Player.PlayerData.money["cash"]
        local bank       = Player.PlayerData.money["bank"]
        local bloodmoney = Player.PlayerData.money["bloodmoney"]
        local citizenid  = Player.PlayerData.citizenid
        local serverid   = id

        
        cb({
            firstname  = firstname,
            lastname   = lastname,
            job        = job, 
            grade      = grade,
            cash       = cash,
            bank       = bank,
            bloodmoney = bloodmoney,
            citizenid  = citizenid,
            serverid   = serverid,
        })
    else
        BanPlayer(src)
    end
end)

-----------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- start version check
--------------------------------------------------------------------------------------------------
CheckVersion()
