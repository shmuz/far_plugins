local ret = far.Message("Press any button", "Hello, Lua!", "&1;&2;&3")
far.Message(ret<1 and "You cancelled the dialog"
                   or "You pressed the button "..ret)
