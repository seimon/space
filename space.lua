dev=1
ver="0.12"
latest_update="2022/02/02"

poke(0X5F5C, 12) poke(0X5F5D, 3) -- Input Delay(default 15, 4)
poke(0x5f2d, 0x1) -- Use Mouse input

-- screen cover pattern 0->100%
cover_pattern_str=[[
0b1111111111111111.1,
0b1111011111111101.1,
0b1111010111110101.1,
0b1011010111100101.1,
0b1010010110100101.1,
0b0010010110000101.1,
0b0000010100000101.1,
0b0000010000000001.1,
0b0000000000000000.1
]]
cover_pattern=split(cover_pattern_str,",")

-- particla data
-- x,y,color pre calculated value
p_data={}
p_str=[[
3,1,7,4,1,7,5,1,7,6,1,7,6,1,10,7,1,10,8,2,10,9,2,9,9,2,9,10,2,4,10,2,5,11,2,5,11,2,2,11,2,2/
2,2,7,2,2,7,2,3,7,3,3,7,3,3,7,4,4,7,4,4,7,4,5,10,5,5,10,5,5,10,5,6,10,6,6,10,6,6,9,6,7,9,6,7,9,7,7,4,7,7,4,7,8,4,7,8,5/
1,3,7,1,4,7,1,4,7,1,5,7,2,6,10,2,7,10,2,7,10,2,8,10,2,9,9,2,9,9,3,10,4,3,10,5,3,11,5,3,11,2,3,11,2/
-1,3,7,-1,3,7,-1,4,7,-2,5,7,-2,6,10,-2,6,10,-2,7,10,-2,7,10,-3,8,9,-3,9,9,-3,9,4,-3,10,4,-3,10,5,-3,10,5,-3,11,2,-4,11,2/
-2,1,7,-3,1,7,-4,1,7,-4,2,7,-5,2,7,-5,2,7,-6,2,10,-6,3,10,-7,3,10,-7,3,10,-8,3,10,-8,3,9,-9,3,9,-9,4,4,-9,4,4,-10,4,4,-10,4,5,-10,4,5,-11,4,2/
-3,-1,7,-4,-1,7,-4,-1,7,-5,-1,7,-6,-1,10,-7,-1,10,-7,-1,10,-8,-2,10,-9,-2,9,-9,-2,9,-10,-2,4,-10,-2,4,-11,-2,5,-11,-2,5,-11,-2,2,-11,-2,2/
-1,-3,7,-2,-3,7,-2,-4,7,-3,-5,7,-3,-5,10,-3,-6,10,-4,-7,10,-4,-7,10,-4,-8,9,-5,-8,9,-5,-9,4,-5,-9,5,-5,-10,5,-5,-10,2,-6,-10,2/
0,-3,7,0,-3,7,0,-4,7,-1,-4,7,-1,-5,7,-1,-5,7,-1,-6,10,-1,-6,10,-1,-7,10,-1,-7,10,-1,-8,10,-1,-8,9,-1,-9,9,-1,-9,9,-1,-10,4,-1,-10,4,-1,-10,4,-1,-11,5,-1,-11,5/
2,-2,7,2,-3,7,3,-4,7,3,-5,7,4,-6,10,4,-6,10,4,-7,10,5,-7,9,5,-8,9,5,-9,4,6,-9,5,6,-9,5,6,-10,2,6,-10,2/
2,-1,7,3,-1,7,3,-1,7,4,-1,7,4,-1,7,5,-2,7,5,-2,7,6,-2,10,6,-2,10,7,-2,10,7,-2,10,8,-3,10,8,-3,9,9,-3,9,9,-3,9,9,-3,4,10,-3,4,10,-3,4,10,-3,5
]]



-- <class helper> --------------------
function class(base)
	local nc={}
	if (base) setmetatable(nc,{__index=base}) 
	nc.new=function(...) 
		local no={}
		setmetatable(no,{__index=nc})
		local cur,q=no,{}
		repeat
			local mt=getmetatable(cur)
			if not mt then break end
			cur=mt.__index
			add(q,cur,1)
		until cur==nil
		for i=1,#q do
			if (rawget(q[i],'init')) rawget(q[i],'init')(no,...)
		end
		return no
	end
	return nc
end

-- event dispatcher
event=class()
function event:init()
	self._evt={}
