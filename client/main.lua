local config = require 'config.client'
if not config.enableClient then return end
local VEHICLES = exports.qbx_core:GetVehiclesByName()

---@enum ProgressColor
local ProgressColor = {
    GREEN = 'green.5',
    YELLOW = 'yellow.5',
    RED = 'red.5'
}

-- Variáveis globais para preview e radial menu
local previewVeh = nil
local garageZones = {}
local isNearGarage = false
local currentGarage = nil

---@param percent number
---@return string
local function getProgressColor(percent)
    if percent >= 75 then
        return ProgressColor.GREEN
    elseif percent > 25 then
        return ProgressColor.YELLOW
    else
        return ProgressColor.RED
    end
end

local VehicleCategory = {
    all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22},
    car = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 22},
    air = {15, 16},
    sea = {14},
}

---@param category VehicleType
---@param vehicle number
---@return boolean
local function isOfType(category, vehicle)
    local classSet = {}

    for _, class in pairs(VehicleCategory[category]) do
        classSet[class] = true
    end

    return classSet[GetVehicleClass(vehicle)] == true
end

---@param vehicle number
local function kickOutPeds(vehicle)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
        end
    end
end

-- Função para obter estado completo do veículo incluindo danos
local function getCompleteVehicleProperties(vehicle)
    local props = lib.getVehicleProperties(vehicle)
    
    -- Adicionar informações de danos das portas
    props.doorsBroken = {}
    for i = 0, 5 do
        if IsVehicleDoorDamaged(vehicle, i) then
            props.doorsBroken[i] = true
        end
    end
    
    -- Adicionar informações de vidros quebrados
    props.windowsBroken = {}
    for i = 0, 7 do
        if not IsVehicleWindowIntact(vehicle, i) then
            props.windowsBroken[i] = true
        end
    end
    
    -- Adicionar informações de pneus estourados
    props.tyresBurst = {}
    for i = 0, 7 do
        if IsVehicleTyreBurst(vehicle, i, false) then
            props.tyresBurst[i] = true
        end
    end
    
    return props
end

-- Função para aplicar estado completo do veículo incluindo danos
local function applyCompleteVehicleProperties(vehicle, props)
    -- Aplicar propriedades básicas primeiro
    lib.setVehicleProperties(vehicle, props)
    
    -- Aguardar um frame para garantir que as propriedades foram aplicadas
    Wait(100)
    
    -- Aplicar danos nas portas
    if props.doorsBroken then
        for doorIndex, isBroken in pairs(props.doorsBroken) do
            if isBroken then
                SetVehicleDoorBroken(vehicle, doorIndex, true)
            end
        end
    end
    
    -- Aplicar vidros quebrados
    if props.windowsBroken then
        for windowIndex, isBroken in pairs(props.windowsBroken) do
            if isBroken then
                SmashVehicleWindow(vehicle, windowIndex)
            end
        end
    end
    
    -- Aplicar pneus estourados
    if props.tyresBurst then
        for tyreIndex, isBurst in pairs(props.tyresBurst) do
            if isBurst then
                SetVehicleTyreBurst(vehicle, tyreIndex, true, 1000.0)
            end
        end
    end
end

local spawnLock = false

---@param vehicleId number
---@param garageName string
---@param accessPoint integer
local function takeOutOfGarage(vehicleId, garageName, accessPoint)
    -- Garantir que sempre remova o preview antes de spawnar
    hideVehiclePreview()
    
    if spawnLock then
        exports.qbx_core:Notify(locale('error.spawn_in_progress'))
        return
    end
    spawnLock = true
    
    local success, result = pcall(function()
        if cache.vehicle then
            exports.qbx_core:Notify(locale('error.in_vehicle'))
            return
        end

        local netId = lib.callback.await('qbx_garages:server:spawnVehicle', false, vehicleId, garageName, accessPoint)
        if not netId then 
            hideVehiclePreview()  -- Garantir que remove o preview mesmo se falhar
            return 
        end

        local veh = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return NetToVeh(netId)
            end
        end)

        if veh == 0 then
            hideVehiclePreview()  -- Garantir que remove o preview se der erro
            exports.qbx_core:Notify('Something went wrong spawning the vehicle', 'error')
            return
        end

        if config.engineOn then
            SetVehicleEngineOn(veh, true, true, false)
        end
        
        -- Garantir que o preview foi removido após spawnar com sucesso
        hideVehiclePreview()
    end)
    spawnLock = false
    
    -- Fechar todos os menus após spawnar
    lib.hideContext()
    
    assert(success, result)
