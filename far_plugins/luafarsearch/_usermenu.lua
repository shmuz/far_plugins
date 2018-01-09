-- coding: utf-8

AddCommand("test", "test_lfsearch")

 AddToMenu ("e", "A. Self-test", nil, "test_lfsearch")

AddToMenu("e", "batch-1", nil, "scripts/batch-1")

AddToMenu ("e", ":sep:User scripts")

AddToMenu ("e", "URLs", nil, "scripts/presets", "url")
AddToMenu ("e", "Credit Card numbers", nil, "scripts/presets", "creditcard")
AddToMenu ("e", "Total stolen money", nil, "scripts/shmuz/stolen")
----------------------------------------
local DataFile = "scripts/Rh_Presets"
local Data = require "scripts.Rh_Presets"

AddToMenu("e", ":sep:Rh Presets")

for _,v in ipairs(Data) do
  AddToMenu("e", v.text, nil, DataFile, v.name)
end
----------------------------------------
