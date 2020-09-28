#=
Aura lighting (ASUS SDK) interface
Julia module to interface with the AURA lighting controller on certain PC motherboards
Created on Monday, 28 September 2020 at 2:35:34
author: William Herrera

IMPORTANT: run as administrator
=#

module AuraLighting

export AuraMb, LEDColors, getcolor, setcolor

struct LEDColor
    r::UInt8   # red
    g::UInt8   # green
    b::UInt8   # blue
end

const black = LEDColor(0, 0, 0)
const red = LEDColor(255, 0, 0)
const green = LEDColor(0, 255, 0)
const blue = LEDColor(0, 0, 255)
const white = LEDColor(255, 255, 255)

function LEDColors(buf::Vector{UInt8})
    len = length(buf)
    @assert(len % 3 == 0)
    return [LEDColor(buf[i], buf[i+1], buf[i+2]) for i in 1:3:len-1]
end

asbuf(colors::Vector{LEDColor}) = mapreduce(c -> [c.r, c.g, c.b], vcat, colors)

const bufchar = UInt8
const AStr = Ptr{bufchar}
struct AuraHandle end
const APtr = Ptr{AuraHandle}

const DLLNAME = "AURA_SDK.dll"

struct AuraMb   # Aura compatible motherboard
    controllernumber::Int32  # 0 for first or default controller
    LEDcount::Int32  # note that length of colors should == 3 * LEDcount
    handles::Vector{APtr}
    colors::Vector{LEDColor}
    colorbuf::Vector{UInt8}
end

function AuraMb(controller=0)
    handlecount = ccall((:EnumerateMbController, DLLNAME), Cint, (APtr,), 0)
    handlecount == 0 && error("No motherboard Aura controllers available.")
    handles = fill(Ptr(AuraHandle()), handlecount)
    ccall((:EnumerateMbController, DLLNAME), Cint, (APtr,), handles)
    success = ccall((:SetMbMode, DLLNAME), Cint, (APtr, Cint), handles[controller], 1)
    success == 1 || error("Cannot set Aura mode on motherboard")
    bufsize =  ccall((:GetMbColor, DLLNAME), Cint, (APtr, Ptr{Cvoid}), handles[controller], 0)
    buf = fill(0x0, bufsize)
    ccall((:GetMbColor, DLLNAME), Cint, (APtr, AStr), handles[controller], buf)
    return AuraMb(controller, bufsize ÷ 3, handles, LEDColors(buf), buf)
end

"""
Get RGB color as an LEDColor struct containing red, green, and blue values
"""
function getcolor(auramb::AuraMb)
    ccall((:GetMbColor, DLLNAME), Cint, (APtr, AStr),
        auramb.handles[auramb.controllernumber], auramb.colorbuf)
    length(buf) >= 3 || error("Color buffer reading error")
    return LEDColor(buf[1], buf[2], buf[3])
end

"""
Set RGB color as separate red, green, and blue values
"""
function setcolor(auramb::AuraMb, red, green, blue, controller=0)
    for (i, c) in enumerate(colors)
        colors.r, colors.g, colors.b = red, green, blue
        colorbuf[3i-2], colorbuf[3i-1], colorbuf[3i] = red, green, blue
    end
    success = ccall((:SetMbColor, DLLNAME), Cint, (APtr, AStr, Cint),
        auramb.handles[auramb.controllernumber], auramb.colorbuf, length(auramb.colorbuf))
    success == 1 || error("Failed to set Aura motherboard color")
end

"""
Set color of the LED light as a 4-byte integer
The color is of form hex 0x00rrggbb, where rr id red, gg green,
    and bb the blue values of an RGB coded color
Black is 0, white is 0x00ffffff
"""
function setcolor(auramb::AuraMb, rgb, controller=0)
    r, g, b = UInt8(rbg >> 16), UInt8((rgb >> 8) && 0xff), UInt8(rgb & 0xff)
    setcolor(auramb, r, g, b, controller)
end

"""
Set color of the LED light as an LEDColor struct
"""
setcolor(amb, led::LEDColor, cont=0) = setcolor(amb, led.r, led.g, led.b, cont)


end # of module
