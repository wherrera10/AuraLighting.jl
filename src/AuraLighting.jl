module AuraLighting

using ZMQ

export AuraMbControl, AuraMBControlClient, getcolor, setcolor, setautomode

const Handle = Ptr{Nothing}
const Hptr = Ptr{Handle}
const Bptr = Ptr{UInt8}

const DLLNAME = "AURA_SDK.dll"

struct AuraMbControl   # Aura compatible motherboard
    controllernumber::Int  # 0 for first or default controller
    LEDcount::Int
    handle::Handle
    colorbuf::Vector{UInt8}
    buflen::Int
    rep::Socket
    req::Socket
    port::Int
    client::String
    function AuraMbControl(cont=1; asservice=false, port=5555, client="localhost")
        handlecount = ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr,), C_NULL)
        handlecount < cont && error("Motherboard Aura controller number $cont is not available.")
        handles = fill(C_NULL, handlecount)
        ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr,), pointer(handles))
        handle = handles[cont]
        LEDcount = ccall((:GetMbLedCount, DLLNAME), Cint, (Handle,), handle)
        buflen = ccall((:GetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint), handle, C_NULL, 3)
        colorbuf = fill(0x0, buflen)
        ccall((:GetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint), handle, colorbuf, 3)  # buflen
        rep = Socket(REP)
        req = Socket(REQ)
        obj = new(cont, LEDcount, handle, colorbuf, buflen, rep, req, port, client)
        if asservice
           @async ZMQservice(obj)
        end
       return finalizer(obj -> (close(obj.rep); close(obj.req)), obj)
    end
end

function setmode(au::AuraMbControl, setting::Integer=0)
    0 <= setting <= 1 || return
    ccall((:SetMbMode, DLLNAME), Cint, (Handle, Cint), au.handle, setting)
end

"""
Get RGB color as red, green, and blue values
"""
function getcolor(auramb::AuraMbControl)
    ccall((:GetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint),
        auramb.handle, pointer(auramb.colorbuf), 3)
    return auramb.colorbuf[1], auramb.colorbuf[2], auramb.colorbuf[3]
end

"""
Set RGB color as separate red, green, and blue values
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
Set color of the LED light as a 4-byte integer
The color is of form hex 0x00rrggbb, where rr id red, gg green,
    and bb the blue values of an RGB coded color
Black is 0, white is 0x00ffffff
"""
function setcolor(au::AuraMbControl, rgb::Integer)
    r, g, b = UInt8((rgb >> 16) & 0xff), UInt8((rgb >> 8) & 0xff), UInt8(rgb & 0xff)
    setcolor(au, r, g, b)
end

function ZMQservice(au::AuraMbLighting)
    try
        bind(rep, "tcp://*:$(au.port)")
        connect(req, "tcp://$(au.client):$(au.port)")
        while true
            message = recv(au.req, String)
            cmd = message * " 0 0 "
            words = split(cmd, r"\s+")
            if words[1] = "getcolor"
                r, g, b = getcolor(au)
                send(au.rep, "OK $(r << 16) | (g << 8) | b)")
            elseif words[1] = "setcolor" && (c = tryparse(Int, words[2]) != nothing
                setcolor(au, c)
                send(au.rep, "OK")
            elseif words[1] = "setmode"
                if (n = tryparse(Int, words[2]) != nothing
                setmode(au, n)
                send(au.rep, "OK")
            elseif words[1] = "getcontroller"
                send(au.rep, "OK $(au.controllernumber)")
            else
                warn("Unknown command received: $message")
                send(au.rep, "ERROR in message received: $message")
            end
        end
        catch y
            warn("ZMQ server fatal error: $y with message $message")
            send(au.rep, "ERROR service ending exception $y")
        end
    end
end

struct AuraMBControlClient
    controllernumber::Int
    rep::Socket
    req::Socket
    port::Int
    client::String
    function AuraMBControlClient(controller=1; port=5555, server="localhost)
        rep = Socket(REP)
        req = Socket(REQ)
        bind(rep, "tcp://*:$(port)")
        connect(req, "tcp://$(client):$(port)")
        obj = new(controller, rep, req, port, client)       
        return finalizer(obj -> (close(obj.rep); close(obj.req)), obj)
    end
end

function iscorrectcontroller(client::AuraMBControlClient)
    send(client.req, "getcontroller")
    try
        message = recv(client.req, String)
        s = split(message, r"\s+")
        n = parse(Int, s[2])
        return n == client.controllernumber
    catch y
        warn("Controller check error $y")
        return false
    end
end
function setcolor(client::AuraMBControlClient, color::Int)

end

function getcolor(client::AuraMBControlClient)

end

function setmode(client::AuraMBControlClient, mode::Integer)

end

end # of module
