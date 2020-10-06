using AuraLighting, Dates

"""
Demo of control of Aura motherboard lighting.

Changes lighting color sequentially to indicate by color
hour, minute, second, repeating the cycle every 5 seconds.
"""

"""
60 colors in RGB
"""
function make60colors()
    reds = [255, 242, 229, 216, 203, 190, 177, 164, 151, 138,
            126, 113, 100, 87, 74, 61, 48, 35, 21, 8,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 13, 26, 39, 52, 65, 78, 91, 104, 117,
            130, 143, 156, 169, 181, 194, 207, 220, 233, 246]

    greens = [0, 13, 26, 39, 52, 65, 78, 91, 104, 117,
              130, 143, 156, 169, 181, 194, 207, 220, 233, 246,
              255, 242, 229, 216, 203, 190, 177, 164, 151, 138,
              126, 113, 100, 87, 74, 61, 48, 35, 21, 8,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    blues = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 13, 26, 39, 52, 65, 78, 91, 104, 117,
             130, 143, 156, 169, 181, 194, 207, 220, 233, 246,
             255, 242, 229, 216, 203, 190, 177, 164, 151, 138,
             126, 113, 100, 87, 74, 61, 48, 35, 21, 8]

    colors = zeros(UInt32, 60)
    for idx in 1:60
        colors[idx] = UInt32(blues[idx] +
                             greens[idx] * 0x100 +
                             reds[idx] * 0x10000)
    end
    return colors
end


"""
24 colors in RGB
"""
function make24colors()
    reds = [255, 224, 192, 160, 128, 96, 64, 32,
            0, 0, 0, 0, 0, 0, 0, 0,
            32, 64, 96, 128, 160, 192, 224, 255]

    greens = [0, 32, 64, 96, 128, 160, 192, 224,
              255, 224, 192, 160, 128, 96, 64, 32,
              0, 0, 0, 0, 0, 0, 0, 0]

    blues = [0, 0, 0, 0, 0, 0, 0, 0,
             32, 64, 96, 128, 160, 192, 224, 255,
             224, 192, 160, 128, 96, 64, 32, 0]

    colors = zeros(UInt32, 24)
    for idx in 1:24
        colors[idx] = UInt32(blues[idx] +
                             greens[idx] * 0x100 +
                             reds[idx] * 0x10000)
    end
    return colors
end


"""
Return intervals for hours, minutes, seconds in 24h time
"""
function hrminsec_colors()
    hours = make24colors()
    minutes = make60colors()
    seconds = minutes
    return hours, minutes, seconds
end


"""
Time (the time now) is coded as colors
"""
function nowcolors(chrs, cmins, csecs)
    nowtime = now()
    hrs = Dates.hour(nowtime)
    mins = Dates.minute(nowtime)
    secs = Dates.second(nowtime)
    if secs > 59
        secs = 59
    end
    return chrs[hrs + 1], cmins[mins + 1], csecs[secs + 1]
end

const AURA = AuraMbControl()
const CHRS, CMINS, CSECS = hrminsec_colors()
const OFF = 0

setmode(AURA, 1)
for i in 1:40
    HOUR, MINUTE, SECOND = nowcolors(CHRS, CMINS, CSECS)
    setcolor(AURA, HOUR)
    sleep(1.5)
    setcolor(AURA, MINUTE)
    sleep(1.5)
    setcolor(AURA, SECOND)
    sleep(0.75)
    setcolor(AURA, OFF)
    sleep(0.75)
end

println("Exiting")

setmode(AURA, 0)  # set hardware back to auto mode
