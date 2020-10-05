module AuraLighting

using ZMQ

export AuraMbControl, AuraMBControlClient, getcolor, setcolor, setmode
export rbgtoi, itorbg, startserver, iscorrectcontroller, sendexit

const Handle = Ptr{Cvoid}
const Hptr = Ptr{Ptr{Cvoid}}
const Bptr = Ptr{UInt8}

"""
IMPORTANT FOR 0MQ SERVER MODE:  MUST BE WINDOWS 32-BIT JULIA IN ADMIN PRIVILEGE MODE
NOTE: THIS DLL FILE MUST BE EITHER BE LOCATED IN THE DIRECTORY WHERE PROGRAM IS RUN,
OR ELSE YOU SHOULD PLACE A COPY IN A DIRECTORY IN YOUR PATH.

The client may 64-bit or 32-bit and may have only user mode privileges.
"""
const DLLNAME = "AURA_SDK.dll"

""" rgb integer to UInt8 (r, g, b) """
itorbg(i) = [UInt8((i >> 16) & 0xff), UInt8((i >> 8) & 0xff), UInt8(i & 0xff)]

""" UInt8 (r, g, b) to rgb integer """
rbgtoi(r, g, b) = ((UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)) & 0xffffff

mutable struct AuraMbControl
    controllernumber::Int
    LEDcount::Int
    handle::Handle
    colorbuf::Vector{UInt8}
    buflen::Int
    port::Int
    client::String
    AuraMbControl(c, n, h, p, a) = new(c, n, h, zeros(UInt, n * 3), n * 3, p, a)
end

"""
    function AuraMbControl(cont=1; asservice=false, port=5555, client="localhost")
Constructor for an AuraMBControl.
cont: controller number, defaults to 1 (first or only controller found)
port: port number of ZMQ service, defaults to 5555
client: address of ZMQ client, defaults to "localhost"
"""
function AuraMbControl(cont=1, port=5555, client="localhost")
    GC.enable(false)
    hcount = ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr, Cint), C_NULL, 0)
    handles = [C_NULL for _ in 1:hcount]
    LEDcount = 1
    GC.@preserve handles begin
        ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr, Cint), handles, hcount)
    end
    handle = handles[min(cont, hcount)]
    LEDcount = ccall((:GetMbLedCount, DLLNAME), Cint, (Handle,), handle)
    return AuraMbControl(cont, LEDcount, handle, port, client)
end

function startserver(au)
    @async begin ZMQservice(au) end
end

"""
   function setmode(au::AuraMbControl, setting::Integer=0)

Set mode of motherboard Aura controller from software control to an auto mode

A setting of 0 will change to the auto mode. A setting of 1 is software control.
"""
function setmode(au::AuraMbControl, setting::Integer)
    0 <= setting <= 1 || return false
    return ccall((:SetMbMode, DLLNAME), Cint, (Handle, Cint), au.handle, setting)
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
    end
    return Int(au.colorbuf[1]), Int(au.colorbuf[2]), Int(au.colorbuf[3])
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
    end
    return success == 1
end

"""
    function setcolor(au::AuraMbControl, rgb::Integer)

Set color of the LED light as an integer in 24-bit RGB format.
The color is of form hex 0xRRGGBB, where RR is the red component, GG green,
    and BB the blue values of an 24-bit RGB coded color.
Black is 0, white is 0x00ffffff, red 0xff0000, green 0x00ff00, blue 0x0000ff
"""
function setcolor(au::AuraMbControl, rgb)
    r, g, b = itorbg(rgb)
    setcolor(au, r, g, b)
end

"""
    function ZMQservice(au::AuraMbLighting)

Serve requests via ZMQ to control the Aura lighting controller on the motherboard.
This must be run in 32-bit Windows mode with admin privileges.
"""
function ZMQservice(au::AuraMbControl)
    sock = Socket(REP)
    bind(sock, "tcp://*:$(au.port)")
    try
        while true
            message = recv(sock, String)
            cmd = message * " 0 0 "
            words = split(cmd, r"\s+")
            if words[1] == "getcolor"
                r, g, b = getcolor(au)
                send(sock, "OK $(rbgtoi(r, g, b))")
            elseif words[1] == "setcolor" && (c = tryparse(Int, words[2])) != nothing
                setcolor(au, c)
                send(sock, "OK")
            elseif words[1] == "setmode" && (n = tryparse(Int, words[2])) != nothing
                setmode(au, n)
                send(sock, "OK")
            elseif words[1] == "getcontroller"
                send(sock, "OK $(au.controllernumber)")
            elseif words[1] == "exit"
                send(sock, "OK")
                break
            else
                @warn("Unknown command received: $message")
                send(sock, "ERROR in message received: $message")
            end
        end
    catch y
        warn("ZMQ server fatal error: $y with message $message")
    finally
        close(sock)
    end
end

"""
    struct AuraMBControlClient

Client for a service to change Aura lighting via the 32-bit Win32 Aura lighting SDK.

This client can be any application and can be 64-bit even though the server must be
32-bit because ASUStek only provided a 32-bit DLL for Windows in its AuraSDK library.
"""
struct AuraMBControlClient
    sock::Socket
    controllernumber::Int
    function AuraMBControlClient(cont=1, port=5555, server="localhost")
        sock = Socket(REQ)
        connect(sock, "tcp://$server:$port")
        new(sock, cont)
    end
end

"""
    function iscorrectcontroller(client::AuraMBControlClient)

Check if the client's controller number matches the server's controller number.
It is not actually necessary these two match, but checking this may help avoid
sending commands to the wrong controller.
"""
function iscorrectcontroller(client::AuraMBControlClient)
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
function getcolor(client::AuraMBControlClient)
    try
        send(client.sock, "getcolor")
        message = ZMQ.recv(client.sock, String)
        s = split(message, r"\s+")
        c = parse(Int, s[2])
        return Tuple(itorbg(c))
    catch y
        @warn("Error getting color: $y")
        return (0, 0, 0)
    end
end

"""
    function setcolor(client::AuraMBControlClient, color::Integer)

Set Aura lighting color to an RGB integer of form 0xrrggbb.
Return: true on success, false on failure
"""
function setcolor(client::AuraMBControlClient, color)
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
    function setcolor(client::AuraMBControlClient, r, g, b)

Set Aura lighting color to RGB color with components r red, g green, b blue.
Return: true on success, false on failure
"""
setcolor(client::AuraMBControlClient, r, g, b) = setcolor(client, rbgtoi(r, g, b))

"""
   function setmode(client::AuraMBControlClient, mode::Integer)

Set the mode of the controller to 0 for auto mode, 1 for software controlled.
Return true on success
"""
function setmode(client::AuraMBControlClient, mode)
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

function sendexit(client::AuraMBControlClient)
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