end
function event:on(event,func,context)
	self._evt[event]=self._evt[event] or {}
	-- only one handler with same function
	self._evt[event][func]=context or self
end
function event:remove_handler(event,func,context)
	local e=self._evt[event]
	if (e and (context or self)==e[func]) e[func]=nil
end
function event:emit(event,...)
	for f,c in pairs(self._evt[event]) do
		f(c,...)
	end
end

-- sprite class for scene graph
sprite=class(event)
function sprite:init()
	self.children={}
	self.parent=nil
	self.x=0
	self.y=0
end
function sprite:set_xy(x,y)
	self.x=x
	self.y=y
end
function sprite:get_xy()
	return self.x,self.y
end
function sprite:add_child(child)
	child.parent=self
	add(self.children,child)
end
function sprite:remove_child(child)
	del(self.children,child)
	child.parent=nil
end
function sprite:remove_self()
	if self.parent then
		self.parent:remove_child(self)
	end
end
-- logical xor
function lxor(a,b) return not a~=not b end
-- common draw function
function sprite:_draw(x,y,fx,fy)
	spr(self.spr_idx,x+self.x,y+self.y,self.w or 1,self.h or 1,lxor(fx,self.fx),lxor(fy,self.fy))
end
function sprite:show(v)
	self.draw=v and self._draw or nil
end
function sprite:render(x,y,fx,fy)
	if (self.draw) self:draw(x,y,fx,fy)
	for i=1,#self.children do
		self.children[i]:render(x+self.x,y+self.y,lxor(fx,self.fx),lxor(fy,self.fy))
	end
end
function sprite:emit_update()
	self:emit("update")
	for i=1,#self.children do
		local child=self.children[i]
		if child then child:emit_update() end
	end
end



-- <utilities> --------------------
function round(n) return flr(n+.5) end
function swap(v) if v==0 then return 1 else return 0 end end -- 1 0 swap
function clamp(a,min_v,max_v) return min(max(a,min_v),max_v) end
function rndf(lo,hi) return lo+rnd()*(hi-lo) end -- random real number between lo and hi
function printa(t,x,y,c,align) -- 0.5 center, 1 right align
	x-=align*4*#t
	print(t,x,y,c)
end



-- <space> --------------------

space=class(sprite)
function space:init(is_front)
	self.spd_x=0
	self.spd_y=0
	self.stars={}
	self.particles={}

	local function make_star(i,max,base_spd)
		local col={1,1,1,1,5,13}
		return {
			x=rnd(127),
			y=rnd(127),
			c=base_spd>1 and col[5+round(i/max)] or col[1+round(i/max*5)],
			spd=base_spd+i/max*base_spd,
			size=1+rnd(1)
		}
	end
	if is_front then
		for i=1,8 do
			add(self.stars,make_star(i,8,2))
		end
	else
		for i=1,50 do
			add(self.stars,make_star(i,50,1))
		end
	end

	self:show(true)
	self:on("update",self.on_update)
end

ptcl_size="11223334443332211000"
ptcl_thrust_col="c77aa99882211211"
ptcl_back_col="77666dd1d111"
ptcl_fire_col="89a7"
ptcl_size_explosion="35787766555444443333332222221111111000"
ptcl_col_explosion="77aaa99988888989994444441111"
ptcl_col_explosion_dust="77982"
ptcl_col_hit="cc7a82"