end

---@param vehicle PlayerVehicle
---@param garageName string
---@param garageInfo GarageConfig
---@param accessPoint integer
local function displayVehicleInfo(vehicle, garageName, garageInfo, accessPoint)
    local engine = qbx.math.round(vehicle.props.engineHealth / 10)
    local body = qbx.math.round(vehicle.props.bodyHealth / 10)
    local engineColor = getProgressColor(engine)
    local bodyColor = getProgressColor(body)
    local fuelColor = getProgressColor(vehicle.props.fuelLevel)
    local vehicleLabel = ('%s %s'):format(VEHICLES[vehicle.modelName].brand, VEHICLES[vehicle.modelName].name)

    -- Usar coordenadas da garagem para spawn se não especificado
    local spawnCoords = garageInfo.accessPoints[accessPoint].coords
    showVehiclePreview(vehicle.props.model, spawnCoords.xyz, spawnCoords.w, vehicle.props)

    local options = {
        {
            title = locale('menu.information'),
            icon = 'circle-info',
            description = locale('menu.description', vehicleLabel, vehicle.props.plate, lib.math.groupdigits(vehicle.depotPrice)),
            readOnly = true,
        },
        {
            title = 'Quilometragem',
            icon = 'road',
            readOnly = true,
            description = string.format('%s km', lib.math.groupdigits(vehicle.total_distance or 0)),
        },
        {
            title = locale('menu.body'),
            icon = 'car-side',
            readOnly = true,
            progress = body,
            colorScheme = bodyColor,
        },
        {
            title = locale('menu.engine'),
            icon = 'oil-can',
            readOnly = true,
            progress = engine,
            colorScheme = engineColor,
        },
        {
            title = locale('menu.fuel'),
            icon = 'gas-pump',
            readOnly = true,
            progress = vehicle.props.fuelLevel,
            colorScheme = fuelColor,
        }
    }
    
    if vehicle.last_pulled_by and vehicle.last_pulled_at then
        options[#options + 1] = {
            title = 'Último Uso',
            icon = 'user-clock',
            readOnly = true,
            description = string.format('Por: %s em %s', vehicle.last_pulled_by, vehicle.last_pulled_at),
        }
    end

    if vehicle.state == VehicleState.OUT then
        if garageInfo.type == GarageType.DEPOT then
            options[#options + 1] = {
                title = 'Take out',
                icon = 'fa-truck-ramp-box',
                description = ('$%s'):format(lib.math.groupdigits(vehicle.depotPrice)),
                arrow = true,
                onSelect = function()
                    lib.hideContext()  -- Fechar menu primeiro
                    hideVehiclePreview()  -- Remover preview
                    takeOutOfGarage(vehicle.id, garageName, accessPoint)
                end,
            }
        else
            options[#options + 1] = {
                title = 'Your vehicle is already out...',
                icon = VehicleType.CAR,
                readOnly = true,
            }
        end
    elseif vehicle.state == VehicleState.GARAGED then
        options[#options + 1] = {
            title = locale('menu.take_out'),
            icon = 'car-rear',
            arrow = true,
            onSelect = function()
                lib.hideContext()  -- Fechar menu primeiro
                hideVehiclePreview()  -- Remover preview
                takeOutOfGarage(vehicle.id, garageName, accessPoint)
            end,
        }
    elseif vehicle.state == VehicleState.IMPOUNDED then
        options[#options + 1] = {
            title = locale('menu.veh_impounded'),
            icon = 'building-shield',
            readOnly = true,
        }
    end

    lib.registerContext({
        id = 'vehicleList',
        title = garageInfo.label,
        menu = 'garageMenu',
        options = options,
        onClose = function()
            hideVehiclePreview()
        end,
    })

    lib.showContext('vehicleList')
