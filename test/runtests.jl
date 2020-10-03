using AuraLighting
using Test

@testset "Direct control" begin

    aur = AuraMbControl()
    @test aur isa AuraMbControl

    setmode(aur, 1)

    println("white")
    setcolor(aur, 0xff, 0xff, 0xff)
    sleep(0.5)
    r, g, b = AuraLighting.getcolor(aur)
    @test r == 0xff
    @test g == 0xff
    @test b == 0xff

    println("black")
    setcolor(aur, 0x0, 0x0, 0x0)
    sleep(0.1)
    r, g, b = AuraLighting.getcolor(aur)
    @test r == 0
    @test g == 0
    @test b == 0

    setcolor(aur, 0xff, 0x0, 0x0)
    sleep(0.1)
    r, g, b = AuraLighting.getcolor(aur)
    @test r == 0xff
    @test g == 0
    @test b == 0

    setcolor(aur, 0x0, 0xff, 0x0)
    sleep(0.1)

    r, g, b = getcolor(aur)
    @test r == 0
    @test g == 0xff
    @test b == 0

    setcolor(aur, 0x0, 0x0, 0xff)
    sleep(0.1)

    r, g, b = getcolor(aur)
    @test r == 0
    @test g == 0
    @test b == 0xff

    n = 0xffffff
    ar, ag, ab = collect(0:255), collect(0:255), collect(0:255)
    for i in 1:10
        n &= 0xffffff
        println("Set color to $n")
        setcolor(aur, n)
        sleep(0.2)
        r, g, b = getcolor(aur)
        @test (r << 16) | (g << 8) | b == n
        r, g, b = rand(ar), rand(ag), rand(ab)
        n = (r << 16) | (g << 8) | b
    end

end #testset

@testset "Client-server control" begin

    aur = AuraMbControl()
    @test aur isa AuraMbControl


    @test 1 == 1

end #testset

@testset "Restore to auto mode" begin

    aur = AuraMbControl()
    @test aur isa AuraMbControl

    setmode(aur, 0)

end #testset

