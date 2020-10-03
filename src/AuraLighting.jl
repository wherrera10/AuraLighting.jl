module AuraLighting

using ZMQ

export AuraMbControl, AuraMBControlClient, getcolor, setcolor, setautomode

const Handle = Ptr{Nothing}
const Hptr = Ptr{Handle}
const Bptr = Ptr{UInt8}

"""
NOTE: THIS DLL FILE MUST BE LOCATED EITHER IN THE DIRECTORY WHERE PROGRAM IS RUN,
OR PLACE A COPY IN DIRECTORY IN YOUR PATH.
"""
const DLLNAME = "AURA_SDK.dll"

"""
    struct AuraMbControl

Aura SDK compatible motherboard

controllernumber: light controller(s) on board, between 1 and number of controllers.
LEDcount: generally, number of LED's controlled, but may be 1 in some cases

NOTE: THIS IS LINKED TO A WIN32 DLL, SO IT CANNOT BE RUN IN 64-BIT MODE.
MUST BE INSTANTIATED UNDER 32-BIT WINDOWS JULIA AND RUN AS AN ADMINISTRATOR.
MAKE SURE OTHER AURA LIGHTING APPLICATIONS ARE NOT RUNNING BEFORE RUNNING THIS.
"""
struct AuraMbControl
    controllernumber::Int
    LEDcount::Int
    handle::Handle
    colorbuf::Vector{UInt8}
    buflen::Int
    rep::ZMQ.Socket
    req::ZMQ.Socket
    port::Int
    client::String
    """
        function AuraMbControl(cont=1; asservice=false, port=5555, client="localhost")

    Constructor for an AuraMBControl.

    cont: controller number, defaults to 1 (first or only controller found)
    isservice: true if the ZMQ service is to be started
    port: port number of ZMQ service, defaults to 5555
    client: address of ZMQ client, defaults to "localhost"
    """
    function AuraMbControl(cont=1; isservice=false, port=5555, client="localhost")
        handlecount = ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr,), C_NULL)
        handlecount < cont && error("Motherboard Aura controller number $cont is not available.")
        handles = fill(C_NULL, handlecount)
        ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr,), pointer(handles))
        handle = handles[cont]
        LEDcount = ccall((:GetMbLedCount, DLLNAME), Cint, (Handle,), handle)
        buflen = ccall((:GetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint), handle, C_NULL, 3)
        colorbuf = fill(0x0, buflen)
        ccall((:GetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint), handle, colorbuf, 3)  # buflen
        rep = ZMQ.Socket(REP)
        req = ZMQ.Socket(REQ)
        obj = new(cont, LEDcount, handle, colorbuf, buflen, rep, req, port, client)
        if isservice
           @async ZMQservice(obj)
        end
       return finalizer(obj -> (close(obj.rep); close(obj.req)), obj)
    end
end

"""
   function setmode(au::AuraMbControl, setting::Integer=0)

Set mode of motherboard Aura controller from software control to an auto mode

A setting of 0 will change to the auto mode. A setting of 1 is software control.
"""
function setmode(au::AuraMbControl, setting::Integer)
    0 <= setting <= 1 || return
    ccall((:SetMbMode, DLLNAME), Cint, (Handle, Cint), au.handle, setting)
end

"""
    function getcolor(auramb::AuraMbControl)

Get RGB color as a tuple of red, green, and blue values (0 to 255 each).
"""
function getcolor(auramb::AuraMbControl)
    ccall((:GetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint),
        auramb.handle, pointer(auramb.colorbuf), 3)
    return auramb.colorbuf[1], auramb.colorbuf[2], auramb.colorbuf[3]
end

"""
    function setcolor(au::AuraMbControl, red, green, blue)

Set RGB color via setting color with separate red, green, and blue values
"""
function setcolor(au::AuraMbControl, red, green, blue)
    for i in 1:3:au.buflen
        au.colorbuf[i], au.colorbuf[i+1], au.colorbuf[i+2] = red, green, blue
    end
    success = ccall((:SetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint),
        au.handle, pointer(au.colorbuf), au.buflen)
    success == 1 || error("Failed to set Aura motherboard color")
end

"""
    function setcolor(au::AuraMbControl, rgb::Integer)

Set color of the LED light as an integer in 24-bit RGB format.
The color is of form hex 0xRRGGBB, where RR is the red component, GG green,
    and BB the blue values of an 24-bit RGB coded color.
Black is 0, white is 0x00ffffff, red 0xff0000, green 0x00ff00, blue 0x0000ff
"""
function setcolor(au::AuraMbControl, rgb::Integer)
    r, g, b = UInt8((rgb >> 16) & 0xff), UInt8((rgb >> 8) & 0xff), UInt8(rgb & 0xff)
    setcolor(au, r, g, b)
end

"""
    function ZMQservice(au::AuraMbLighting)

Serve requests via ZMQ to control the Aura lighting controller on the motherboard.
This must be run in 32-bit Windows mode with admin privileges.
"""
function ZMQservice(au:: AuraMbControl)
    try
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
struct AuraMBControlClient
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
