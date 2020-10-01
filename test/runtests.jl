using AuraLighting
using Test

lighting = AuraMb()

@test lighting isa AuraMb


while true
    setcolor(lighting, 0xffffff)
    sleep(0.2)
end

