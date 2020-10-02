using AuraLighting
using Test

lighting = AuraMb()

@test lighting isa AuraMbControl

const n = [0x707070, 0x3]
while true
    println("set to $(n[1])")
    setcolor(aur, n[1] & 0xffffff)
    sleep(0.2)
    n[1] += 0x25 >> mod(n[2], 3) * 8
    n[2] += 1
end
