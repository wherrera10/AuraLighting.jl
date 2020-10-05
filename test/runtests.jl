using AuraLighting
using Test, Random

if sizeof(C_NULL) == 4 # 32-bit mode can use the 32-bit DLL AURA_SDK.dll

    GC.enable(false)

    aur = AuraMbControl()
    @test aur isa AuraMbControl

    setmode(aur, 1)
    sleep(0.5)

    println("white")
    setcolor(aur, 0xff, 0xff, 0xff)
    sleep(0.8)
    r, b, g = AuraLighting.getcolor(aur)
    @test r == 0xff
    @test b == 0xff
    @test g == 0xff

    println("black")
    setcolor(aur, 0x0, 0x0, 0x0)
    sleep(0.8)
    r, b, g = AuraLighting.getcolor(aur)
    @test r == 0
    @test b == 0
    @test g == 0

    println("red")
    setcolor(aur, 0xff, 0x0, 0x0)
    sleep(0.8)
    r, b, g = AuraLighting.getcolor(aur)
    @test r == 0xff
    @test b == 0
    @test g == 0

    println("blue")
    setcolor(aur, 0x0, 0xff, 0x0)
    sleep(0.8)
    r, b, g = getcolor(aur)
    @test r == 0
    @test b == 0xff
    @test g == 0

    println("green")
    setcolor(aur, 0x0, 0x0, 0xff)
    sleep(0.8)
    r, b, g = getcolor(aur)
    @test r == 0
    @test b == 0
    @test g == 0xff

    picks = collect(0x0:0xff)
    for i in 1:5
        sleep(0.8)
        c = view(shuffle!(picks),1:3)
        n = UInt(rbgtoi(c[1], c[2], c[3]))
        println("Set color to $n")
        setcolor(aur, n)
        sleep(0.8)
        r2, g2, b2 = getcolor(aur)
        @test rbgtoi(c[1], c[2], c[3]) == n
    end

    startserver(aur)
    @info("Service started. You may test a 64-bit session for 30 seconds now. Waiting...")
    sleep(30)
    @info("Service will terminate in 5 seconds.")

    cli = AuraMBControlClient(1)
    @test cli isa AuraMBControlClient
    @test iscorrectcontroller(cli)

    println("Client request yellow")
    setcolor(cli, 0xff00ff)
    sleep(3)
    r, g, b = getcolor(cli)
    @test r == 0xff
    @test g == 0x0
    @test b == 0xff

    sleep(1)
    setmode(aur, 0)

elseif sizeof(C_NULL) == 8  # 64-bit mode

    client = AuraMBControlClient()
    @test client isa AuraMBControlClient
    @test iscorrectcontroller(client)

    println("Client request yellow")
    setcolor(client, 0xff00ff)
    sleep(3)
    r, g, b = getcolor(client)
    @test r == 0xff
    @test g == 0x0
    @test b == 0xff

end
