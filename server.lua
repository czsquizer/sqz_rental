local rentedVehicles = {}
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterNetEvent('sqz_carrental:RentVehicle')
AddEventHandler('sqz_carrental:RentVehicle', function(model, insurance, price, time, rentalIndex)
    time = time:gsub('min', '')
    time =  tonumber(time)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.getMoney() >= price + Config.DownPayment then
        xPlayer.removeMoney(price + Config.DownPayment)
        xPlayer.showNotification('You have paid '..price..'$')
        xPlayer.showNotification('You have paid '..Config.DownPayment..'$ as a down payment')
        TriggerClientEvent('sqz_carrental:SpawnVehicle', source, model, insurance, price, time, rentalIndex)
    elseif xPlayer.getAccount('bank').money >= price + Config.DownPayment then
        xPlayer.removeAccountMoney('bank', price + Config.DownPayment)
        xPlayer.showNotification('You have paid '..Config.DownPayment..'$ as a down payment from your bank account')
        xPlayer.showNotification('You have paid '..price..'$ from your bank account')
        TriggerClientEvent('sqz_carrental:SpawnVehicle', source, model, insurance, price, time, rentalIndex)
    else
        xPlayer.showNotification('You can not afford renting this vehicle')
    end
end)

RegisterNetEvent('sqz_carrental:VehicleSpawned')
AddEventHandler('sqz_carrental:VehicleSpawned', function(plate, insurance, time, netId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not rentedVehicles[plate] then
        rentedVehicles[plate] = {
            owner = xPlayer.identifier,
            insurance = insurance,
            netId = netId,
            downPayment = Config.DownPayment
        }
        SetTimeout(time * 60 * 1000 + 5000, function()
            local plate = GetVehicleNumberPlateText(NetworkGetEntityFromNetworkId(netId))
            if rentedVehicles[plate] then
                if GetPlayerPing(rentedVehicles[plate].owner) > 5 then
                    Citizen.CreateThread(function()
                        
                        while true do
                            Wait(1000 * 60)
                            if rentedVehicles[plate].downPayment >= Config.ExtraChargePerMinute then
                                rentedVehicles[plate].downPayment = rentedVehicles[plate].downPayment - Config.ExtraChargePerMinute
                            else
                                if ESX.GetPlayerFromId(_source) then
                                    xPlayer.showNotification('The deposit will not be refunded, because you have not returned the vehicle')
                                    xPlayer.showNotification('The vehicle has been impounded')
                                end
                                DeleteEntity(NetworkGetEntityFromNetworkId(netId))
                                rentedVehicles[plate] = nil
                            end
                        end
                    end)
                else
                    rentedVehicles[plate] = nil
                    DeleteEntity(NetworkGetEntityFromNetworkId(netId))
                end
            end
        end)
    end
end)

RegisterNetEvent('sqz_carrental:ReturnVehicle')
AddEventHandler('sqz_carrental:ReturnVehicle', function(plate, damageIndex)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not rentedVehicles[plate] then
        xPlayer.showNotification('You can not return this vehicle because this one has not been rented.')
        return
    end

    if rentedVehicles[plate].owner ~= xPlayer.identifier then
        xPlayer.showNotification('You can not return this vehicle because you are not borrower.')
        return
    end

    if rentedVehicles[plate].insurance then
        damageIndex = 1
    end

    local moneyToGive = math.floor(rentedVehicles[plate].downPayment * damageIndex)

    if damageIndex < 1 then
        local reducedBy = Config.DownPayment - Config.DownPayment * damageIndex
        xPlayer.showNotification('Down payment you should receive has been lowered by '..reducedBy..'$ because you have returned the vehicle damaged')
    end

    xPlayer.addAccountMoney('bank', moneyToGive)
    xPlayer.showNotification('The down payment of amount '..moneyToGive..'$ has been returned you.')
    TaskLeaveVehicle(GetPlayerPed(source), NetworkGetEntityFromNetworkId(rentedVehicles[plate].netId), 0)
    Wait(1700)
    DeleteEntity(NetworkGetEntityFromNetworkId(rentedVehicles[plate].netId))
    rentedVehicles[plate] = nil
    TriggerClientEvent('sqz_carrental:VehicleSuccessfulyReturned', xPlayer.source)
end)