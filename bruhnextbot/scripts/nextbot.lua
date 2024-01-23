------- SETTINGS -------
local tex = LoadSprite("MOD/tex.png")
local speedMove = 0.0092
local jumpForce = 1
local maxDist = 64

local useMusic = false -- if true then play loop music
local chaseMusic = LoadLoop("MOD/sounds/chase.ogg")
local deadSound = LoadSound("MOD/sounds/dead.ogg")

local debugMode = false -- If you want to see the bot's path to the player
------------------------

local jumpPower = 0.0
local position = Vec(0,0,0)
local lastposition = Vec(0,0,0)
local velocity = Vec(0,0,0)
local lastpoint
local targetpoint
local target = nil
local isSpawned = false
local spawnDelay = 0.0
local llast = 0.0
local updatePathTime = 0.0
local patrolTime = 0.0

local isDisabled = false

local navigation = {
    thinkTime = 0.0,
    timeout = 2.0,
    target = Vec(0,0,0),
    resultRetrieved = false
}
local pathPos = 1
local botPath = {}

function init()
    isSpawned = false
    target = GetPlayerPos()

    if(HasKey("savegame.mod.nextbot.speed")) then
        speedMove = GetFloat("savegame.mod.nextbot.speed")
    end
    if(HasKey("savegame.mod.nextbot.speed")) then
        maxDist = GetFloat("savegame.mod.nextbot.maxdist")
    end
    if(HasKey("savegame.mod.nextbot.music")) then
        useMusic = GetBool("savegame.mod.nextbot.music")
    end
    --DebugPrint("NextBot Spawned!")
end

function tick(dt)
    if(isSpawned == false) then
        if(spawnDelay < 4) then
            spawnDelay = spawnDelay + 0.1
        end
        local camTransform = GetCameraTransform()
    
        local dir = TransformToParentVec(camTransform, Vec(0, 0, -1))
        local hit, d, n = QueryRaycast(camTransform.pos, dir, 100)    

        if hit then
            local hitPoint = VecAdd(camTransform.pos, VecScale(dir, d))
            position = VecAdd(hitPoint,Vec(0,1,0))
            if(InputDown("lmb") and spawnDelay > 2) then
                isSpawned = true
            end
        end
        return
    end

    if(isDisabled) then
        return
    end
    
    
    if(debugMode) then
        for i=2,#botPath do
            DebugLine(botPath[i-1],botPath[i],1,1,1,1)
        end
    end

    QueryRequire("physical dynamic")
	local hit, p, n, s = QueryClosestPoint(position, 2)
	if hit then
		local body = GetShapeBody(s)
		SetBodyVelocity(body, VecScale(VecSub(position,target),-1))
		MakeHole(position, 1, 1)
	end

    if(GetPlayerHealth() > 0.0 and getDist(position,GetPlayerPos()) < 2) then
        SetPlayerHealth(0.0)
        PlaySound(deadSound, GetPlayerPos(), 0.5)
        isDisabled = true
    end
    if(useMusic and GetPlayerHealth() > 0.0 and getDist(position,GetPlayerPos()) < 16) then
        PlayLoop(chaseMusic, GetPlayerPos(), 0.5)
    end

    updateNavigation(dt)
    navigate()