function space:_draw()
	-- stars
	for i,v in pairs(self.stars) do
		local x=v.x-self.spd_x*v.spd
		local y=v.y+self.spd_y*v.spd
		v.x=x>129 and x-129 or x<-2 and x+129 or x
		v.y=y>129 and y-129 or y<-2 and y+129 or y
		local x2=v.x+cx
		local y2=v.y+cy
		x2=x2>129 and x2-129 or x2<-2 and x2+129 or x2
		y2=y2>129 and y2-129 or y2<-2 and y2+129 or y2
		if v.size>1.9 then circfill(x2,y2,1,v.c)
		else pset(x2,y2,v.c) end
	end

	-- particles
	for i,v in pairs(self.particles) do
		if v.type=="thrust" then
			circfill(v.x,v.y,
				sub(ptcl_size,v.age,_),
				tonum(sub(ptcl_thrust_col,v.age,_),0x1))
			v.x+=v.sx-self.spd_x+rnd(2)-1
			v.y+=v.sy+self.spd_y+rnd(2)-1
			v.sx*=0.93
			v.sy*=0.93
			if(v.age>20) del(self.particles,v)

		elseif v.type=="thrust-back" then
			circfill(v.x,v.y,
				sub(ptcl_size,v.age,_)*0.7,
				tonum(sub(ptcl_back_col,v.age,_),0x1))
			v.x+=v.sx-self.spd_x+rnd(2)-1
			v.y+=v.sy+self.spd_y+rnd(2)-1
			v.sx*=0.93
			v.sy*=0.93
			if(v.age>16) del(self.particles,v)

		elseif v.type=="bullet" or v.type=="bomb" then
			local ox,oy=v.x,v.y
			v.x+=v.sx-self.spd_x
			v.y+=v.sy+self.spd_y
			local c=tonum(sub(ptcl_fire_col,1+round(v.age/12),_),0x1)
			if v.type=="bullet" then
				line(ox,oy,v.x,v.y,c)
			else
				spr(9,v.x-4,v.y-4)
			end
			if(v.age>60 or v.x>131 or v.y>131 or v.x<-4 or v.y<-4) del(self.particles,v)

			-- hit test bullet & enemy
			-- todo: 폭탄 임시 처리해 둔 상태
			local dmg=(v.type=="bomb") and 10 or 1
			local dist=(v.type=="bomb") and 8 or 5
			for j,e in pairs(_enemies.list) do
				if is_near(v.x,v.y,e.x,e.y,dist) and get_dist(v.x,v.y,e.x,e.y)<=dist then
					e.hp-=dmg
					if e.hp<=0 then
						add_explosion_eff(e.x,e.y,v.sx,v.sy)
						del(_enemies.list,e)
						sfx(3,3)
					else
						e.hit_count=8
						local a=atan2(e.x-v.x,e.y-v.y)
						add_hit_eff(v.x,v.y,a)
						sfx(2,3)
					end
					del(self.particles,v)
				end
			end

		elseif v.type=="explosion" then
			circfill(v.x,v.y,
				sub(ptcl_size_explosion,v.age,_),
				tonum(sub(ptcl_col_explosion,v.age,_),0x1))
			v.x+=v.sx-self.spd_x+rnd(1)-0.5
			v.y+=v.sy+self.spd_y+rnd(1)-0.5
			v.sx*=0.9
			v.sy*=0.9
			if(v.age>40) del(self.particles,v)

		elseif v.type=="explosion_dust" then
			local c=tonum(sub(ptcl_col_explosion_dust,1+flr(v.age/5),_),0x1)
			pset(v.x,v.y,c)
			v.x+=v.sx-self.spd_x
			v.y+=v.sy+self.spd_y
			v.sx*=0.94
			v.sy*=0.94
			if(v.age>20) del(self.particles,v)

		elseif v.type=="hit" then
			local c=tonum(sub(ptcl_col_hit,1+flr(v.age/3),_),0x1)
			pset(v.x,v.y,c)
			v.x+=v.sx-self.spd_x
			v.y+=v.sy+self.spd_y
			v.sx*=0.94
			v.sy*=0.94
			if(v.age>12) del(self.particles,v)

		end
		v.age+=1
	end
end

function space:on_update()
end



-- <ship> --------------------

ship=class(sprite)
function ship:init()
	self.spd=0
	self.spd_x=0
	self.spd_y=0
	self.spd_max=1.8
	self.angle=0
	self.angle_acc=0
	self.thrust=0
	self.thrust_acc=0
	self.thrust_max=1.4
	self.tail={x=0,y=0}
	self.head={x=0,y=0}
	self.fire_spd=1.4 -- 1.4 -> 3.0
	self.fire_intv=0
	self.fire_intv_full=16 -- 20 -> 5
	self.bomb_spd=0.8
	self.bomb_intv=0
	self.bomb_intv_full=60
	self.hit_count=0
	self:show(true)
	self:on("update",self.on_update)
end

guide_pattern_str=[[
0b1111011111111101.1,
0b0111110111111111.1,
0b1101111101111111.1,
]]
guide_pattern=split(guide_pattern_str,",")

