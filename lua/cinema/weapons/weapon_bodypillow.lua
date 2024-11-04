﻿-- This file is subject to copyright - contact swampservers@gmail.com for more information.
AddCSLuaFile()

if CLIENT then
    CreateClientConVar("bodypillow_url", "", true, true)
    CreateClientConVar("bodypillow_imgur", "", true, true) -- NOTE(winter): Legacy ConVar; just here so we don't wipe out everyone's settings
end

DEFINE_BASECLASS("weapon_swamp_base")
SWEP.PrintName = "Body Pillow"
SWEP.Purpose = "Gives the feeling of companionship"
SWEP.Instructions = "Left click: boof\nRight click: drop\nReload: customize"
SWEP.Slot = 1
SWEP.SlotPos = 99
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.ViewModelFOV = 85
SWEP.ViewModel = Model("models/swamponions/bodypillow.mdl")
SWEP.WorldModel = Model("models/swamponions/bodypillow.mdl")
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.Damage = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Damage = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.AllowInVehicle = true

if SERVER then
    local weaponppl = {}

    hook.Add("Tick", "DisallowWeaponsInVehicle", function()
        local nxt = {}

        for owner, v in pairs(weaponppl) do
            if IsValid(owner) then
                if IsValid(owner:GetActiveWeapon()) and owner:GetActiveWeapon().AllowInVehicle then
                    nxt[owner] = true
                else
                    owner:SetAllowWeaponsInVehicle(false)
                end
            end
        end

        weaponppl = nxt
    end)

    function SWEP:Deploy()
        BaseClass.Deploy(self)
        local owner = self:GetOwner()
        owner:SetAllowWeaponsInVehicle(true)
        weaponppl[owner] = true
    end
end

function SWEP:GetHardened()
    -- return self:GetOwner():SteamID() == "STEAM_0:0:38422842"
    return self:GetNWBool("Hard", false)
end

function SWEP:TimeScale()
    -- return self:GetNWBool("Hard", false)
    -- self:GetHardened() and 1.5 or 1
    return 1
end

function bodypillow_unjiggle(self)
    if not self.Unjiggled then
        self:AddCallback("BuildBonePositions", function(e, nb)
            PILLOW_UNJIGGLE(e, nb)
        end)

        self.Unjiggled = true
    end
end

function PILLOW_UNJIGGLE(self, nb)
    pcall(function()
        --or (self.wep and not self.wep:GetHardened())
        if self:GetModel() ~= "models/swamponions/bodypillow.mdl" then return end --it got set on the viewmodel entity

        for i = 0, nb - 1 do
            local i2 = i < 3 and i or 2 - i
            local a = i == 0 and Angle(0, 0, 90) or (i < 3 and Angle() or Angle(0, 0, 180))
            local ro, ra = self:GetRenderOrigin(), self:GetRenderAngles()

            if self:GetClass() == "prop_trash_pillow" then
                ro, ra = self:GetPos(), self:GetAngles()
            end

            if not ro then
                if not IsValid(self.wep) or not IsValid(self.wep.Owner) then return end
                ro, ra = self.wep:GetViewModelPosition(self.wep.Owner:EyePos(), self.wep.Owner:EyeAngles())
            end

            self:SetBonePosition(i, LocalToWorld(Vector(0, 0, i2 * 10), a, ro, ra))
        end
    end)
end

