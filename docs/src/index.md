# AuraLighting.jl

<img src="https://github.com/wherrera10/AuraLighting.jl/blob/master/docs/src/aur.png">

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
<br /><br />

### Example:

### 32-bit server:

    GC.enable(false)  # DLL glitch workaround

    aur = AuraMbControl(1, 5555)
    startservice(aur)
    
    while true sleep(0.5); end  # only use if not running in REPL
<br /><br />

### 64-bit client:

    client = AuraControlClient(5555, "localhost", 1)

    println("Client request yellow")
    setcolor(client, 0xff00ff)
    sleep(0.5)

    r, b, g = getcolor(client)
    println("Color is now RBG red = $r, blue = $b, green = $g")
<br /><br /><br />



## Functions

    itorbg(i) 

Change rgb integer to a vector length 3 of UInt8 (red, green, blue)
<br /><br />

    rbgtoi(r, g, b)

Convert array of UInt8 of length 3 (r, g, b) to rgb integer.
<br /><br />

    struct AuraMbControl <: AuraControl
        controllernumber::Int
        LEDcount::Int
        handle::Handle
        colorbuf::Vector{UInt8}
        buflen::Int
        port::Int
        AuraMbControl(c, n, h, p) = new(c, n, h, zeros(UInt, n * 3), n * 3, p)
    end

Represents an Aura enabled motherboard hardware item for color control usage.
<br /><br />


    function AuraMbControl(cont=1; asservice=false, port=5555)

Constructor for an AuraMBControl.
cont: controller number, defaults to 1 (first or only controller found)
port: port number of ZMQ service, defaults to 5555
<br /><br />


    struct AuraGPUControl <: AuraControl
        controllernumber::Int
        LEDcount::Int
        handle::Handle
        colorbuf::Vector{UInt8}
        buflen::Int
        port::Int
        AuraGPUControl(c, n, h, p) = new(c, n, h, zeros(UInt, n * 3), n * 3, p)
    end

Represents an Aura enabled GPU hardware item for color control usage.
<br /><br />


    function AuraGPUControl(cont=1, port=5556)

Constructor for an AuraGPUControl.
cont: controller number, defaults to 1 (first or only controller found)
port: port number of ZMQ service, defaults to 5556
<br /><br />

	struct AuraKeyboardControl <: AuraControl
	    LEDcount::Int
	    handle::Handle
	    colorbuf::Vector{UInt8}
	    buflen::Int
	    port::Int
	    AuraKeyboardControl(n, h, p) = new(n, h, zeros(UInt, n * 3), n * 3, p)
	end

Represents an Aura enabled keyboard hardware item for color control usage.
<br /><br />


    function AuraKeyboardControl(cont=1; asservice=false, port=5557)

Constructor for an AuraKeyboardControl.
port: port number of ZMQ service, defaults to 5557
<br /><br />


	struct AuraMouseControl <: AuraControl
	    LEDcount::Int
	    handle::Handle
	    colorbuf::Vector{UInt8}
	    buflen::Int
	    port::Int
	    AuraMouseControl(n, h, p) = new(n, h, zeros(UInt, n * 3), n * 3, p)
	end

Represents an Aura enabled mouse hardware item for color control usage.


    function AuraMouseControl(cont=1; asservice=false, port=5558)

Constructor for an AuraMouseControl.
port: port number of ZMQ service, defaults to 5558
<br /><br />


    function startserver(au::AuraControl)
    
Start AuraControl service on previously specified AuraControl object's port.    
<br /><br />


    controllernumber(au::AuraMbControl)

Get the number of the hardware control for when there is mre than one Aura
controller on the hardware. Usually only motherboard and GPU have such a setup.
For other hardware this is always 1.
<br /><br />


   function setmode(au::AuraMbControl, setting::Integer=0)

Set mode of motherboard Aura controller from software control to an auto mode
A setting of 0 will change to the auto mode. A setting of 1 is software control.
<br /><br />


    function setmode(au::AuraGPUControl, setting::Integer)

Set mode of GPU Aura controller from software control to an auto mode
A setting of 0 will change to the auto mode. A setting of 1 is software control.
<br /><br />


    function setmode(au::AuraKeyboardControl, setting::Integer)

Set mode of keyboard Aura controller from software control to an auto mode
A setting of 0 will change to the auto mode. A setting of 1 is software control.
<br /><br />


    function setmode(au::AuraMouseControl, setting::Integer)

Set mode of mouse Aura controller from software control to an auto mode
A setting of 0 will change to the auto mode. A setting of 1 is software control.
<br /><br />


    function getcolor(auramb::AuraMbControl)

Get RGB color as a tuple of red, green, and blue values (0 to 255 each).
As of 2021 """ only motherboards can get color, though all types can set color
<br /><br />


    function setcolor(au::AuraControl, red, green, blue)

Set RGB color via setting color with separate red, green, and blue values
<br /><br />


    function setcolor(au::AuraControl, rgb)

Set RGB color as a 64-bit integer with color as 0x00rrggbb (highest 8 bits ignored).
See e.g. https://www.rapidtables.com/web/color/RGB_Color.html
<br /><br />


    function ZMQservice(au::AuraControl)

Serve requests via ZMQ to control the Aura lighting controller.
This must be run in 32-bit Windows mode with admin privileges.
<br /><br />


	struct AuraControlClient
	    sock::Socket
	    controllernumber::Int
	    function AuraControlClient(port=5555, server="localhost", cont=1)
	        sock = Socket(REQ)
	        connect(sock, "tcp://$server:$port")
	        new(sock, cont)
	    end
	end

Client for a service to change Aura lighting via the 32-bit Win32 Aura lighting SDK.
This client can be any application and can be 64-bit even though the server must be
32-bit because ASUStek only provided a 32-bit DLL for Windows in its AuraSDK library.
<br /><br />


    function iscorrectcontroller(client::AuraControlClient)

Check if the client's controller number matches the server's controller number.
It is not actually necessary these two match, but checking this may help avoid
sending commands to the wrong controller.
<br /><br />


    function getcolor(client::AuraMBControlClient)

Get Aura lighting color as a tuple of red, green, and blue.
<br /><br />


    function setcolor(client::AuraControlClient, color::Integer)

Set Aura lighting color to an RGB integer of form 0xrrggbb.
Return: true on success, false on failure
<br /><br />


    function setcolor(client::AuraControlClient, r, g, b)

Set Aura lighting color to RGB color with components r red, g green, b blue.
Return: true on success, false on failure
<br /><br />


   function setmode(client::AuraControlClient, mode::Integer)

Set the mode of the controller to 0 for auto mode, 1 for software controlled.
Return true on success
<br /><br />


    function sendexit(client::AuraControlClient)

Close down the server and exit the server thread.
<br /><br />


