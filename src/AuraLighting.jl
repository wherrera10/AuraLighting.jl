module AuraLighting

using ZMQ

export AuraMbControl, AuraControlClient, getcolor, setcolor, setmode
export rbgtoi, itorbg, startserver, iscorrectcontroller, sendexit
export AuraGPUControl, AuraKeyboardControl, AuraMouseControl

const Handle = Ptr{Cvoid}
const Hptr = Ptr{Ptr{Cvoid}}
const Bptr = Ptr{UInt8}

"""
NOTE: THIS DLL FILE MUST BE EITHER BE LOCATED IN THE DIRECTORY WHERE PROGRAM IS RUN,
OR ELSE YOU SHOULD PLACE A COPY IN A DIRECTORY IN YOUR PATH.
"""
const DLLNAME = "AURA_SDK.dll"

""" rgb integer to UInt8 (r, g, b) """
itorbg(i) = [UInt8((i >> 16) & 0xff), UInt8((i >> 8) & 0xff), UInt8(i & 0xff)]

""" UInt8 (r, g, b) to rgb integer """
rbgtoi(r, g, b) = ((UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)) & 0xffffff

abstract type AuraControl end

struct AuraMbControl <: AuraControl
    controllernumber::Int
    LEDcount::Int
    handle::Handle
    colorbuf::Vector{UInt8}
    buflen::Int
    port::Int
    AuraMbControl(c, n, h, p) = new(c, n, h, zeros(UInt, n * 3), n * 3, p)
end

"""
    function AuraMbControl(cont=1; asservice=false, port=5555)

Constructor for an AuraMBControl.
cont: controller number, defaults to 1 (first or only controller found)
port: port number of ZMQ service, defaults to 5555
"""
function AuraMbControl(cont=1, port=5555)
    GC.enable(false)
    hcount = ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr, Cint), C_NULL, 0)
    handles = [C_NULL for _ in 1:hcount]
    GC.@preserve handles begin
        ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr, Cint), handles, hcount) 
        handle = handles[hcount]
        LEDcount = ccall((:GetMbLedCount, DLLNAME), Cint, (Handle,), handle)
        Libc.free(handles)
        return AuraMbControl(cont, LEDcount, handle, port)
    end
end

struct AuraGPUControl <: AuraControl
    controllernumber::Int
    LEDcount::Int
    handle::Handle
    colorbuf::Vector{UInt8}
    buflen::Int
    port::Int
    AuraGPUControl(c, n, h, p) = new(c, n, h, zeros(UInt, n * 3), n * 3, p)
end

"""
    function AuraGPUControl(cont=1, port=5556)

Constructor for an AuraGPUControl.
cont: controller number, defaults to 1 (first or only controller found)
port: port number of ZMQ service, defaults to 5556
"""
function AuraGPUControl(cont=1, port=5556)
    GC.enable(false)
    hcount = ccall((:EnumerateGPU, DLLNAME), Cint, (Hptr, Cint), C_NULL, 0)
    handles = [C_NULL for _ in 1:hcount]
    GC.@preserve handles begin
        ccall((:EnumerateGPU, DLLNAME), Cint, (Hptr, Cint), handles, hcount)
        handle = handles[max(min(hcount, cont), 1)]
        LEDcount = ccall((:GetGPULedCount, DLLNAME), Cint, (Handle,), handle)
        return AuraGPUControl(cont, LEDcount, handle, port)
    end
end

struct AuraKeyboardControl <: AuraControl
    LEDcount::Int
    handle::Handle
    colorbuf::Vector{UInt8}
    buflen::Int
    port::Int
    AuraKeyboardControl(n, h, p) = new(n, h, zeros(UInt, n * 3), n * 3, p)
end

"""
    function AuraKeyboardControl(cont=1; asservice=false, port=5557)
Constructor for an AuraKeyboardControl.
port: port number of ZMQ service, defaults to 5557
"""
function AuraKeyboardControl(port=5557)
    GC.enable(false)
    handles = [C_NULL]
    GC.@preserve handles begin
        ccall((:CreateClaymoreKeyboard, DLLNAME), Cint, (Hptr,), handles)
        handle = handles[1]
        LEDcount = ccall((:GetClaymoreKeyboardLedCount, DLLNAME), Cint, (Handle,), handle)
        return AuraKeyboardControl(LEDcount, handle, port)
    end
end

struct AuraMouseControl <: AuraControl
    LEDcount::Int
    handle::Handle
    colorbuf::Vector{UInt8}
    buflen::Int
    port::Int
    AuraMouseControl(n, h, p) = new(n, h, zeros(UInt, n * 3), n * 3, p)
end