function ship:_draw()
	local x0=cos(self.angle)
	local y0=sin(self.angle)
	local x1=cx+0.5-x0*2
	local y1=cy+0.5-y0*2

	local x2=cx+cos(self.angle-0.40)*6
	local y2=cy+sin(self.angle-0.40)*6
	local x3=cx+cos(self.angle+0.40)*6
	local y3=cy+sin(self.angle+0.40)*6
	-- local x2=cos(self.angle-0.45)
	-- local y2=sin(self.angle-0.45)
	-- local x3=cos(self.angle+0.45)
	-- local y3=sin(self.angle+0.45)

	-- guide line
	local len=50
	fillp(guide_pattern[1+round(f/6)%3])
	line(cx-1,cy-1,cx-1+x0*len,cy-1+y0*len,1)
	line(cx-1,cy,cx-1+x0*len,cy+y0*len,1)
	line(cx,cy-1,cx+x0*len,cy-1+y0*len,1)
	line(cx,cy,cx+x0*len,cy+y0*len,1)
	line(cx-1,cy-1,cx-1+x0*len,cy-1+y0*len,1)
	fillp()

	-- ship body
	if self.hit_count>0 then
		pal(10,7)
		pal(9,7)
		pal(4,10)
		self.hit_count-=1
	end
	line(cx,cy,cx+x0*6,cy+y0*6,9)
	pset(cx+x0*6,cy+y0*6,8)
	spr(0,cx-4,cy-4)
	spr(2,x2-1,y2-1)
	spr(2,x3-1,y3-1)
	-- line(cx+x2*5.4,cy+y2*5.4,cx+x3*5.4,cy+y3*5.4,13)
	-- line(cx+x2*6,cy+y2*6,cx+x3*6,cy+y3*6,6)
	-- line(cx+x2*6.6,cy+y2*6.6,cx+x3*6.6,cy+y3*6.6,13)
	-- line(cx+x2*7.2,cy+y2*7.2,cx+x3*7.2,cy+y3*7.2,6)
	spr(1,x1-4,y1-4)
	pal()

	self.tail.x=cx+0.5-x0*9
	self.tail.y=cy+0.5-y0*9
	self.head.x=cx+0.5+x0*9
	self.head.y=cy+0.5+y0*9
