local rentalTimer = 0
local lastLocalVehicle

Citizen.CreateThread(function()
    AddTextEntry('carRental', 'Vehicle Rental')
    AddTextEntry('carRentalClose', '~INPUT_PICKUP~ Vehicle Rental')
    while true do
        Wait(0)
        local letSleep = true
        if rentalTimer == 0 then
            local pedCoords = GetEntityCoords(PlayerPedId())
            for k, v in pairs(Config.Points) do
                local dist = #(pedCoords - v.Pos)
                if dist < 1.5 and not IsPedInAnyVehicle(PlayerPedId()) then
                    letSleep = false
                    BeginTextCommandDisplayHelp('carRentalClose')
                    EndTextCommandDisplayHelp(1, 0, 0, 0)
                    SetFloatingHelpTextWorldPosition(0, v.Pos)

                    if IsControlJustPressed(0, 38) then
                        OpenCarRental(k)
                        Wait(500)
                    end
                elseif dist < 5 and not IsPedInAnyVehicle(PlayerPedId()) then
                    letSleep = false
                    BeginTextCommandDisplayHelp('carRental')
                    EndTextCommandDisplayHelp(1, 0, 0, 0)
                    SetFloatingHelpTextWorldPosition(0, v.Pos)
                end
            end
        else
            Wait(1000)
        end

        if letSleep then
            Wait(500)
        end
    end
end)

WarMenu.CreateMenu('carRental', 'Vehicle Rental')

function OpenCarRental(index)
    WarMenu.OpenMenu('carRental')
    local price = 0
    local vehicleIndex = 1
    local rentalTimeIndex = 1
    local vehiclesToRent = {}


    for k, v in pairs(Config.Points[index].Vehicles) do
        table.insert(vehiclesToRent, v.model)
    end

    SpawnLocalVehicle(vehiclesToRent[1], Config.Points[index].SpawnPoint)

    while true do
        Wait(0)
        if WarMenu.Begin('carRental') then

            local _, vehicleId = WarMenu.ComboBox('Select Vehicle', vehiclesToRent, vehicleIndex)
            if vehicleIndex ~= vehicleId then
                vehicleIndex = vehicleId
                if DoesEntityExist(lastLocalVehicle) then
                    DeleteEntity(lastLocalVehicle)
                    lastLocalVehicle = nil
                    FreezeEntityPosition(PlayerPedId(), false)
                    SetEntityInvincible(PlayerPedId(), false)
                    SetEntityCoords(PlayerPedId(), Config.Points[index].Pos)
                end
                SpawnLocalVehicle(vehiclesToRent[vehicleId], Config.Points[index].SpawnPoint)
            end

            local _, totalTime = WarMenu.ComboBox('Vehicle Rental Time', Config.RentalTimes, rentalTimeIndex)
            if rentalTimeIndex ~= totalTime then
                rentalTimeIndex = totalTime
            end

            if WarMenu.CheckBox('Insurance - '..Config.InsurancePrice..'$', insurance) then
                insurance = not insurance
            end

            if WarMenu.IsItemHovered() then
                WarMenu.ToolTip('In case you damage the car, you will pay no additional fees')
            end

            price = Config.Points[index].Vehicles[vehicleIndex].price
            price = price * rentalTimeIndex
            if insurance then
                price = price + Config.InsurancePrice
            end

            if WarMenu.Button('Rent Vehicle', price..'$') then
                if DoesEntityExist(lastLocalVehicle) then
                    DeleteEntity(lastLocalVehicle)
                    lastLocalVehicle = nil
                    FreezeEntityPosition(PlayerPedId(), false)
                    SetEntityInvincible(PlayerPedId(), false)
                    SetEntityCoords(PlayerPedId(), Config.Points[index].Pos)
                end
                TriggerServerEvent('sqz_carrental:RentVehicle', vehiclesToRent[vehicleId], insurance, price, Config.RentalTimes[rentalTimeIndex], index)
                return
            end

            
            WarMenu.End()
        else
            if DoesEntityExist(lastLocalVehicle) then
                DeleteEntity(lastLocalVehicle)
                lastLocalVehicle = nil
                FreezeEntityPosition(PlayerPedId(), false)
                SetEntityInvincible(PlayerPedId(), false)
                SetEntityCoords(PlayerPedId(), Config.Points[index].Pos)
            end
            return
        end
    end

end

function SpawnLocalVehicle(model, coords)
    model = GetHashKey(model)
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    lastLocalVehicle = CreateVehicle(model, coords, GetEntityHeading(PlayerPedId()), true, false)

    SetEntityAsMissionEntity(lastLocalVehicle, true, true)
    SetVehicleOnGroundProperly(lastLocalVehicle)
    FreezeEntityPosition(lastLocalVehicle, true)
    SetEntityInvincible(lastLocalVehicle, true)
    SetVehicleDoorsLocked(lastLocalVehicle, 2)
    TaskWarpPedIntoVehicle(PlayerPedId(), lastLocalVehicle, -1)
    FreezeEntityPosition(PlayerPedId(), true)
    SetEntityInvincible(PlayerPedId(), true)
end