"""
    function AuraMouseControl(cont=1; asservice=false, port=5558)
Constructor for an AuraMouseControl.
port: port number of ZMQ service, defaults to 5558
"""
function AuraMouseControl(port=5558)
    GC.enable(false)
    handles = [C_NULL]
    GC.@preserve handles begin
        ccall((:CreateRogMouse, DLLNAME), Cint, (Hptr,), handles)
        handle = handles[1]
        LEDcount = ccall((:GetRogLedCount, DLLNAME), Cint, (Handle,), handle)
        return AuraMouseControl(LEDcount, handle, port)
    end
end

function startserver(au::AuraControl)
    @async begin ZMQservice(au) end
end

""" only motherboard and GPU have controller number, all others are just 1 """
controllernumber(au::AuraMbControl) = au.controllernumber
controllernumber(au::AuraGPUControl) = au.controllernumber
controllernumber(au::AuraControl) = 1

"""
   function setmode(au::AuraMbControl, setting::Integer=0)

Set mode of motherboard Aura controller from software control to an auto mode

A setting of 0 will change to the auto mode. A setting of 1 is software control.
"""
function setmode(au::AuraMbControl, setting::Integer)
    0 <= setting <= 1 || return false
    h = au.handle
    return ccall((:SetMbMode, DLLNAME), Cint, (Handle, Cint), h, setting)
end

function setmode(au::AuraGPUControl, setting::Integer)
    0 <= setting <= 1 || return false
    h = au.handle
    return ccall((:SetGPUMode, DLLNAME), Cint, (Handle, Cint), h, setting)
end

function setmode(au::AuraKeyboardControl, setting::Integer)
    0 <= setting <= 1 || return false
    h = au.handle
    return ccall((:SetClaymoreKeyboardMode, DLLNAME), Cint, (Handle, Cint), h, setting)
end

function setmode(au::AuraMouseControl, setting::Integer)
    0 <= setting <= 1 || return false
    h = au.handle
    return ccall((:SetRogMouseMode, DLLNAME), Cint, (Handle, Cint), h, setting)
end

"""
    function getcolor(auramb::AuraMbControl)

Get RGB color as a tuple of red, green, and blue values (0 to 255 each).
"""
function getcolor(au::AuraMbControl)
    for i in 1:au.buflen
        au.colorbuf[i] = 0x0
    end
    buf = au.colorbuf
    GC.@preserve buf begin
        ccall((:GetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint),
            au.handle, buf, au.buflen)
        return Int(buf[1]), Int(buf[2]), Int(buf[3])
    end
end

""" only motherboard currently can get color, though all types can set color """
function getcolor(au::AuraControl)
    return (-1, -1, -1)
end

"""
    function setcolor(au::AuraMbControl, red, green, blue)

Set RGB color via setting color with separate red, green, and blue values
"""
function setcolor(au::AuraMbControl, red, green, blue)
    for i in 1:3:au.buflen-1
        au.colorbuf[i], au.colorbuf[i+1], au.colorbuf[i+2] = red, green, blue
    end
    buf = au.colorbuf
    GC.@preserve buf begin
        success = ccall((:SetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint),
            au.handle, buf, au.buflen)
        return success == 1
    end
end

"""
    function setcolor(au::AuraGPUControl, red, green, blue)

Set RGB color via setting color with separate red, green, and blue values
"""
function setcolor(au::AuraGPUControl, red, green, blue)
    for i in 1:3:au.buflen-1
        au.colorbuf[i], au.colorbuf[i+1], au.colorbuf[i+2] = red, green, blue
    end
    buf = au.colorbuf
    GC.@preserve buf begin
        success = ccall((:SetGPUColor, DLLNAME), Cint, (Handle, Bptr, Cint),
            au.handle, buf, au.buflen)
        return success == 1
    end
end

"""
    function setcolor(au::AuraKeyboardControl, red, green, blue)

Set RGB color via setting color with separate red, green, and blue values
"""
function setcolor(au::AuraKeyboardControl, red, green, blue)
    for i in 1:3:au.buflen-1
        au.colorbuf[i], au.colorbuf[i+1], au.colorbuf[i+2] = red, green, blue
    end
    buf = au.colorbuf
    GC.@preserve buf begin
        success = ccall((:SetClaymoreKeyboardColor, DLLNAME), Cint, (Handle, Bptr, Cint),
            au.handle, buf, au.buflen)
        return success == 1
    end
end

"""
    function setcolor(au::AuraControl, red, green, blue)

Set RGB color via setting color with separate red, green, and blue values
"""
function setcolor(au::AuraMouseControl, red, green, blue)
    for i in 1:3:au.buflen-1
        au.colorbuf[i], au.colorbuf[i+1], au.colorbuf[i+2] = red, green, blue
    end
    buf = au.colorbuf
    GC.@preserve buf begin
        success = ccall((:SetRogMouseColor, DLLNAME), Cint, (Handle, Bptr, Cint),
            au.handle, buf, au.buflen)
        return success == 1
    end
end