end

---@param garageName string
---@param garageInfo GarageConfig
---@param accessPoint integer
local function openGarageMenu(garageName, garageInfo, accessPoint)
    ---@type PlayerVehicle[]?
    local vehicleEntities = lib.callback.await('qbx_garages:server:getGarageVehicles', false, garageName)

    if not vehicleEntities then
        exports.qbx_core:Notify(locale('error.no_vehicles'), 'error')
        return
    end

    table.sort(vehicleEntities, function(a, b)
        return a.modelName < b.modelName
    end)

    local options = {}
    for i = 1, #vehicleEntities do
        local vehicleEntity = vehicleEntities[i]
        local vehicleLabel = ('%s %s'):format(VEHICLES[vehicleEntity.modelName].brand, VEHICLES[vehicleEntity.modelName].name)

        options[#options + 1] = {
            title = vehicleLabel,
            description = vehicleEntity.props.plate,
            arrow = true,
            onSelect = function()
                displayVehicleInfo(vehicleEntity, garageName, garageInfo, accessPoint)
            end,
        }
    end

    lib.registerContext({
        id = 'garageMenu',
        title = garageInfo.label,
        options = options,
        onClose = function()
            hideVehiclePreview()
        end,
    })

    lib.showContext('garageMenu')
end

---@param vehicle number
---@param garageName string
local function parkVehicle(vehicle, garageName)
    if GetVehicleNumberOfPassengers(vehicle) ~= 1 then
        local isParkable = lib.callback.await('qbx_garages:server:isParkable', false, garageName, NetworkGetNetworkIdFromEntity(vehicle))

        if not isParkable then
            exports.qbx_core:Notify(locale('error.not_owned'), 'error', 5000)
            return
        end

        kickOutPeds(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
        Wait(1500)
        
        -- Usar função completa para capturar estado do veículo
        local completeProps = getCompleteVehicleProperties(vehicle)
        lib.callback.await('qbx_garages:server:parkVehicle', false, NetworkGetNetworkIdFromEntity(vehicle), completeProps, garageName)
        exports.qbx_core:Notify(locale('success.vehicle_parked'), 'primary', 4500)
    else
        exports.qbx_core:Notify(locale('error.vehicle_occupied'), 'error', 3500)
    end
end

---@param garage GarageConfig
---@return boolean
local function checkCanAccess(garage)
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(garage.groups, QBX.PlayerData) then
        exports.qbx_core:Notify(locale('error.no_access'), 'error')
        return false
    end
    if cache.vehicle and not isOfType(garage.vehicleType, cache.vehicle) then
        exports.qbx_core:Notify(locale('error.not_correct_type'), 'error')
        return false
    end
    return true
end

---@param garageName string
---@param garage GarageConfig
---@param accessPoint AccessPoint
---@param accessPointIndex integer
local function createZones(garageName, garage, accessPoint, accessPointIndex)
    CreateThread(function()
        accessPoint.dropPoint = accessPoint.dropPoint or accessPoint.spawn or accessPoint.coords
        
        -- Criar zona unificada para acesso via radial menu
        lib.zones.sphere({
            coords = accessPoint.coords,
            radius = 3.0,
            onEnter = function()
                isNearGarage = true
                currentGarage = {
                    name = garageName,
                    garage = garage,
                    accessPoint = accessPointIndex
                }
                -- Adicionar opção no radial menu
                TriggerEvent('qbx_radialmenu:client:addOption', {
                    id = 'open_garage_' .. garageName,
                    label = garage.type == GarageType.DEPOT and 'Apreensão' or 'Garagem',
                    icon = 'car',
                    onSelect = function()
                        if not checkCanAccess(garage) then return end
                        if cache.vehicle and garage.type ~= GarageType.DEPOT then
                            parkVehicle(cache.vehicle, garageName)
                        else
                            openGarageMenu(garageName, garage, accessPointIndex)
                        end
                    end
                })
            end,
            onExit = function()
                isNearGarage = false
                currentGarage = nil
                -- Remover preview ao sair da zona da garagem
                hideVehiclePreview()
                -- Remover opção do radial menu
                TriggerEvent('qbx_radialmenu:client:removeOption', 'open_garage_' .. garageName)
            end,
            inside = function()
                if accessPoint.dropPoint then
                    config.drawDropOffMarker(accessPoint.dropPoint)
                end
                config.drawGarageMarker(accessPoint.coords.xyz)
            end,
            debug = config.debugPoly,
        })
    end)
end

---@param garageInfo GarageConfig
---@param accessPoint AccessPoint
local function createBlips(garageInfo, accessPoint)
    local blip = AddBlipForCoord(accessPoint.coords.x, accessPoint.coords.y, accessPoint.coords.z)
    SetBlipSprite(blip, accessPoint.blip.sprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.60)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, accessPoint.blip.color or 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(accessPoint.blip.name or garageInfo.label)
    EndTextCommandSetBlipName(blip)
end

local function createGarage(name, garage)
    local accessPoints = garage.accessPoints
    for i = 1, #accessPoints do
        local accessPoint = accessPoints[i]

        if accessPoint.blip then
            createBlips(garage, accessPoint)
        end

        createZones(name, garage, accessPoint, i)
    end
end

local function createGarages()
    local garages = lib.callback.await('qbx_garages:server:getGarages')
    for name, garage in pairs(garages) do
        createGarage(name, garage)
    end
end

RegisterNetEvent('qbx_garages:client:garageRegistered', function(name, garage)
    createGarage(name, garage)
end)

CreateThread(function()
    createGarages()
end)

local previewVeh = nil

showVehiclePreview = function(model, coords, heading, props)
    if previewVeh then
        DeleteEntity(previewVeh)
        previewVeh = nil
    end

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    previewVeh = CreateVehicle(model, coords.x, coords.y, coords.z + 1.0, heading, false, false)
    SetEntityAlpha(previewVeh, 180, false)
    SetEntityCollision(previewVeh, false, false)
    SetEntityCompletelyDisableCollision(previewVeh, true, true)
    SetEntityInvincible(previewVeh, true)
    SetVehicleDoorsLocked(previewVeh, 2)
    SetEntityAsMissionEntity(previewVeh, true, true)
    SetEntityVisible(previewVeh, true, false)
    if props then
        lib.setVehicleProperties(previewVeh, props)
    end
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(previewVeh, true)
end

hideVehiclePreview = function()
    if previewVeh and DoesEntityExist(previewVeh) then
        DeleteEntity(previewVeh)
        previewVeh = nil
    end
end

-- Thread para monitorar fechamento de menus e garantir que preview seja removido
CreateThread(function()
    while true do
        Wait(100)
        -- Se não está em nenhum menu e tem preview, remove
        if previewVeh and not lib.getOpenContextMenu() then
            hideVehiclePreview()
        end
    end
end)

-- Evento para garantir que preview seja removido ao pressionar ESC
RegisterCommand('+menu_back', function()
    if previewVeh then
        hideVehiclePreview()
    end
end, false)
RegisterKeyMapping('+menu_back', 'Close Menu and Hide Preview', 'keyboard', 'ESCAPE')

-- Cleanup ao parar o resource
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        hideVehiclePreview()
    end
end)

-- Evento para aplicar estado completo do veículo após spawn
RegisterNetEvent('qbx_garages:client:applyCompleteVehicleState', function(netId, props)
    CreateThread(function()
        local vehicle = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return NetToVeh(netId)
            end
        end, 'Failed to get vehicle from network id', 5000)
        
        if vehicle and vehicle ~= 0 then
            -- Aguardar o veículo estar totalmente carregado
            Wait(500)
            applyCompleteVehicleProperties(vehicle, props)
        end
    end)
end)
