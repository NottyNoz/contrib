﻿-- This file is subject to copyright - contact swampservers@gmail.com for more information.
include('shared.lua')
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Instructions = "Primary: Eat Popcorn\nSecondary: Throw Bucket"
local emitter = ParticleEmitter(Vector(0, 0, 0))

function SWEP:GetViewModelPosition(pos, ang)
    pos, ang = LocalToWorld(Vector(20, -10, -15), Angle(0, 0, 0), pos, ang)

    return pos, ang
end

local function kernel_init(particle, vel)
    particle:SetColor(255, 255, 255, 255)
    particle:SetVelocity(vel or VectorRand():GetNormalized() * 15)
    particle:SetGravity(Vector(0, 0, -200))
    particle:SetLifeTime(0)
    particle:SetDieTime(math.Rand(5, 10))
    particle:SetStartSize(1)
    particle:SetEndSize(0)
    particle:SetStartAlpha(255)
    particle:SetEndAlpha(0)
    particle:SetCollide(true)
    particle:SetBounce(0.25)
    particle:SetRoll(math.pi * math.Rand(0, 1))
    particle:SetRollDelta(math.pi * math.Rand(-4, 4))
end

function SWEP:DrawWorldModel()
    local ply = self:GetOwner()

    if IsValid(ply) then
        local bp, ba = ply:GetBonePosition(ply:LookupBone(ply:IsPony() and "LrigScull" or "ValveBiped.Bip01_R_Hand") or 0)
        local pos, ang

        if bp then
            pos, ang = bp, ba
        else
            pos, ang = self:GetPos(), self:GetAngles()
        end

        if ply:IsPony() then
            ang:RotateAroundAxis(ang:Forward(), -90)
            pos = pos + ang:Up() * 10 + ang:Right() * -1 + ang:Forward() * 7
        else
            ang:RotateAroundAxis(ang:Forward(), 30)
            pos = pos + ang:Right() * 7 + ang:Up() * 3 + ang:Forward() * -4
        end

        self:SetupBones()
        local mrt = self:GetBoneMatrix(0)

        if mrt then
            mrt:SetTranslation(pos)
            mrt:SetAngles(ang)
            mrt:SetScale(Vector(0.8, 0.8, 0.8))
            self:SetBoneMatrix(0, mrt)
        end
    end

    self:DrawModel()
end

net.Receive("Popcorn_Eat", function()
    local ply = net.ReadEntity()
    if not IsValid(ply) then return end
    local size = net.ReadFloat()
    local attachid = ply:LookupAttachment("eyes")
    emitter:SetPos(Me:GetPos())

    local angpos = ply:GetAttachment(attachid) or {
        ["Pos"] = ply:EyePos(),
        ["Ang"] = Angle(0, 0, 0)
    }

    local fwd
    local pos

    if ply ~= Me then
        fwd = (angpos.Ang:Forward() - angpos.Ang:Up()):GetNormalized()
        pos = angpos.Pos + fwd * 3
    else
        fwd = ply:GetAimVector():GetNormalized()
        pos = ply:GetShootPos() + gui.ScreenToVector(ScrW() / 2, ScrH() / 4 * 3) * 10
    end

    for i = 1, size do
        if not IsValid(ply) then return end
        local particle = emitter:Add("particle/popcorn-kernel", pos)

        if particle then
            local dir = VectorRand():GetNormalized()
            kernel_init(particle, (fwd + dir):GetNormalized() * math.Rand(0, 40))
        end
    end
end)

net.Receive("Popcorn_Eat_Start", function()
    local ply = net.ReadEntity()
    ply.ChewScale = 1
    ply.ChewStart = CurTime()
    ply.ChewDur = SoundDuration("crisps/eat.wav")
end)
