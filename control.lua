require("lib")

local anz_train = 0
local anz_provider = 0


function OnInit()
	global = {}
	global.TrainList = {}
	global.ProviderList = {}
end
script.on_init(OnInit)


function OnLoad()
	anz_train = Count(global.TrainList)
	anz_provider = Count(global.ProviderList)
end
script.on_load(OnLoad)

function OnConfigurationChanged(data)
	local mod_name = "ElectricTrain"
	if IsModChanged(data,mod_name) then
		if data.mod_changes[mod_name].old_version == "0.17.201" or GetOldVersion(data,mod_name) < "00.17.05" then
			OnInit()
			for _,surface in pairs(game.surfaces) do
				local trains = surface.find_entities_filtered{type="locomotive"}
				for _,train in pairs(trains) do
					if train.name:match("^et%-electric%-locomotive%-%d$") then
						table.insert(global.TrainList,train)
						train.burner.currently_burning = game.item_prototypes['et-electric-locomotive-fuel']
						train.burner.remaining_burning_fuel = train.burner.currently_burning.fuel_value
					end
				end	
				local providers = surface.find_entities_filtered{type="electric-energy-interface"}
				for _,provider in pairs(providers) do
					if provider.name == "et-electricity-provider" then
						table.insert(global.ProviderList,provider)
					end
				end	
			end
			anz_train = Count(global.TrainList)
			anz_provider = Count(global.ProviderList)
		end
	end
end
script.on_configuration_changed(OnConfigurationChanged)

--error(global.FuelValue)
function OnBuilt(event)
	local entity = event.created_entity
	if entity and entity.valid then
		if entity.name == "et-electricity-provider" and entity.type == "electric-energy-interface" then
			table.insert(global.ProviderList,entity)
			anz_provider = anz_provider + 1
		elseif entity.name:match("^et%-electric%-locomotive%-%d$") and entity.type == "locomotive" then 
			table.insert(global.TrainList,entity)
			entity.burner.currently_burning = game.item_prototypes['et-electric-locomotive-fuel']
			entity.burner.remaining_burning_fuel = entity.burner.currently_burning.fuel_value
			anz_train = anz_train + 1
		end
	end
end
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,defines.events.script_raised_built},OnBuilt)


function OnTick()
	if anz_provider > 0 and anz_train > 0 then
		local need_power = 0
		local provider_power = 0
		local rest_power = 0
		local split_power = 0
		
		for i,provider in pairs(global.ProviderList) do
			if provider and provider.valid then
				provider_power = provider_power + provider.energy
			else
				table.remove(global.ProviderList,i)
				anz_provider = anz_provider - 1
			end
		end
			
		if provider_power > 0 then 
			for i,train in pairs(global.TrainList) do
				if train and train.valid then
					need_power = need_power + train.burner.currently_burning.fuel_value - train.burner.remaining_burning_fuel		
				else
					table.remove(global.TrainList,i)
					anz_train = anz_train - 1
				end
			end
		
			rest_power = provider_power - need_power
			if rest_power >= 0 then
				for _,train in pairs(global.TrainList) do
					train.burner.remaining_burning_fuel = train.burner.currently_burning.fuel_value
				end
				split_power = rest_power / #global.ProviderList
				for _,provider in pairs(global.ProviderList) do
					provider.energy = split_power
				end
			else
				for _,provider in pairs(global.ProviderList) do
					provider.energy = 0
				end
				split_power = provider_power / #global.TrainList
				for _,train in pairs(global.TrainList) do
					train.burner.remaining_burning_fuel = train.burner.remaining_burning_fuel + split_power
				end
			end
		end
	end
end
script.on_event(defines.events.on_tick,OnTick)