if sizeof(C_NULL) == 8

    @testset "64-bit client doing Client-server control" begin

        cli = AuraMBControlClient()
        @test cli isa AuraMBControlClient
        @test iscorrectcontroller(cli)

        println("Client request yellow")
        setcolor(cli, 0xff00ff)
        sleep(3)
        r, g, b = getcolor(cli)
        @test r == 0xff
        @test g == 0x0
        @test b == 0xff

        @test sendexit(aur)

    end #testset

end
