module AuraLighting

using ZMQ

export AuraMbControl, AuraMBControlClient, getcolor, setcolor, setmode

const Handle = Ptr{Nothing}
const Hptr = Ptr{Ptr{Nothing}}
const Bptr = Ptr{UInt8}

"""
NOTE: THIS DLL FILE MUST BE EITHER BE LOCATED IN THE DIRECTORY WHERE PROGRAM IS RUN,
OR ELSE YOU SHOULD PLACE A COPY IN A DIRECTORY IN YOUR PATH.
"""
const DLLNAME = "AURA_SDK.dll"

mutable struct AuraMbControl
    controllernumber::Int
    LEDcount::Int
    handle::Handle
    colorbuf::Vector{UInt8}
    buflen::Int
    port::Int
    client::String
    """
        function AuraMbControl(cont=1; asservice=false, port=5555, client="localhost")
    Constructor for an AuraMBControl.
    cont: controller number, defaults to 1 (first or only controller found)
    port: port number of ZMQ service, defaults to 5555
    client: address of ZMQ client, defaults to "localhost"
    """
    function AuraMbControl(cont=1, port=5555, client="localhost")
        Base.GC.enable(false)
        handlecount = ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr, Cint), C_NULL, 0)
        handles = [C_NULL for _ in 1:handlecount]
        ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr, Cint), handles, handlecount)
        handle = handles[cont]
        LEDcount = ccall((:GetMbLedCount, DLLNAME), Cint, (Handle,), handle)
        buflen = LEDcount * 3
        colorbuf = zeros(UInt8, buflen)
        return new(cont, LEDcount, handle, colorbuf, buflen, port, client)
    end
end

function startserver(au)
    @async begin ZMQservice(au) end
end

"""
   function setmode(au::AuraMbControl, setting::Integer=0)

Set mode of motherboard Aura controller from software control to an auto mode

A setting of 0 will change to the auto mode. A setting of 1 is software control.
"""
function setmode(au, setting::Integer)
    GC.enable(false)
    0 <= setting <= 1 || return
    ccall((:SetMbMode, DLLNAME), Cint, (Handle, Cint), au.handle, setting)
end

"""
    function getcolor(auramb::AuraMbControl)

Get RGB color as a tuple of red, green, and blue values (0 to 255 each).
"""
function getcolor(au)
    Base.GC.@preserve au.colorbuf
    for i in 1:au.buflen
        au.colorbuf[i] = 0x0
    end
    ccall((:GetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint),
        au.handle, au.colorbuf, au.buflen)
    return Int(au.colorbuf[1]), Int(au.colorbuf[2]), Int(au.colorbuf[3])
end

"""
    function setcolor(au::AuraMbControl, red, green, blue)

Set RGB color via setting color with separate red, green, and blue values
"""
function setcolor(au, red, green, blue)
    Base.GC.@preserve au.colorbuf
    for i in 1:3:au.buflen-1
        au.colorbuf[i], au.colorbuf[i+1], au.colorbuf[i+2] = red, green, blue
    end
    success = ccall((:SetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint),
        au.handle, au.colorbuf, au.buflen)
    return success == 1
end

"""
    function setcolor(au::AuraMbControl, rgb::Integer)

Set color of the LED light as an integer in 24-bit RGB format.
The color is of form hex 0xRRGGBB, where RR is the red component, GG green,
    and BB the blue values of an 24-bit RGB coded color.
Black is 0, white is 0x00ffffff, red 0xff0000, green 0x00ff00, blue 0x0000ff
"""
function setcolor(au, rgb::Integer)
    r, g, b = UInt8((rgb >> 16) & 0xff), UInt8((rgb >> 8) & 0xff), UInt8(rgb & 0xff)
    setcolor(au, r, g, b)
end

