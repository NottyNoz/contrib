﻿-- This file is subject to copyright - contact swampservers@gmail.com for more information.
-- INSTALL: CINEMA
local Player = FindMetaTable('Player')
local Entity = FindMetaTable('Entity')
SS_MaterialCache = {}

--NOMINIFY
function SS_GetMaterial(nam)
    SS_MaterialCache[nam] = SS_MaterialCache[nam] or Material(nam)

    return SS_MaterialCache[nam]
end

function SS_PreRender(item)
    if item.cfg.imgur then
        local imat = ImgurMaterial({
            id = item.cfg.imgur.url,
            owner = item.owner,
            worksafe = true,
            pos = IsValid(item.owner) and item.owner:IsPlayer() and item.owner:GetPos(),
            stretch = true,
            shader = "VertexLitGeneric",
            params = [[{["$alphatest"]=1}]]
        })

        render.MaterialOverride(imat)
        --render.OverrideDepthEnable(true,true)
    else
        local mat = item.cfg.material or item.material

        if mat then
            render.MaterialOverride(SS_GetMaterial(mat))
        else
            render.MaterialOverride()
        end
    end

    local col = (item.GetColor and item:GetColor()) or item.cfg.color or item.color

    if col then
        render.SetColorModulation(col.x, col.y, col.z)
    end
end

function SS_PostRender()
    render.SetColorModulation(1, 1, 1)
    render.MaterialOverride()
    --render.OverrideDepthEnable(false)
end

hook.Add("PrePlayerDraw", "SS_BoneMods", function(ply)
    -- will be "false" if the model is not mounted yet
    local mounted_model = require_workshop_model(ply:GetModel()) and ply:GetModel()
    if not ply:Alive() then return true end

    if ply.SS_PlayermodelModsLastModel ~= mounted_model then
        ply.SS_PlayermodelModsClean = false
        --seems to have issues if you apply the bone mods as soon as the model changes...
        --timer.Simple(1, function() if IsValid(ply) then ply.SS_PlayermodelModsClean = false end end)
    end

    if not ply.SS_PlayermodelModsClean then
        ply.SS_PlayermodelModsClean = SS_ApplyBoneMods(ply, ply:SS_GetActivePlayermodelMods())
        ply.SS_PlayermodelModsLastModel = mounted_model
    end

    SS_ApplyMaterialMods(ply, ply:SS_GetActivePlayermodelMods())
end)

local function AddScaleRecursive(ent, b, scn, recurse, safety)
    if safety[b] then
        error("BONE LOOP!")
    end

    safety[b] = true
    local sco = ent:GetManipulateBoneScale(b)
    sco.x = sco.x * scn.x
    sco.y = sco.y * scn.y
    sco.z = sco.z * scn.z

    if ent:GetModel() == "models/milaco/minecraft_pm/minecraft_pm.mdl" then
        sco.x = math.min(sco.x, 1)
        sco.y = math.min(sco.y, 1)
        sco.z = math.min(sco.z, 1)
    end

    ent:ManipulateBoneScale(b, sco)

    if recurse then
        for i, v in ipairs(ent:GetChildBones(b)) do
            AddScaleRecursive(ent, v, scn, recurse, safety)
        end
    end
end

--only bone scale right now...
--if you do pos/angles, must do a combination override to make it work with emotes, vape arm etc
function SS_ApplyBoneMods(ent, mods)
    for x = 0, (ent:GetBoneCount() - 1) do
        ent:ManipulateBoneScale(x, Vector(1, 1, 1))
        ent:ManipulateBonePosition(x, Vector(0, 0, 0))
    end

    if ent:GetModel() == HumanTeamModel or ent:GetModel() == PonyTeamModel then return end
    local pone = isPonyModel(ent:GetModel())
    local suffix = pone and "_p" or "_h"
    --if pelvis has no children, its not ready!
    local pelvis = ent:LookupBone(pone and "LrigPelvis" or "ValveBiped.Bip01_Pelvis")

    if pelvis then
        if #ent:GetChildBones(pelvis) == 0 then return false end
    end

    for _, item in ipairs(mods) do
        if item.bonemod then
            local bn = item.cfg["bone" .. suffix] or (pone and "LrigScull" or "ValveBiped.Bip01_Head1")
            local x = ent:LookupBone(bn)

            if x then
                if (item.configurable or {}).scale then
                    local scn = item.cfg["scale" .. suffix] or Vector(1, 1, 1.5)
                    AddScaleRecursive(ent, x, scn, item.cfg["scale_children" .. suffix], {})
                end

                if (item.configurable or {}).pos then
                    local psn = item.cfg["pos" .. suffix] or Vector(10, 0, 0)

                    --don't allow moving the root bone
                    if ent:GetBoneParent(x) == -1 then
                        psn.x = 0
                        psn.y = 0
                    end

                    local pso = ent:GetManipulateBonePosition(x)
                    pso = pso + psn
                    ent:ManipulateBonePosition(x, pso)
                end
            end
        end
    end

    --clamp the amount of stacking
    for x = 0, (ent:GetBoneCount() - 1) do
        local old = ent:GetManipulateBoneScale(x)
        local mn = 0.125 --0.5*0.5*0.5
        local mx = 3.375 --1.5*1.5*1.5

        if ent.GetNetData and ent:GetNetData('OF') ~= nil then
            mx = 1.5
        end

        old.x = math.Clamp(old.x, mn, mx)
        old.y = math.Clamp(old.y, mn, mx)
        old.z = math.Clamp(old.z, mn, mx)
        ent:ManipulateBoneScale(x, old)
        old = ent:GetManipulateBonePosition(x)
        old.x = math.Clamp(old.x, -8, 8)
        old.y = math.Clamp(old.y, -8, 8)
        old.z = math.Clamp(old.z, -8, 8)
        ent:ManipulateBonePosition(x, old)
    end

    return true