end
local isChase = false
local randomPos = 0
function navigate()

    if(getDist(position,GetPlayerPos()) < maxDist) then
        isChase = true
    else
        isChase = false
        patrolTime = patrolTime + 0.1
    end

    if(#botPath > 1) then
        if(getDist(position,botPath[pathPos]) < 2) then
            pathPos = pathPos + 1
        end
        if(pathPos >= #botPath) then
            pathPos = #botPath
        end
        velocity = VecAdd(velocity,VecScale(VecNormalize(VecSub(position,botPath[pathPos])),-speedMove))
        velocity[2] = 0
    end
    updatePathTime = updatePathTime + 0.1
    if(updatePathTime > 3) then
    if(isChase == false and patrolTime > 10) then
        navigationClear()
        navigation.target = Vec(math.random(position[1]-100,position[1]+100),position[2],math.random(position[3]-100,position[3]+100))
        patrolTime = 0.0
    end
    if(isChase == true) then
        navigation.target = GetPlayerPos()
    end
    updatePathTime = 0
    end

    --[[
   
    patrolTime = patrolTime + 0.1

    if(updatePathTime > 2) then
        if(getDist(position,GetPlayerPos()) < maxDist) then
            isChase = true
            target = GetPlayerPos()
            QueryPath(position, target, 100, 0.0)
        else
            isChase = false
        end
        updatePathTime = 0.0
    end

    if(isChase == false and patrolTime > 5) then
        target = Vec(math.random(position[1]-1000,position[1]+1000),0,math.random(position[3]-1000,position[3]+1000))
        patrolTime = 0.0
    end

    local d = 0
    local l = GetPathLength()

    if(llast == l) then
        velocity = VecAdd(velocity,VecScale(VecNormalize(VecSub(position,target)),-speedMove))
        velocity[2] = 0
    else
        if l > 3 then
            --position = VecLerp(position,targetpoint, speedMove)
            velocity = VecAdd(velocity,VecScale(VecNormalize(VecSub(position,targetpoint)),-speedMove))
            velocity[2] = 0
    
            local s = GetPathState()
            targetpoint = GetPathPoint(2)
            lastpoint = GetPathPoint(l)
        end
    end
    -]]
    velocity = VecLerp(velocity, Vec(0,0,0), 0.04)

    local hit, d, n = QueryRaycast(position, Vec(0,-1,0), 1, 0.5)    

    if hit then
        if(getDist(position,target) < maxDist) then
            if(target[2] > position[2]+10) then
                jumpPower = jumpForce
            end
        end
        velocity[2] = velocity[2] + jumpPower
    else
        velocity[2] = velocity[2] + jumpPower
        jumpPower = jumpPower - 0.07
        if(jumpPower <= 0) then
            jumpPower = 0
            velocity[2] = velocity[2] - 9.81/40
        end
    end
    calculateCollision(velocity)
    position = VecAdd(position,velocity)

	lastposition = position
    llast = l
end

function calculateCollision(dir)
    local hit, d, n = QueryRaycast(VecAdd(position,Vec(0,1,0)), dir, 2, 0.2)    

    if hit then
       velocity = VecAdd(velocity,VecScale(dir,-1))
       velocity[2] = velocity[2] + 0.3
    end
end

function navigationClear()
	AbortPath()
	pathPos = 1
	botPath = {}
end

function updateNavigation(dt)
	if GetPathState() == "busy" then
		navigation.thinkTime = navigation.thinkTime + dt
		if navigation.thinkTime > navigation.timeout then
			AbortPath()
		end
        velocity = VecAdd(velocity,VecScale(VecNormalize(VecSub(position,navigation.target)),-speedMove/3))
        velocity[2] = 0
	end

	if GetPathState() ~= "busy" then
		if GetPathState() == "done" or GetPathState() == "fail" then
			if not navigation.resultRetrieved then
				if GetPathLength() > 0.5 then
					for l=1, GetPathLength(), 1 do
						local point = GetPathPoint(l)
						table.insert(botPath,point)
					end	
				end
				navigation.resultRetrieved = true
			end
		end
		navigation.thinkTime = 0
	end
    local ppos
    if(GetPlayerVehicle() ~= 0) then
        ppos = Vec(navigation.target[1],position[2],navigation.target[3])
    else
        ppos = navigation.target
    end
	if navigation.thinkTime == 0 and getDist(ppos,botPath[#botPath]) > 2 then
		navigationClear()
		QueryRequire("physical large static")
		QueryPath(position, ppos, 200, 0, "standard")
		navigation.resultRetrieved = false
	end
end


function draw()
    if(isDisabled) then
        return
    end
    local faceT = Transform(VecAdd(position,Vec(0,0.4,0)), QuatLookAt(position,GetCameraTransform().pos))

    DrawSprite(tex, faceT, 3, 3, 1, 1, 1, 1, true)
end

function err(reas)
    DebugPrint("Nextbot Base: " .. reas)
end

function randomVec()
	return Vec(math.random(-1,1),math.random(-1,1),math.random(-1,1))
end

function getDist(v1, v2)
	return VecLength(VecSub(v1,v2))
end

function lerp(a,b,t)
	return a + (b - a) * t
end