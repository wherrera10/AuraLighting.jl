#=
Aura lighting (ASUS SDK) interface
Julia module to interface with the AURA lighting controller on certain PC motherboards
Created on Monday, 28 September 2020 at 2:35:34
author: William Herrera

IMPORTANT: run as administrator
=#

module AuraLighting

using ZMQ

export AuraMbControl, getcolor, setcolor, setautomode

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
end

function AuraMbControl(cont=1)
    handlecount = ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr,), C_NULL)
    handlecount < 1 && error("No motherboard Aura controllers available.")
    handles = fill(C_NULL, handlecount)
    ccall((:EnumerateMbController, DLLNAME), Cint, (Hptr,), pointer(handles))
    handle = handles[cont]
    LEDcount = ccall((:GetMbLedCount, DLLNAME), Cint, (Handle,), handle)
    buflen = ccall((:GetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint), handle, C_NULL, 3)
    colorbuf = fill(0x0, buflen)
    ccall((:GetMbColor, DLLNAME), Cint, (Handle, Bptr, Cint), handle, colorbuf, 3)  # buflen
 #   ccall((:SetMbMode, DLLNAME), Cint, (Handle, Cint), handle, 1)
    return AuraMbControl(cont, LEDcount, handle, colorbuf, buflen)
end


function setautomode(au::AuraMbControl; to_automatic=true)
    ccall((:SetMbMode, DLLNAME), Cint, (Handle, Cint), au.handle, to_automatic == 0)
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

mutable struct ZMQservice
    port::Int
    rep::Socket
    req::Socket
    controller::Int
    aura::Union{AuraMbControl, Nothing}
end

function ZMQserver(serv::ZMQservice)
    while true
        message = recv(serv.socket, String)
        isempty(message) && continue
        words = split(message, r"\s+", limit=2)
        words[1] = "quit" && break
        length(words) < 2 && push!(words, "")
        # call the function indexed in api Dict
        result = get(api, words[1], x -> send(rep, "Error $message"))(words[2])
    end
end

function ZMQservice(controller=1, port=5555)
    rep = Socket(REP)
    req = Socket(REQ)
    bind(rep, "tcp://*:$port")
    connect(req, "tcp://localhost:$port")
    serv = new(port, rep, req, controller, nothing)
    @async ZMQserver(serv)
    return finalizer(obj -> (close(obj.rep); close(obj.req)), serv)
end

function ZMQinit(z::ZMQservice, message::String)
    z.controller = something(tryparse(Int, message), 0)
    z.aura = AuraMbControl(controller)
    send(z.socket, "OK")
end

function ZMQgetcolor(z::ZMQservice, message::String)
    if z.aura == nothing
        send(rep, "Error Aura not initialized.")
    else
        r, g, b = getcolor(z.aura)
        send(rep, "OK $(r << 16) | (g << 8) | b)")
    end
end

function ZMQsetcolor(z::ZMQservice, message::String)
    if z.aura == nothing
        send("Error Aura not initialized.")
    else
        try
            c = parse(Int, message)
            setcolor(z.aura, c)
            send("OK")
        catch
            send(rep, "Error Cannot set color to $message")
        end
    end
end

const api = Dict("init" => ZMQinit, "getcolor" => ZMQgetcolor, "setcolor" => ZMQsetcolor)

end # of module
