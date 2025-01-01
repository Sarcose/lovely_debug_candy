A quick and dirty implementation of colored eyecandy for console debug printouts, with errors, warnings, debug messages, and a todo list if that interests you. Uses a pseudonamespace of `_c_` because that's what works personally for me. Feel free to modify that.

Just `require "debugcandy.lua"` and start using it with: 

`_c_debug(msg,level)`\
`_c_error(msg,level)`\
`_c_warn(msg,level)`\
`_c_stop(msg,level)`\
`_c_todo{"12/31/2024","XChecked Option","Unchecked Option"}`

There are three globals *I* personally use in this implementation. As-is they are needed to run but they are declared in the file. Feel free to tinker with this and remove those calls if need be:

`DEBUGMODE = true` : enables `_c_debug()` and `_c_todo` otherwise they won't print. Good for just parsing warnings and errors.\
`DEBUGBASELEVEL = 2` : sets the base level of stacktrace to be printed. By stacktrace I mean the following example: 
 * `[assets.lua:38][main.lua:10]`
 * Higher levels go back more files.
`TODOEXPIRATION = 5` : number of days before a Todo list shows a warning that it hasn't been touched. Starts yellow, then at `TODOEXPIRATION*3` becomes red. Date is passed as `t[1]` in the format of `"12/31/2024"`

For further explanations see the comments in `debugcandy.lua` 