function SWEP:DrawWorldModel()
    local owner = self:GetOwner()

    if IsValid(owner) then
        local bn = owner:IsPony() and "Lrig_LEG_FR_Humerus" or "ValveBiped.Bip01_R_Hand"
        local bon = owner:LookupBone(bn) or 0
        local opos = self:GetPos()
        local oang = self:GetAngles()
        local bp, ba = owner:GetBonePosition(bon)

        if bp then
            opos = bp
        end

        if ba then
            oang = ba
        end

        if owner:IsPony() then
            local pf = self:Boof()
            opos = opos + oang:Right() * (3 - pf * 7)
            opos = opos + oang:Forward() * -8
            opos = opos + oang:Up() * (8 - pf * 4)
            oang:RotateAroundAxis(oang:Forward(), -90 + pf * 120)
            oang:RotateAroundAxis(oang:Right(), 100)
            oang:RotateAroundAxis(oang:Forward(), 5 + pf * -30)
            oang:RotateAroundAxis(oang:Up(), self:GetNWBool('flip') and 0 or 180)
        else
            opos = opos + oang:Right() * -2
            opos = opos + oang:Forward() * 4
            opos = opos + oang:Up() * 2
            oang:RotateAroundAxis(oang:Forward(), 30)
            oang:RotateAroundAxis(oang:Right(), 170)
            oang:RotateAroundAxis(oang:Up(), 60 + (self:GetNWBool('flip') and 180 or 0))

            if owner:InVehicle() then
                oang:RotateAroundAxis(oang:Forward(), -30)
                oang:RotateAroundAxis(oang:Right(), -50)
                oang:RotateAroundAxis(oang:Up(), -40)
                opos = opos + oang:Forward() * 10
                oang:RotateAroundAxis(oang:Up(), -30)
                oang:RotateAroundAxis(oang:Forward(), 10)
                oang:RotateAroundAxis(oang:Right(), -10)
            end
        end

        self:SetRenderOrigin(opos)
        self:SetRenderAngles(oang)
    end

    self:SetupBones()
    local url, owner = self:GetWebMatInfo()

    if not url and self:GetHardened() then
        url = "i.imgur.com/cogLTj5.png" -- the default texture, hacky solution
    end

    if url then
        render.MaterialOverride(WebMaterial({
            url = url,
            owner = owner,
            pos = self:GetPos(),
            stretch = true,
            params = self:GetHardened() and HardenedPillowArgs(util.CRC((owner ~= "" and owner or (IsValid(owner) and owner:SteamID() or "")) .. url)) or nil,
            nsfw = "?"
        }))
    end

    if self:GetHardened() then
        bodypillow_unjiggle(self)
    end

    self:DrawModel()

    if url then
        render.MaterialOverride()
    end
end

function HardenedPillowArgs(hsh)
    return string.format([[{["$detail"]="decals/decalstain%03da",["$detailscale"]="1",["$detailblendfactor"]="2"}]], hsh % 15 + 1)
end

function SWEP:PreDrawViewModel(vm, owner, wep)
    self.PrintName = self:GetHardened() and "Body Pillow (Hardened)" or "Body Pillow"
    self.Purpose = self:GetHardened() and "Stands up on its own" or "Gives the feeling of companionship"
    local url, owner = self:GetWebMatInfo()

    if not url and self:GetHardened() then
        url = "i.imgur.com/cogLTj5.png" -- the default texture, hacky solution
    end

    if url then
        render.MaterialOverride(WebMaterial({
            url = url,
            owner = owner,
            pos = self:GetPos(),
            stretch = true,
            params = self:GetHardened() and HardenedPillowArgs(util.CRC((owner ~= "" and owner or (IsValid(owner) and owner:SteamID() or "")) .. url)) or nil,
            nsfw = "?"
        }))
    end

    if self:GetHardened() then
        vm.wep = self
        bodypillow_unjiggle(vm)
    end
end

function SWEP:PostDrawViewModel()
    render.MaterialOverride()
end

function SWEP:GetViewModelPosition(pos, ang)
    local owner = self:GetOwner()
    --local of,_ = LocalToWorld(owner:GetCurrentViewOffset(),Angle(0,0,0),Vector(0,0,0),ang)
    --pos = pos - (of*0.5)
    if not IsValid(owner) then return pos, ang end

    if owner:InVehicle() then
        local va = owner:GetVehicle():GetAngles()
        va:RotateAroundAxis(va:Up(), 90)
        ang = LerpAngle(0.5, va, ang)
    end

    pos = pos - owner:GetCurrentViewOffset() * 0.5
    local pf = self:Boof(true)
    local v = ang:Forward()

    if math.abs(v.z) == 1 then
        v = -ang:Up()
    end

    v.z = 0
    ang = v:Angle()
    local angr = ang:Right()
    local angu = ang:Up()
    pos = pos + ang:Right() * (15 - pf * 15)
    pos = pos + ang:Up() * (10 + pf * 6)
    pos = pos + ang:Forward() * (24 + pf * 4)

    if owner:InVehicle() then
        pos = pos - Vector(0, 0, 30) + ang:Right() * 10 + ang:Forward() * -10
    end

    ang:RotateAroundAxis(ang:Up(), self:GetNWBool("flip") and 90 or -90)
    ang:RotateAroundAxis(ang:Forward(), 0)
    ang:RotateAroundAxis(ang:Up(), (1 - pf) * -50 + pf * 60)
    ang:RotateAroundAxis(angr, pf * -70)
    ang:RotateAroundAxis(angu, pf * 40)
    --ang:RotateAroundAxis(ang:Forward(), pf*-40)
    --ang:RotateAroundAxis(ang:Right(), pf*80)

    return pos, ang