"""
    function ZMQservice(au::AuraMbLighting)

Serve requests via ZMQ to control the Aura lighting controller on the motherboard.
This must be run in 32-bit Windows mode with admin privileges.
"""
function ZMQservice(au::AuraMbControl)
    try
        rep = ZMQ.Socket(REP)
        req = ZMQ.Socket(REQ)
        bind(au.rep, "tcp://*:$(au.port)")
        connect(au.req, "tcp://$(au.client):$(au.port)")
        while true
            message = recv(au.rep, String)
            cmd = message * " 0 0 "
            words = split(cmd, r"\s+")
            if words[1] == "getcolor"
                r, g, b = getcolor(au)
                send(au.req, "OK $(r << 16) | (g << 8) | b)")
            elseif words[1] == "setcolor" && (c = tryparse(Int, words[2])) != nothing
                setcolor(au, c)
                send(au.req, "OK")
            elseif words[1] == "setmode" && (n = tryparse(Int, words[2])) != nothing
                setmode(au, n)
                send(au.req, "OK")
            elseif words[1] == "getcontroller"
                send(au.req, "OK $(au.controllernumber)")
            else
                warn("Unknown command received: $message")
                send(au.req, "ERROR in message received: $message")
            end
        end
        close(rep)
        close(req)
    catch y
        warn("ZMQ server fatal error: $y with message $message")
        send(au.req, "ERROR service ending exception $y")
    end
end

"""
    struct AuraMBControlClient

Client for a service to change Aura lighting via the 32-bit Win32 Aura lighting SDK.

This client can be any application and can be 64-bit even though the server must be
32-bit because ASUStek only provided a 32-bit DLL for Windows in its AuraSDK library.
"""
mutable struct AuraMBControlClient
    controllernumber::Int
    rep::ZMQ.Socket
    req::ZMQ.Socket
    port::Int
    client::String
    function AuraMBControlClient(controller=1; port=5555, server="localhost")
        rep = ZMQ.Socket(REP)
        req = ZMQ.Socket(REQ)
        bind(rep, "tcp://*:$(port)")
        connect(req, "tcp://$(client):$(port)")
        obj = new(controller, rep, req, port, client)
        return finalizer(obj -> (close(obj.rep); close(obj.req)), obj)
    end
end

"""
    function iscorrectcontroller(client::AuraMBControlClient)

Check if the client's controller number matches the server's controller number.
It is not actually necessary these two match, but checking this may help avoid
sending commands to the wrong controller.
"""
function iscorrectcontroller(client::AuraMBControlClient)
    send(client.req, "getcontroller")
    try
        message = recv(client.rep, String)
        s = split(message, r"\s+")
        n = parse(Int, s[2])
        return n == client.controllernumber
    catch y
        warn("Controller check error $y")
        return false
    end
end

"""
    function getcolor(client::AuraMBControlClient)

Get Aura lighting color as a tuple of red, green, and blue.
"""
function getcolor(client::AuraMBControlClient)
    try
        send(client.req, "getcolor")
        message = recv(client.rep, String)
        s = split(message, r"\s+")
        c = parse(Int, s[2])
        return (c >> 16) & 0xff, (c >> 8) & 0xff, c & 0xff
    catch y
        warn("Error getting color: $y")
        return -1, -1, -1
    end
end

"""
    function setcolor(client::AuraMBControlClient, color::Integer)

Set Aura lighting color to an RGB integer of form 0xrrggbb.
Return: true on success, false on failure
"""
function setcolor(client::AuraMBControlClient, color::Int)
    try
        send(client.req, "setcolor $(color & 0xffffff)")
        message = recv(client.rep, String)
        return message[1:2] == "OK"
    catch y
        warn("Error setting color to $color: $y")
        return false
    end
end

"""
    function setcolor(client::AuraMBControlClient, r, g, b)

Set Aura lighting color to RGB color with components r red, g green, b blue.
Return: true on success, false on failure
"""
setcolor(client::AuraMBControlClient, r, g, b) = setcolor(client, (r << 16) | (g << 8) | b)

"""
   function setmode(client::AuraMBControlClient, mode::Integer)

Set the mode of the controller to 0 for auto mode, 1 for software controlled.
Return true on success
"""
function setmode(client::AuraMBControlClient, mode::Integer)
    0 <= mode <= 1 || return false
    try
        send(client.req, "setmode $mode")
        message = recv(client.rep, String)
        return message[1:2] == "OK"
    catch y
        warn("Error setting mode")
        return false
    end
end

end # module