"""
    function setcolor(au::AuraControl, rgb::Integer)

Set color of the LED light as an integer in 24-bit RGB format.
The color is of form hex 0xRRGGBB, where RR is the red component, GG green,
    and BB the blue values of an 24-bit RGB coded color.
Black is 0, white is 0x00ffffff, red 0xff0000, green 0x00ff00, blue 0x0000ff
"""
function setcolor(au::AuraControl, rgb)
    r, g, b = itorbg(rgb)
    setcolor(au, r, g, b)
end

"""
    function ZMQservice(au::AuraControl)

Serve requests via ZMQ to control the Aura lighting controller on the motherboard.
This must be run in 32-bit Windows mode with admin privileges.
"""
function ZMQservice(au::AuraControl)
    sock = Socket(REP)
    bind(sock, "tcp://*:$(au.port)")
    try
        while true
            message = recv(sock, String)
            cmd = message * " 0 0 "
            words = split(cmd, r"\s+")
            if words[1] == "getcolor"
                r, g, b = getcolor(au)
                if r == g == b == -1
                    send("ERROR not supported")
                else
                    send(sock, "OK $(rbgtoi(r, g, b))")
                end
            elseif words[1] == "setcolor" && (c = tryparse(Int, words[2])) != nothing
                setcolor(au, c)
                send(sock, "OK")
            elseif words[1] == "setmode" && (n = tryparse(Int, words[2])) != nothing
                setmode(au, n)
                send(sock, "OK")
            elseif words[1] == "getcontroller"
                send(sock, "OK $(controllernumber(au))")
            elseif words[1] == "exit"
                send(sock, "OK")
                break
            else
                @warn("Unknown command received: $message")
                send(sock, "ERROR in message received: $message")
            end
        end
    catch y
        @warn("ZMQ server fatal error: $y with message $message")
    finally
        close(sock)
    end
end

"""
    struct AuraControlClient

Client for a service to change Aura lighting via the 32-bit Win32 Aura lighting SDK.

This client can be any application and can be 64-bit even though the server must be
32-bit because ASUStek only provided a 32-bit DLL for Windows in its AuraSDK library.
"""
struct AuraControlClient
    sock::Socket
    controllernumber::Int
    function AuraControlClient(port=5555, server="localhost", cont=1)
        sock = Socket(REQ)
        connect(sock, "tcp://$server:$port")
        new(sock, cont)
    end
end

"""
    function iscorrectcontroller(client::AuraControlClient)

Check if the client's controller number matches the server's controller number.
It is not actually necessary these two match, but checking this may help avoid
sending commands to the wrong controller.
"""
function iscorrectcontroller(client::AuraControlClient)
    send(client.sock, "getcontroller")
    message = ZMQ.recv(client.sock, String)
    try
        s = split(message, r"\s+")
        n = tryparse(Int, s[2])
        return n == client.controllernumber
    catch
        return false
    end
end

"""
    function getcolor(client::AuraMBControlClient)

Get Aura lighting color as a tuple of red, green, and blue.
"""
function getcolor(client::AuraControlClient)
    try
        send(client.sock, "getcolor")
        message = ZMQ.recv(client.sock, String)
        s = split(message, r"\s+")
        if s[1] != "OK"
            @warn("Error, getcolor may not be supported")
        return (0, 0, 0)
        else
            c = parse(Int, s[2])
            return Tuple(itorbg(c))
        end
    catch y
        @warn("Error getting color: $y")
        return (0, 0, 0)
    end
end

"""
    function setcolor(client::AuraControlClient, color::Integer)

Set Aura lighting color to an RGB integer of form 0xrrggbb.
Return: true on success, false on failure
"""
function setcolor(client::AuraControlClient, color)
    try
        send(client.sock, "setcolor $(color & 0xffffff)")
        message = ZMQ.recv(client.sock, String)
        return message[1:2] == "OK"
    catch y
        @warn("Error setting color to $color: $y")
        return false
    end
end

"""
    function setcolor(client::AuraControlClient, r, g, b)

Set Aura lighting color to RGB color with components r red, g green, b blue.
Return: true on success, false on failure
"""
setcolor(client::AuraControlClient, r, g, b) = setcolor(client, rbgtoi(r, g, b))

"""
   function setmode(client::AuraControlClient, mode::Integer)

Set the mode of the controller to 0 for auto mode, 1 for software controlled.
Return true on success
"""
function setmode(client::AuraControlClient, mode)
    0 <= mode <= 1 || return false
    try
        send(client.sock, "setmode $mode")
        message = recv(client.sock, String)
        return message[1:2] == "OK"
    catch y
        @warn("Error setting mode")
        return false
    end
end

function sendexit(client::AuraControlClient)
    try
        send(client.sock, "exit")
        message = recv(client.sock, String)
        if message[1:2] == "OK"
            @info("Sent exit command to server, terminating socket")
            close(client.sock)
            return true
        end
    catch y
        @warn("Error sending exit command to server")
        return false
    end
end

end # module