end

function SWEP:Initialize()
    self:SetHoldType("slam")
end

if SERVER then
    util.AddNetworkString("pillowboof")
    util.AddNetworkString("SetMyBodyPillow")

    net.Receive("SetMyBodyPillow", function(len, owner)
        local url = net.ReadString()

        if (owner.SetPillowTimeout or 0) > CurTime() - 2 then
            owner:Notify("Wait...")

            return
        end

        owner.SetPillowTimeout = CurTime()
        local wep = owner:GetWeapon("weapon_bodypillow")

        if IsValid(wep) then
            local url = SanitizeWebMatURL(url)
            wep:SetWebMatInfo(url, owner:SteamID())

            if id then
                for _, pillow_ent in ipairs(Ents.prop_trash_pillow) do
                    local t_url, t_owner = pillow_ent:GetWebMatInfo()

                    if t_owner == owner:SteamID() and url ~= t_url then
                        pillow_ent:SetWebMatInfo()
                        owner:Notify("Can't have different custom pillows")
                    end
                end
            end
        end
    end)
else
    local emitter = ParticleEmitter(Vector(0, 0, 0))

    net.Receive("pillowboof", function()
        local pos = net.ReadVector()
        if not Me or pos:Distance(Me:EyePos()) > 1200 then return end
        if not emitter then return end

        for i = 1, math.random(2, 12) do
            local particle = emitter:Add("particle/pillow-feather", pos + VectorRand() * 10)

            if particle then
                particle:SetColor(255, 255, 255, 255)
                particle:SetVelocity(VectorRand():GetNormalized() * 15)
                particle:SetGravity(Vector(0, 0, -20))
                particle:SetLifeTime(0)
                particle:SetDieTime(math.Rand(5, 10))
                particle:SetStartSize(math.Rand(2, 6))
                particle:SetEndSize(0)
                particle:SetStartAlpha(math.random(200, 250))
                particle:SetEndAlpha(0)
                particle:SetCollide(true)
                particle:SetBounce(0.25)
                particle:SetRoll(math.pi * math.Rand(0, 1))
                particle:SetRollDelta(math.pi * math.Rand(-2, 2))
            end
        end
    end)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.6 / self:TimeScale())
    if CLIENT and not IsFirstTimePredicted() then return end

    if CLIENT then
        self.localpf = RealTime()
    end

    local owner = self:GetOwner()

    if not owner:IsPony() then
        owner:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE, true)
    end

    if SERVER then
        timer.Simple(0.1 / self:TimeScale(), function()
            if IsValid(self) and IsValid(owner) then
                local boof = owner:EyePos() + owner:EyeAngles():Forward() * 50
                local aim = owner:EyeAngles():Forward()

                if math.abs(aim.z) == 1 then
                    aim = -owner:EyeAngles():Up()
                end

                aim.z = 0
                aim:Normalize()
                aim.z = 0.7
                aim = aim * 30

                for _, v in player.Iterator() do
                    local bcenter = v:LocalToWorld(v:OBBCenter())

                    if v ~= owner and v:Alive() and bcenter:Distance(boof) < (self:GetHardened() and 100 or 70) then
                        bcenter = bcenter + VectorRand() * 16
                        bcenter.z = bcenter.z + 8
                        local sound2play = self:GetHardened() and "physics/plastic/plastic_barrel_impact_hard" .. tostring(math.random(1, 3)) .. ".wav" or "bodypillow/hit" .. tostring(math.random(1, 2)) .. ".wav"
                        sound.Play(sound2play, bcenter, 80, math.random(100, 115) + (self:GetHardened() and -20 or 0), 1)
                        net.Start("pillowboof")
                        net.WriteVector(bcenter)
                        net.SendPVS(bcenter)

                        if not v:IsProtected() and not v:InVehicle() and not (IsValid(v:GetActiveWeapon()) and v:GetActiveWeapon():GetClass() == "weapon_golfclub") and not (owner.hvp and owner.hvp == v.hvp) then
                            if v:IsOnGround() then
                                v:SetPos(v:GetPos() + Vector(0, 0, 2))
                            end

                            local aimvel = aim

                            if self:GetHardened() then
                                aimvel = aim * 5
                                local dmg = DamageInfo()
                                dmg:SetAttacker(owner)
                                dmg:SetInflictor(self)
                                dmg:SetDamage(15)
                                dmg:SetDamagePosition(v:LocalToWorld(v:OBBCenter()))
                                dmg:SetDamageType(DMG_CLUB)
                                dmg:SetDamageForce(aimvel * 30 * 20)
                                v:TakeDamageInfo(dmg)
                            end

                            v:SetVelocity(aimvel)
                            if self:GetHardened() then break end
                        end
                    end
                end
            end
        end)
    end

    self:SetNWFloat("pf", CurTime())
    self:EmitSound("bodypillow/swing" .. tostring(math.random(1, 2)) .. ".wav", 60, math.random(100, 115), 0.1)