Citizen.CreateThread(function()

    for k, v in pairs(Config.Points) do
        local blip = AddBlipForCoord(v.Pos)

        SetBlipSprite (blip, 147)
		SetBlipDisplay(blip, 4)
		SetBlipScale  (blip, 0.8)
		SetBlipColour (blip, 24)
		SetBlipAsShortRange(blip, true)
        SetBlipHighDetail(blip, true)

		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName('Vehicle Rental')
		EndTextCommandSetBlipName(blip)
    end

end)

local returnBlips = {}

function createReturnBlips()

    for k, v in pairs(Config.ReturnPoints) do
        local blip = AddBlipForCoord(v)

        SetBlipSprite (blip, 527)
		SetBlipDisplay(blip, 4)
		SetBlipScale  (blip, 0.8)
		SetBlipColour (blip, 65)
		SetBlipAsShortRange(blip, true)
        SetBlipHighDetail(blip, true)

		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName('Vehicle Return Point')
		EndTextCommandSetBlipName(blip)
        table.insert(returnBlips, blip)
    end

end

RegisterNetEvent('sqz_carrental:SpawnVehicle')
AddEventHandler('sqz_carrental:SpawnVehicle', function(model, insurance, price, time, rentalIndex)
    model = GetHashKey(model)

    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(10)
    end

    local vehicle = CreateVehicle(model, Config.Points[rentalIndex].SpawnPoint, GetEntityHeading(PlayerPedId()), true, false)
    while not DoesEntityExist(vehicle) do
        Wait(10)
    end
    local netId = VehToNet(vehicle)
    SetNetworkIdCanMigrate(netId, false)
    SetEntityAsMissionEntity(vehicle, true, true)

    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)

    TriggerServerEvent('sqz_carrental:VehicleSpawned', GetVehicleNumberPlateText(vehicle), insurance, time, netId)

    rentalTimer = time * 60

    createReturnBlips()

    startTimer()
end)

function disp_time(time)
    local minutes = math.floor((time%3600/60))
    local seconds = math.floor((time%60))
    return string.format("%02dm %02ds",minutes,seconds)
end

function startTimer()
    Citizen.CreateThread(function()
        Citizen.CreateThread(function()
            while rentalTimer>0 do
                rentalTimer=rentalTimer-1
                Citizen.Wait(1000)
            end
        end)
        while rentalTimer>0 do
            Citizen.Wait(0)
            SetTextFont(4)
            SetTextScale(0.45, 0.45)
            SetTextColour(185, 185, 185, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextDropShadow()
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(disp_time(rentalTimer).." - Rental Time Remaining")
            EndTextCommandDisplayText(0.05, 0.55)
        end
    end)
end

Citizen.CreateThread(function()
    AddTextEntry('carReturn', 'Vehicle return point')
    AddTextEntry('carReturnClose', '~INPUT_PICKUP~ Return Vehicle')
    while true do
        Wait(0)
        if rentalTimer > 0 then
            local letSleep = true
            local pedCoords = GetEntityCoords(PlayerPedId())
            for k, v in pairs(Config.ReturnPoints) do
                local dist = #(v - pedCoords)
                if dist < 2.5 and IsPedInAnyVehicle(PlayerPedId()) then
                    letSleep = false
                    BeginTextCommandDisplayHelp('carReturnClose')
                    EndTextCommandDisplayHelp(1, 0, 0, 0)
                    SetFloatingHelpTextWorldPosition(0, v)
    
                    if IsControlJustPressed(0, 38) then
                        ReturnVehicle()
                        Wait(2000)
                    end
                elseif dist < 10 and IsPedInAnyVehicle(PlayerPedId()) then
                    letSleep = false
                    BeginTextCommandDisplayHelp('carReturn')
                    EndTextCommandDisplayHelp(1, 0, 0, 0)
                    SetFloatingHelpTextWorldPosition(0, v)
                end
            end
            if letSleep then
                Wait(500)
            end
        else
            Wait(100)
        end
    end

end)

function ReturnVehicle()

    local vehicle = GetVehiclePedIsIn(PlayerPedId())

    local health = (GetVehicleEngineHealth(vehicle) + GetVehicleBodyHealth(vehicle)) / 2
    TriggerServerEvent('sqz_carrental:ReturnVehicle', GetVehicleNumberPlateText(vehicle), health/1000)
end

RegisterNetEvent('sqz_carrental:VehicleSuccessfulyReturned')
AddEventHandler('sqz_carrental:VehicleSuccessfulyReturned', function()

    rentalTimer = 0
    local sec = 3
    local scaleform = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')

    for i=1, #returnBlips do
        if DoesBlipExist(returnBlips[i]) then
            RemoveBlip(returnBlips[i])
        end
    end

	while not HasScaleformMovieLoaded(scaleform) do
		Citizen.Wait(0)
	end

	BeginScaleformMovieMethod(scaleform, 'SHOW_SHARD_WASTED_MP_MESSAGE')
	PushScaleformMovieMethodParameterString('Vehicle Rental')
	PushScaleformMovieMethodParameterString('Vehicle has been successfuly returned')
	EndScaleformMovieMethod()

	while sec > 0 do
		Citizen.Wait(1)
		sec = sec - 0.01

		DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
	end

	SetScaleformMovieAsNoLongerNeeded(scaleform)
end)