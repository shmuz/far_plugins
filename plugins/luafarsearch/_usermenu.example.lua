AddCommand("test", "test_lfsearch")

AddToMenu ("e", "A. Self-test", nil, "test_lfsearch")
AddToMenu ("e", ":sep:User scripts")
AddToMenu ("e", "URLs", nil, "scripts/presets", "url")
AddToMenu ("e", "Credit Card numbers", nil, "scripts/presets", "creditcard")