end

function SWEP:Boof(locl)
    local pf = self:GetNWFloat("pf")
    local ct = CurTime()

    if locl and self.localpf then
        pf = self.localpf
        ct = RealTime()
    end

    pf = pf * self:TimeScale()
    ct = ct * self:TimeScale()

    return math.max(0, math.min((ct - pf) * 5, ((pf + 1) - ct) / 0.8))
end

--NOMINIFY
function SWEP:SecondaryAttack()
    if SERVER then
        if self.REMOVING then return end
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        if not CannotMakeTrash(owner) then
            local e = ents.Create("prop_trash_pillow")
            if not IsValid(e) then return end
            e:SetNWBool("Hard", self:GetHardened())
            local pos, ang = LocalToWorld(self.droppos or Vector(40, 0, 0), self.dropang or Angle(10, 240, -10), owner:EyePos(), owner:EyeAngles())
            local fwdv = owner:EyeAngles():Forward() * 10
            local p2 = pos + fwdv

            local tr = util.TraceLine({
                start = owner:EyePos(),
                endpos = p2,
                mask = MASK_SOLID_BRUSHONLY
            })

            if tr.Hit then
                p2 = tr.HitPos
            end

            pos = p2 - fwdv
            e:SetPos(pos)
            e:SetAngles(ang)
            e:SetOwnerID(owner:SteamID())
            e:Spawn()
            e:Activate()
            e:GetPhysicsObject():SetVelocity(owner:GetVelocity())
            local url, owner = self:GetWebMatInfo()
            e:SetWebMatInfo(url, owner)
            self.REMOVING = true
            self:Remove()
        else
            owner:Notify("Can't drop right now, too much on map")
        end
    end
end

function SWEP:OnDrop()
    self:SecondaryAttack()

    if not self.REMOVING then
        self:Remove()
    end
end

function SWEP:OwnerChanged()
    if SERVER then
        local owner = self:GetOwner()

        if IsValid(owner) then
            local webmat_url = string.Trim(owner:GetInfo("bodypillow_url"))

            if webmat_url == "" then
                webmat_url = string.Trim(owner:GetInfo("bodypillow_imgur")) -- Fallback to the old ConVar

                if webmat_url ~= "" then
                    webmat_url = "i.imgur.com/" .. webmat_url
                end
            end

            self:SetWebMatInfo(webmat_url, owner:SteamID())
        end
    end
end

function SWEP:Reload()
    if CLIENT then
        if IsValid(self.OPENREQUEST) then return end
        local cur_url = self:GetWebMatInfo()

        self.OPENREQUEST = Derma_StringRequest("Custom Waifu", "Post an imgur/catbox direct URL, such as:\n\nhttps://i.imgur.com/4aIcUgd.jpg\nor\nhttps://files.catbox.moe/tx86vk.jpg\n\nLeft half is front of pillow, right half is back.", cur_url, function(url)
            local url = SanitizeWebMatURL(url) or ""
            RunConsoleCommand("bodypillow_url", url)
            RunConsoleCommand("bodypillow_imgur", "") -- Wipe out as soon as we're using the new ConVar
            net.Start("SetMyBodyPillow")
            net.WriteString(url)
            net.SendToServer()
        end)
    end
end