end
function ship:on_update()
	
	-- rotation
	if btn(0) then self.angle_acc+=0.0006
	elseif btn(1) then self.angle_acc-=0.0006 end
	local a=self.angle+self.angle_acc
	self.angle=a>1 and a-1 or a<0 and a+1 or a
	self.angle_acc*=0.93
	if(abs(self.angle_acc)<0.0005) self.angle_acc=0

	-- acceleration
	if btn(2) then
		self.thrust_acc+=0.0006
	elseif btn(3)
		then self.thrust_acc-=0.0003
	end
	self.thrust=clamp(self.thrust+self.thrust_acc,-self.thrust_max,self.thrust_max)
	self.thrust_acc*=0.8
	self.thrust*=0.9
	local thr_x=cos(self.angle)*self.thrust
	local thr_y=sin(self.angle)*self.thrust
	self.spd_x+=thr_x
	self.spd_y+=thr_y
	self.spd_x*=0.995
	self.spd_y*=0.995

	-- fire
	self.fire_intv-=1
	if btn(4) and self.fire_intv<=0 then
		sfx(6,-1)
		self.fire_intv=self.fire_intv_full
		local fire_spd_x=cos(self.angle)*self.fire_spd+self.spd_x
		local fire_spd_y=sin(self.angle)*self.fire_spd+self.spd_y
		add(_space_f.particles,
		{
			type="bullet",
			x=self.head.x,
			y=self.head.y,
			sx=fire_spd_x,
			sy=fire_spd_y,
			age=1
		})
	end

	-- bomb
	-- todo: 폭탄 인터벌이든 뭐든 처리해야 함
	self.bomb_intv-=1
	if btn(5) and self.bomb_intv<=0 then
		sfx(6,-1)
		self.bomb_intv=self.bomb_intv_full
		local fire_spd_x=cos(self.angle)*self.bomb_spd+self.spd_x
		local fire_spd_y=sin(self.angle)*self.bomb_spd+self.spd_y
		add(_space_f.particles,
		{
			type="bomb",
			x=self.head.x,
			y=self.head.y,
			sx=fire_spd_x,
			sy=fire_spd_y,
			age=1
		})
	end

	-- add effect
	if self.thrust_acc>0 then
		sfx(4,2)
		add(_space_f.particles,
		{
			type="thrust",
			x=self.tail.x-2+rnd(4),
			y=self.tail.y-2+rnd(4),
			sx=-thr_x*160,
			sy=-thr_y*160,
			age=1
		})
	elseif self.thrust_acc<-0.0001 then
		sfx(5,2)
		add(_space_f.particles,
		{
			type="thrust-back",
			x=self.head.x-2+rnd(4),
			y=self.head.y-2+rnd(4),
			sx=-thr_x*160,
			sy=-thr_y*160,
			age=1
		})
	else
		sfx(-1,2)
	end

	-- speed limit
	local spd=sqrt(self.spd_x^2+self.spd_y^2)
	if spd>self.spd_max then
		local r=self.spd_max/spd
		self.spd_x*=r
		self.spd_y*=r
	end

	-- hit test with enemies
	for i,e in pairs(_enemies.list) do
		if is_near(e.x,e.y,cx,cy,8) and get_dist(e.x,e.y,cx,cy)<=8 then
			-- simply speed change(don't consider hit direction)
			local sx=e.spd_x
			local sy=e.spd_y
			e.spd_x=self.spd_x*1.2
			e.spd_y=self.spd_y*1.2
			self.spd_x*=-0.3
			self.spd_y*=-0.3
			sfx(2,3)
			self.hit_count=8
			e.hit_count=8
			e.hp-=1
			local d=atan2(e.x-cx,e.y-cy)
			add_hit_eff((cx+e.x)/2,(cy+e.y)/2,d)
		end
	end

	-- space speed update
	_space.spd_x=self.spd_x
	_space.spd_y=-self.spd_y
	_space_f.spd_x=self.spd_x
	_space_f.spd_y=-self.spd_y
	
	-- space center move(use space speed & ship direction)
	local tcx=64-self.spd_x*12-cos(self.angle)*22
	local tcy=64-self.spd_y*12-sin(self.angle)*22
	cx=cx+(tcx-cx)*0.03
	cy=cy+(tcy-cy)*0.03
end



-- <enemies> --------------------

enemies=class(sprite)
function enemies:init(enemies_num)
	self.list={}
	for i=1,enemies_num do
		local x=cos(i/enemies_num)
		local y=sin(i/enemies_num)
		self:add(x*50,y*50)
		self:add(x*70,y*70)
	end

	self:show(true)
end
function enemies:_draw()
	for i,e in pairs(self.list) do
		e.space_x+=e.spd_x-_space.spd_x
		e.space_y+=e.spd_y+_space.spd_y
		e.x=e.space_x+cx
		e.y=e.space_y+cy
		e.spd_x*=0.99
		e.spd_y*=0.99
		if e.x<-4 then
			spr(5,0,clamp(e.y-4,4,118))
		elseif e.x>131 then
			spr(5,127-8,clamp(e.y-4,4,118),1,1,true)
		elseif e.y<-4 then
			spr(6,clamp(e.x-4,4,118),0)
		elseif e.y>131 then
			spr(6,clamp(e.x-4,4,118),127-8,1,1,false,true)
		else
			if e.hit_count>0 then
				spr(7,e.x-4,e.y-4)
				e.hit_count-=1
			else
				spr(e.spr,e.x-4,e.y-4)
			end
		end
	end

	-- hit test between enemies
	for i,e1 in pairs(self.list) do
		for j=i+1,#self.list do
			local e2=self.list[j]
			if abs(e1.x-e2.x)<=8 and abs(e1.y-e2.y)<=8 then
				if sqrt((e1.x-e2.x)^2+(e1.y-e2.y)^2)<8 then
					local sx,sy=e1.spd_x,e1.spd_y
					e1.spd_x=e2.spd_x*1.2
					e1.spd_y=e2.spd_y*1.2
					e2.spd_x=sx*1.2
					e2.spd_y=sy*1.2
					sfx(2,3)
					e1.hit_count=8
					e2.hit_count=8
					e1.hp-=1
					e2.hp-=1
					local d=atan2(e1.x-e2.x,e1.y-e2.y)
					add_hit_eff((e1.x+e2.x)/2,(e1.y+e2.y)/2,d)
				end
			end
		end
	end

end
function enemies:add(x,y)
	local hp,spr=3,3
	if(rnd()>0.9) hp,spr=10,4
		
	local e={
		x=0,
		y=0,
		spd_x=(rnd(1)-0.5)/4,
		spd_y=(rnd(1)-0.5)/4,
		space_x=x,
		space_y=y,
		hp=hp,
		hit_count=0,
		spr=spr
	}
	add(self.list,e)
end



-- <etc. functions> --------------------

function is_near(x1,y1,x2,y2,r)
	return abs(x2-x1)<=r and abs(y1-y1)<=r
end

function get_dist(x1,y1,x2,y2)
	return sqrt((x2-x1)^2+(y2-y1)^2)
end

--[[ function is_hit(x1,y1,r1,x2,y2,r2)
	local r=r1+r2
	if abs(x2-x1)>r or abs(y2-y1)>r then return false
	elseif sqrt((x2-x1)^2+(y2-y1)^2)<=r then return true end
	return false
end ]]

function add_explosion_eff(x,y,spd_x,spd_y)
	for i=1,16 do
		local sx=cos(i/16+rnd()*0.1)
		local sy=sin(i/16+rnd()*0.1)
		add(_space_f.particles,
		{
			type="explosion",
			x=x+rnd(3)-1.5,
			y=y+rnd(3)-1.5,
			sx=sx*(0.6+rnd()*1.4)+spd_x*0.7,
			sy=sy*(0.6+rnd()*1.4)+spd_y*0.7,
			age=1+round(rnd(10))
		})
		add(_space_f.particles,
		{
			type="explosion_dust",
			x=x+rnd(4)-2,
			y=y+rnd(4)-2,
			sx=sx*(1+rnd()*2)+spd_x,
			sy=sy*(1+rnd()*2)+spd_y,
			age=1+round(rnd(5))
		})
	end
end
function add_hit_eff(x,y,angle)
	for i=1,8 do
		--local a=angle+round(i/8)/2-0.25
		local a=angle+round(i/8)*0.8-0.4
		local sx=cos(a)
		local sy=sin(a)
		add(_space_f.particles,
		{
			type="hit",
			x=x+rnd(4)-2,
			y=y+rnd(4)-2,
			sx=sx*(1+rnd()*3),
			sy=sy*(1+rnd()*3),
			age=1+round(rnd(5))
		})
	end
end



-- <log, system info> --------------------

log_d=nil
log_counter=0
function log(...)
	local s=""
	for i,v in pairs{...} do
		s=s..v..(i<#{...} and "," or "")
	end
	if log_d==nil then log_d=s
	else log_d=sub(s.."\n"..log_d,1,200) end
	log_counter=3000
end
function print_log()
	if(log_d==nil or log_counter<=1) log_d=nil return
	log_counter-=1
	?log_d,2,2,0
	?log_d,1,1,8
end
function print_system_info()
	local cpu=round(stat(1)*10000)
	local mem=tostr(stat(0))
	local s=(cpu\100).."."..(cpu%100\10)..(cpu%10).."%"
	printa(s,126,2,0,1)
	printa(s,127,1,8,1)
	printa(mem,126,8,0,1) printa(mem,127,7,8,1)
end



-- <constants> ------------------------------------------------



--------------------------------------------------
f=0 -- every frame +1
dim_pal={} -- 이게 있으면 stage 렌더링 시작할 때 팔레트 교체
stage=sprite.new() -- scene graph top level object
cx,cy=64,64 -- space center

function _init()
	--music(13,2000,2)

	_space=space.new()
	_ship=ship.new()
	_enemies=enemies.new(16)
		
	stage:add_child(_space)
	stage:add_child(_ship)
	stage:add_child(_enemies)
	--[[ 
	_enemies={}
	for i=1,10 do
		local e=enemy.new(rnd(127)-64,rnd(127)-64)
		add(_enemies,e)
		stage:add_child(e)
	end
 ]]
	_space_f=space.new(true) -- front layer
	stage:add_child(_space_f)
end
function _update60()
	f+=1
	stage:emit_update()
end
function _draw()
	cls(0)
	pal()

	if(#dim_pal>0) pal(dim_pal,0)
	stage:render(0,0)

	-- 개발용
	if dev==1 then
		print_log()
		print_system_info()
	end
end