end

function SS_ApplyMaterialMods(ent, mods)
    ent:SetSubMaterial()

    if SS_PPM_SetSubMaterials then
        SS_PPM_SetSubMaterials(ent)
    end

    if ent:GetModel() == HumanTeamModel or ent:GetModel() == PonyTeamModel then return end

    for _, item in ipairs(mods) do
        if item.materialmod then
            local col = item.cfg.color or Vector(1, 1, 1)

            local mat = ImgurMaterial({
                id = (item.cfg.imgur or {}).url or "EG84dgp.png",
                owner = ent,
                worksafe = true,
                pos = IsValid(ent) and ent:IsPlayer() and ent:GetPos(),
                stretch = true,
                shader = "VertexLitGeneric",
                params = string.format('{["$color2"]="[%f %f %f]"}', col.x, col.y, col.z)
            })

            ent:SetSubMaterial(item.cfg.submaterial or 0, "!" .. mat:GetName())
        end
    end
end

local EntityGetModel = Entity.GetModel

-- Entity.SS_True_LookupAttachment = Entity.SS_True_LookupAttachment or Entity.LookupAttachment
-- Entity.SS_True_LookupBone = Entity.SS_True_LookupBone or Entity.LookupBone
-- function Entity:LookupAttachment(id)
--     local mdl = EntityGetModel(self)
--     if self.LookupAttachmentCacheModel ~= mdl then
--         self.LookupAttachmentCache={}
--     end
--     if not self.LookupAttachmentCache[id] then self.LookupAttachmentCache[id] = Entity.SS_True_LookupAttachment(self, id) end
--     return self.LookupAttachmentCache[id]
-- end
-- function Entity:LookupBone(id)
--     local mdl = EntityGetModel(self)
--     if self.LookupBoneCacheModel ~= mdl then
--         self.LookupBoneCache={}
--     end
--     if not self.LookupBoneCache[id] then self.LookupBoneCache[id] = Entity.SS_True_LookupBone(self, id) end
--     return self.LookupBoneCache[id]
-- end
-- function SWITCHH()
--     Entity.LookupAttachment = Entity.SS_True_LookupAttachment
--     Entity.LookupBone = Entity.SS_True_LookupBone
-- end
--TODO: add "defaultcfg" as a standard field in items rather than this hack!
--TODO this is lag causin
-- function SS_GetItemWorldPos(item, ent)
--     local pone = isPonyModel(EntityGetModel(ent))
--     local attach, translate, rotate, scale = item:AccessoryTransform(pone)
--     local pos, ang
--     if attach == "eyes" then
--         local attach_id = ent:LookupAttachment("eyes")
--         if attach_id then
--             local attacht = ent:GetAttachment(attach_id)
--             if attacht then
--                 pos = attacht.Pos
--                 ang = attacht.Ang
--             end
--         end
--     else
--         local bone_id = ent:LookupBone(SS_Attachments[attach][pone and 2 or 1])
--         if bone_id then
--             pos, ang = ent:GetBonePosition(bone_id)
--         end
--     end
--     if not pos then return end
--     pos, ang = LocalToWorld(translate, rotate, pos, ang)
--     return pos, ang
-- end
-- function SS_DrawWornCSModel(item, mdl, ent)
--     local pos, ang = SS_GetItemWorldPos(item, ent)
--     mdl:Refresh()
--     -- local pone = isPonyModel(EntityGetModel(ent))
--     -- local attach, translate, rotate, scale = item:AccessoryTransform(pone)
--     -- local pos, ang
--     -- if attach == "eyes" then
--     --     local fn = FrameNumber()
--     --     if ent.attachcacheframe ~= fn then
--     --         ent.attachcacheframe = fn
--     --         local attach_id = ent:LookupAttachment("eyes")
--     --         if attach_id then
--     --             local attacht = ent:GetAttachment(attach_id)
--     --             if attacht then
--     --                 ent.attachcache = attacht
--     --                 pos = attacht.Pos
--     --                 ang = attacht.Ang
--     --             end
--     --         end
--     --     else
--     --         local attacht = ent.attachcache
--     --         if attacht then
--     --             pos = attacht.Pos
--     --             ang = attacht.Ang
--     --         end
--     --     end
--     -- else
--     --     local bone_id = ent:LookupBone(SS_Attachments[attach][pone and 2 or 1])
--     --     if bone_id then
--     --         pos, ang = ent:GetBonePosition(bone_id)
--     --     end
--     -- end
--     -- if not pos then
--     --     pos = ent:GetPos()
--     --     ang = ent:GetAngles()
--     -- end
--     -- pos, ang = LocalToWorld(translate, rotate, pos, ang)
--     print("DRAW",mdl:GetModel(),pos)
--     -- mdl:SetParent()
--     mdl:SetPos(pos)
--     mdl:SetAngles(ang)
--     mdl:SetupBones()
--     -- local bone_id = ent:LookupBone(SS_Attachments[attach][pone and 2 or 1])
--     -- -- if attach=="eyes" then
--     -- -- --     mdl:SetParent(ent, ent:LookupAttachment("eyes"))
--     -- if bone_id then
--     --     print(ent, bone_id)
--     --     mdl:FollowBone(ent, bone_id)
--     --     mdl:SetLocalPos(translate)
--     --     mdl:SetLocalAngles(rotate)
--     -- end
--     -- SS_PreRender(item)
--     DrawingInShop = true
--     mdl:DrawModel()
--     DrawingInShop = false
--     -- SS_PostRender()
-- end
--NOMINIFY
-- hook.Add("DrawOpaqueAccessories", 'SS_DrawPlayerAccessories', function(ply)
hook.Add("PrePlayerDraw", 'SS_DrawPlayerAccessories', function(ply)
    if ply.SS_Items == nil and ply.SS_ShownItems == nil then return end
    if not ply:Alive() then return end
    if EyePos():DistToSqr(ply:GetPos()) > 2000000 then return end
    -- and (GetConVar('thirdperson') and GetConVar('thirdperson'):GetInt() == 0)
    --if ply == LocalPlayer() and GetViewEntity():GetClass() == 'player' then return end
    if GAMEMODE.FolderName == "fatkid" and ply:Team() ~= TEAM_HUMAN then return end

    --in SPADES, the renderboost.lua is disabled!
    -- Note: this is only called when alive
    for i, v in ipairs(ply:SS_GetCSModels() or {}) do
        -- if ply==LocalPlayer() then print(v.mdl:GetPos(), v.mdl:GetParent(), v.mdl:GetLocalPos()) end
        v:Attach(ply)
    end
end)

hook.Add('CreateClientsideRagdoll', 'SS_CreateClientsideRagdoll', function(ply, rag)
    if IsValid(ply) and ply:IsPlayer() then
        local counter = 0

        for k, v in pairs(SS_CSModels[ply] or {}) do
            counter = counter + 1
            if counter > 10 then return end
            local gib = GibClientProp(v:GetModel(), v:GetPos(), v:GetAngles(), ply:GetVelocity(), 1, 6)

            if v.matrix then
                gib:EnableMatrix("RenderMultiply", v.matrix)
            end

            local item = v.item

            gib.RenderOverride = function(e, fl)
                SS_PreRender(item)
                e:DrawModel()
                SS_PostRender()
            end
        end
    end
end)

SS_CSModels = SS_CSModels or {}

hook.Add('Think', 'SS_Cleanup', function()
    for ply, mdls in pairs(SS_CSModels) do
        if not IsValid(ply) then
            for i, v in ipairs(mdls) do
                v:Remove()
            end

            SS_CSModels[ply] = nil
        end
    end
end)

-- --makes a CSModel for a worn item
-- function SS_CreateWornCSModel(item)
--     if item.wear == nil then return end
--     local mdl = SS_CreateCSModel(item)
--     mdl.Refresh = function(e)
--         if scale ~= e.appliedscale then
--             e.matrix = isnumber(scale) and Matrix({
--                 {scale, 0, 0, 0},
--                 {0, scale, 0, 0},
--                 {0, 0, scale, 0},
--                 {0, 0, 0, 1}
--             }) or Matrix({
--                 {scale.x, 0, 0, 0},
--                 {0, scale.y, 0, 0},
--                 {0, 0, scale.z, 0},
--                 {0, 0, 0, 1}
--             })
--             -- TODO: do we need to adjust renderbounds?
--             e:EnableMatrix("RenderMultiply", e.matrix)
--             e.appliedscale = scale
--         end
--     end
--     return mdl
-- end
local DrawingInShop = false

--makes a CSModel for a product or item
function SS_CreateCSModel(item)
    local ply = item.owner == SS_SAMPLE_ITEM_OWNER and LocalPlayer() or item.owner
    local mdl = ClientsideModel(item:GetModel(), RENDERGROUP_OPAQUE)
    mdl.item = item

    if item.AccessoryTransform then
        mdl.Attach = function(e, ent)
            ent = ent or ply

            if not IsValid(e:GetParent()) or e.lastent ~= ent then
                e.appliedmodel = nil
                e.lastent = ent
            end

            local desiredmodel = EntityGetModel(ent)
            local pone = isPonyModel(desiredmodel)
            local attach, translate, rotate, scale = item:AccessoryTransform(pone)

            if desiredmodel ~= e.appliedmodel then
                if attach == "eyes" then
                    local attach_id = ent:LookupAttachment("eyes")
                    if attach_id < 1 then return end
                    e:SetParent(ent, attach_id)
                else
                    local bone_id = ent:LookupBone(SS_Attachments[attach][pone and 2 or 1])
                    if not bone_id then return end
                    e:FollowBone(ent, bone_id)
                end

                e.appliedmodel = desiredmodel
            end

            if scale ~= e.appliedscale then
                e.matrix = isnumber(scale) and Matrix({
                    {scale, 0, 0, 0},
                    {0, scale, 0, 0},
                    {0, 0, scale, 0},
                    {0, 0, 0, 1}
                }) or Matrix({
                    {scale.x, 0, 0, 0},
                    {0, scale.y, 0, 0},
                    {0, 0, scale.z, 0},
                    {0, 0, 0, 1}
                })

                -- TODO: do we need to adjust renderbounds?
                e:EnableMatrix("RenderMultiply", e.matrix)
                e.appliedscale = scale
            end

            --this likes to change itself
            e:SetLocalPos(translate)
            e:SetLocalAngles(rotate)
        end

        mdl.DrawInShop = function(self, ent)
            -- local pos, ang = SS_GetItemWorldPos(item, ent)
            -- self:SetPos(pos)
            -- self:SetAngles(ang)
            self:Attach(ent)
            -- make sure it isn't cached bone position from the world version
            self:SetupBones()
            DrawingInShop = true
            self:DrawModel()
            DrawingInShop = false
        end
    end

    mdl.RenderOverride = function(e, fl)
        if not DrawingInShop then
            -- will be cleaned up
            if not IsValid(ply) then return end
            if ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer() then return end
            -- TODO use these models as the gibs?
            if not ply:Alive() then return end

            if ply:IsDormant() then
                ply:SS_ClearCSModels()

                return
            end
        end

        SS_PreRender(item)
        e:DrawModel()
        SS_PostRender()
    end

    return mdl
end

function Player:SS_ClearCSModels()
    for i, v in ipairs(SS_CSModels[self] or {}) do
        v:Remove()
    end

    SS_CSModels[self] = nil
end

function Player:SS_GetCSModels()
    if SS_CSModels[self] == nil then
        SS_CSModels[self] = {}

        for k, item in pairs(self.SS_ShownItems or {}) do
            if item.AccessoryTransform then
                table.insert(SS_CSModels[self], SS_CreateCSModel(item))
            end
        end
    end

    return SS_CSModels[self]
end

function Player:SS_GetActivePlayermodelMods()
    local mods = {}

    for k, item in pairs(self.SS_ShownItems or {}) do
        if item.playermodelmod then
            table.insert(mods, item)
        end
    end

    return mods
end
-- function Player:SS_GetActiveMaterialMods()
--     --{[5]="https://i.imgur.com/Ue1qUPf.jpg"}
--     return {}
-- end
-- function thinga()
--     TTT1 = FindMetaTable("Entity")
--     TTT2 = FindMetaTable("Player")
--     TTT2.SetMaterial = function(a, b)
--         TTT1.SetMaterial(a, b)
--         print(a, b)
--     end
-- end
