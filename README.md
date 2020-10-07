# AuraLighting.jl

## Julia Aura Lighting interface for PC hardware using the ASUS AURA SDK.

## Usage Notes

## Server mode or direct hardware interaction mode.

You need to run the main process (for directly interacting with the Aura lighting hardware):

1.    As a 32-bit process under Windows: see Julia Windows 32-bit download at [Download-Win32](https://julialang.org/downloads/)
             
2.    In adminstrator privilege mode under Windows ("Run as administrator")

This is because the Aura SDK itself, as provided by ASUStek, is a 32-bit DLL.

## Client mode using the ZMQ.jl functions.

Client interaction with the 32-bit Aura hardware server can be run with any Julia process, 32 or 64 bit.
 
The OS may be any Julia capable of running ZMQ, and need not be on the same machine.

Note that the AURA_SDK dll is a bit glitchy, especially when the hardware is slow to respond. Turning off 
garbage collection seems to allow Julia to mostly ignore some AURA_SDK.dll based memory errors. YMMV.


### Example:

### 32-bit server:

    GC.enable(false)  # DLL glitch workaround

    aur = AuraMbControl(1, 5555)
    startservice(aur)
    
    while true sleep(0.5); end  # only use if not running in REPL


### 64-bit client:

    client = AuraControlClient(5555, "localhost", 1)

    println("Client request yellow")
    setcolor(client, 0xff00ff)
    sleep(0.5)

    r, b, g = getcolor(client)
    println("Color is now RBG red = $r, blue = $b, green = $g")

