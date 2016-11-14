require "lom"
require "base"
require "sys"
require "math"
local html=require("htmlparser")
local json=require("json")
local io,pairs,ipairs=io,pairs,ipairs
local chm_builder='C:\\Program Files (x86)\\HTML Help Workshop\\hhc.exe'
local source_doc_root='f:\\BM\\E11882_01\\'
local target_doc_root='f:\\BM\\newdoc11\\'


--local function print(txt)

local reps={
	["\""]="&quot;",
	["<"]="&lt;",
	[">"]="&gt;"
}
function rp(s) return reps[s] end
function strip(str)
	return str:gsub("[\n\r\b]",""):gsub("^[ ,]*(.-)[ ,]*$", "%1"):gsub("  +"," "):gsub("[\"<>]",rp):gsub("%s*&reg;?%s*"," ")
end


local jcount={}

local xmlParser={}
function xmlParser.new(self,dir,build)
	dir=dir:gsub('[\\/]+','\\'):gsub("\\$","")
	local _,depth,parent,folder=dir:gsub('[\\/]','')
	depth=depth and depth+1 or 1
	if depth>1 then
		parent,folder=dir:match('^(.+)\\([^\\]+)$')
	else
		folder=dir
	end
	local full_dir=target_doc_root..dir..'\\'
	local o={
		toc=full_dir..'toc.htm',
		json=full_dir..'target.json',
		idx=full_dir..'index.htm',
		hhc="",
		hhk="",
		depth=depth,
		root=target_doc_root,
		dir=dir,
		full_dir=full_dir,
		parent=parent,
		folder=folder,
		name=dir:gsub("[\\/]+",".")}
	local fd = sys.handle()
	if fd:open(full_dir.."title.htm","r") then 
		o.title="title.htm" 
	else
		o.title="toc.htm"
	end 
	fd:close()
	setmetatable(o,self)
	self.__index=self
	if build then 
		o:buildJson()

	end
	return o
end

function xmlParser.save(path,text)
	io.open(path,"w"):write(text)		
end


function xmlParser.getContent(self,file)
	--print(file)
	local f=io.open(file,"r")
	if not f then return print('Unable to open file '..file) end
	local txt=f:read("*a")
	f:close() 
	--print(1)
	local title=txt:match([[<meta name="doctitle" content="([^"]+)"]])
	if not title then title=txt:match("<title>(.-)</title>") end
	title=title:gsub("%s*&reg;?%s*"," ")
	local root=html.parse(txt):select("div[class^='IND']")
	return root and root[1] or {} ,title
end

function xmlParser.buildIdx(self)
	local c=self:getContent(self.idx)
	if not c then return end
	local function normalize(node,this,parent,idx)
		local i=1
		node.name=""
		node.ref={}
		while true do
			if i>#node then break end
			if type(node[i])=="string" then
				node.name=strip(node.name..' '..node[i])
				nodele.remove(node,i)
				i=i-1
			else
				if node[i].tag~="dl" and node[i].tag~="dd" and not parent then
					nodele.remove(node,i)
					i=i-1
				else
					i=i-(this(node[i],this,node,i) or 0)
					--if this(node[i],this,node,i)==1 then i=i-1 
				end
			end
			i=i+1
		end
		if parent and node.attributes and node.attributes.href then
			if node.attributes.href:sub(1,1)~="#" then
				parent.ref[#parent.ref+1]=self.dir.."\\"..node.attributes.href
			end
			nodele.remove(parent,idx)
			return 1
		end
		
		if parent and node.tag~="dd" and node.tag~="dl" then
			if node.name:lower():find("see") then
				parent.name="#SEE#"..parent.name
			else 
				parent.name=strip(parent.name.." "..node.name)
			end
			nodele.remove(parent,idx)
			return 1
		end
		
		node.attributes=nil
		if node.tag=="dd" and node.name=="" and parent[idx-1].tag=="dd" then
			for j=1,#node.ref do parent[idx-1].ref[#parent[idx-1].ref+1]=node.ref[j] end
			for j=1,#node do parent[idx-1][#parent[idx-1]+1]=node[j] end
			nodele.remove(parent,idx)
			return 1
		end
		
		if node.tag=="dl" then
			nodele.remove(parent,idx)
			for j=1,#node do nodele.insert(parent,idx-1+j,node[j]) end
			return 1-#node
		end
	end
	
	normalize(c,normalize)
	local hhk={[[
		<HTML><HEAD>
			<meta content="Microsoft HTML Help Workshop 4.1" name="GENERATOR">
			<!-- Sitemap 1.0 -->
		  </HEAD>
		  <BODY>
			<OBJECT type="text/site properties">
			  <param name="Window Styles" value="0x800025">
			</OBJECT><UL>]]}
	local function append(level,txt)
		hhk[#hhk+1]='\n				'..string.rep("  ",level).. txt
	end
	local function Build(level,node,this,parent)
		if not parent then
			for i=1,#node do this(level,node[i],this,node) end
			return
		end
		if node.name~="" then
			if #node.ref==0 then
				if #node==0 then
					node.ref[1]='#'
				else
					node.ref[1]=node[1].ref[1] or '#'
				end
			end
			for i=1,#node.ref do
				append(level+1,"<LI><OBJECT type=\"text/sitemap\">")
				if node.name:find("^#SEE#")==1 then
					node.name=node.name:sub(6)
					append(level+2,([[<param name="Name"  value="%s">]]):format("See Also "..node.name))
					append(level+2,([[<<param name="See Also" value="%s">]]):format(node.name))
				else
					append(level+2,([[<param name="Name"  value="%s">]]):format(node.name))
					append(level+2,([[<param name="Local" value="%s">]]):format(node.ref[i]))
				end
				if i==#node.ref and #node>0 then
					append(level+1,'</OBJECT><UL>')
					for i=1,#node do this(level+1,node[i],this,node) end
					append(level+1,'</UL></LI>')
				else
					append(level,'</OBJECT></LI>')
				end
			end
			
		end
	end
	Build(0,c,Build)
	append(0,"</UL></BODY></HTML>")
	self.hhk=self.name..".hhk"
	self.save(self.root..self.hhk,nodele.concat(hhk))
	self.save(self.root..self.hhk..".txt",nodele.concat(hhk))
end

function xmlParser.buildJson(self)
	local f=io.open(self.json)
	if not f then return end
	local txt=f:read("*a")
	f:close() 
	local root=json.decode(txt)
	local hhc={
    [[<HTML><HEAD>
		<meta content="Microsoft HTML Help Workshop 4.1" name="GENERATOR">
		<!-- Sitemap 1.0 -->
	  </HEAD>
	  <BODY>
		<OBJECT type="text/site properties">
		  <param name="Window Styles" value="0x800025">
		  <param name="comment" value="title:Online Help">
     	  <param name="comment" value="base:toc.htm">
		</OBJECT><UL>]]}
	local function append(level,txt)
		hhc[#hhc+1]='\n    '..string.rep("  ",level*2).. txt
	end
	local function travel(node,level)
		if node.t then
			node.t=node.t:gsub("[\1-\127\194-\244][\128-\193]", "")
			append(level+1,"<LI><OBJECT type=\"text/sitemap\">")
			append(level+2,([[<param name="Name"  value="%s">]]):format(node.t:gsub('®','')))
			append(level+2,([[<param name="Local" value="%s">]]):format(self.dir..'\\'..node.h))

			if node.c then
				append(level+1,"</OBJECT><UL>") 
				for index,child in ipairs(node.c) do
					travel(child,level+1)
				end
				append(level+1,"</UL></LI>") 
			else
				append(level+1,"</OBJECT></LI>") 
			end
		elseif #node>0 then
			for index,child in ipairs(node) do
				travel(child,level+1)
			end
		end
	end
	local title=root.docs[1].t
	travel(root.docs[1],0)
	append(0,"</UL></BODY></HTML>")
	self.hhc=self.name..".hhc"
	self.save(self.root..self.hhc,table.concat(hhc))
	self.save(self.root..self.hhc..".txt",table.concat(hhc))
	--self:listdir(self.listdir,self.full_dir,self.dir..'\\',self.depth)
	return title
end

function xmlParser.buildToc(self)
	local c,title=self:getContent(self.toc)
	if not c then return end
	
	local hhc={[[
		<HTML><HEAD>
			<meta content="Microsoft HTML Help Workshop 4.1" name="GENERATOR">
			<!-- Sitemap 1.0 -->
		  </HEAD>
		  <BODY>
			<OBJECT type="text/site properties">
			  <param name="Window Styles" value="0x800025">
			</OBJECT><UL>]]}
	local function append(level,txt)
		hhc[#hhc+1]='\n				'..string.rep("  ",level).. txt
	end
		
	local function normalize(level,node,this,parent,idx)
		local i=1
		node.name=""
		while true do
			if i>#node then break end
			if type(node[i])=="string"  then
				node.name=strip(node.name..' '..node[i])
				nodele.remove(node,i)
				i=i-1
			else
				if node[i].tag=="script" then 
					nodele.remove(node,i);i=i-1
				else
					i=i-(this(level+1,node[i],this,node,i) or 0)
				end
			end
			i=i+1
		end			
		if not node.tag:find("^[hul][%dli]$") and parent then
			if node.name~="" then parent.name=strip(parent.name.." "..node.name) end
			if node.attributes and node.attributes.href and node.attributes.href~="" then 
				parent.href=self.dir.."\\"..strip(node.attributes.href) 
			end
			nodele.remove(parent,idx)
			return 1
		end
		node.attributes=nil
		if node.tag=="ul" then
			for i=1,#node do
				nodele.remove(parent,idx)
				if level>1 then
					for i=1,#node do nodele.insert(parent,idx-1+i,node[i]) end
					return 1-#node
				else
					for i=1,#node do parent[idx-1][#parent[idx-1]+1]=node[i] end
					return 1
				end
			end
		end
	end
	normalize(0,c,normalize)
	c.name=title
	c.href=self.toc
	c[#c+1]={
		name="Build-in CHM files",
		href=self.name..".hhp.txt",
		tag="h2",
		[1]={name="hhc",href=self.name..".hhc.txt",tag="li"}}
	
	if self.hhk~=""	 then c[#c][2]={name="hhk",href=self.name..".hhk.txt",tag="li"} end
	local function Build(level,node,this)
		if node.name~="" and node.href then
			append(level+1,"<LI><OBJECT type=\"text/sitemap\">")
			append(level+2,([[<param name="Name"  value="%s">]]):format(node.name))
			append(level+2,([[<param name="Local" value="%s">]]):format(node.href))
			if #node>0 then 
				append(level+1,"</OBJECT><UL>") 
				for i=1,#node do  this(level+1,node[i],this) end
				append(level+1,"</UL></LI>") 
			else
				append(level+1,"</OBJECT></LI>") 
			end
		end
	end
	Build(0,c,Build)
	append(0,"</UL></BODY></HTML>")
	self.hhc=self.name..".hhc"
	self.save(self.root..self.hhc,nodele.concat(hhc))
	self.save(self.root..self.hhc..".txt",nodele.concat(hhc))
	--self.save("d:\\1.txt",prettytostring(c))
end

function xmlParser:listdir(this,dir,base,level,callback)
	local fd=sys.handle()
	local function parseHtm(file,level)
		if not file:lower():find("%.html?$") then return end
		local prefix=string.rep("%.%./",level)
		local txt=fd:open(file,"r"):read("*a")
		local count=0
		fd:close()
		txt,count=txt:gsub("\n(%s+parent%.document%.title)","\n//%1"):gsub("&amp;&amp;","&&")
		txt=txt:gsub('<header>.-</header>','')
		txt=txt:gsub('href="'..prefix..'([^"]+)%.pdf"([^>]*)>PDF<',function(s,d)
			return [[href="javascript:location.href ='file:///'+location.href.match(/\:((\w\:)?[^:]+[\\/])[^:\\/]+\:/)[1]+']]..s:gsub("/",".")..[[.chm'"]]..d..'>CHM<'
		end)

		txt=txt:gsub('"('..prefix..[[[^"]-)([^"\/]+)"]],function(s,e)
			if s:find(prefix.."dcommon/")==1 or s:find(prefix.."nav/")==1 or s==prefix:gsub("%%","") then return '"'..s..e..'"' end
			local n=prefix:gsub("%%",""):len()
			local t=s:sub(n+1)
			if t:find("^nav/") then 
				t="nav/"
			else
				t=t:match("^[^/]+/[^/]+/")
			end
			if not t then return '"'..s..e..'"' end
			return '"MS-ITS:'..t:gsub("/",".").."chm::"..s:sub(n)..e..'"'
		end)

		if level==2 then
			print(file)
			txt=txt:gsub([["%.%./([^%.][^"]-)([^"\/]+)"]],function(s,e)
				t=self.parent..'/'..s
				return '"MS-ITS:'..t:gsub("[\\/]+",".").."chm::/"..t:gsub("[\\/]+","/")..e..'"'
			end)
		end
		if not txt then print("file",file,"miss matched!") end
		fd:open(file,"w"):write(txt or "")
		fd:close()
	end

	for name,is_dir in sys.dir(dir) do
		if is_dir then
			this(this,dir..name.."\\",base..name.."\\",level+1)
		else
			parseHtm(dir..name,level)
			if callback then callback(base..name,dir) end
		end
	end
end

function xmlParser.buildHhp(self)
	local _,title=self:getContent(self.toc)
	local hhp={string.format([[
	
		[OPTIONS]
		Binary TOC=Yes
		Binary Index=Yes
		Compiled File=%s.chm
		Contents File=%s
		Index File=%s
		Default Window=main
		Default Topic=%s\%s
		Default Font=
		Full-text search=Yes
		Auto Index=Yes
		Language=
		Title=%s
		Create CHI file=No
		Compatibility=1.1 or later
		Error log file=%s_errorlog.txt
		Full text search stop list file=
		Display compile progress=Yes
		Display compile notes=Yes

		[WINDOWS]
		main="%s","%s","%s","%s\%s","%s\%s",,,,,0x33520,222,0x70384E,[10,10,800,600],0xB0000,,,,,,0
		[FILES]
		%s.hhp.txt
		index.htm]],
		self.name,self.hhc,self.hhk,self.dir,self.title,title,self.name,
		title,self.hhc,self.hhk,self.dir,self.title,self.dir,self.title,self.name)}
	hhp[1]=hhp[1]:gsub("\n\t\t\t","\n")
	local function append(txt) hhp[#hhp+1]='\n'..txt end
	local _,depth=self.dir:gsub('[\\/]','')
	self:listdir(self.listdir,self.full_dir,self.dir..'\\',self.depth,append)
	self.save(self.root..self.name..".hhp",nodele.concat(hhp))
	self.save(self.root..self.name..".hhp.txt",nodele.concat(hhp))
end

function xmlParser.startBuild(self)
	print("building "..self.dir)
	self:buildIdx()
	self:buildToc()
	self:buildHhp()
end


function BuildJobs(source,target,parallel)
	local lst={"toc","index","title"}
	local tasks={}
	local fd=sys.handle()
	local i=1
	for name,is_dir in sys.dir(source) do
		if is_dir and name~="nav" then
			for n,isdir in sys.dir(source..name.."\\") do
				if isdir then
					local targetroot='"'..target..name.."\\"..n..'"'
					local sourceroot=source..name.."\\"..n.."\\"
					os.execute("mkdir "..targetroot)
					os.execute('xcopy "'..sourceroot..'*" '..targetroot.." /E/Y/Q  /EXCLUDE:exclude.txt")
					for i=1,3 do
						local f=sourceroot..lst[i]..".htm"
						if not fd:open(f,"r") then
							print(f,"not exists")
						end
						fd:close()
					end
					o=xmlParser:new(targetroot:sub(2,-2),1)
					local idx=math.fmod(i,parallel)+1
					if not tasks[idx] then tasks[idx]={} end
					tasks[idx][#tasks[idx]+1]='"'..chm_builder..'" "'..target..o.name..'.hhp"'					i=i+1
				end
			end
		end
	end
	
	for i=1,#tasks do
		io.open(i..".bat","w"):write(nodele.concat(tasks[i],"\n").."\npause")
	end
end

--dirÊÇÄ¿±êÄ¿Â¼
function BuildBatch(dir)
	local hhc=[[
	
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<HTML>
<HEAD>
<meta name="GENERATOR" content="Microsoft&reg; HTML Help Workshop 4.1">
<!-- Sitemap 1.0 -->
</HEAD>
<BODY>
	]]
	local hhk=[[
</HEAD>
<BODY>
<OBJECT type="text/site properties">
	<param name="FrameName" value="right">
</OBJECT>
<UL>
	<LI> <OBJECT type="text/sitemap">
		<param name="Name" value="copyright">
		<param name="Local" value="dcommon\html\cpyr.htm">
		</OBJECT>
</UL>
</BODY>
</HTML>
	]]
	local hhp=[[

	
[OPTIONS]
Binary TOC=No
Binary Index=Yes
Compiled File=index.chm
Contents File=index.hhc
Index File=index.hhk
Default Window=main
Default Topic=index.htm
Default Font=
Full-text search=Yes
Auto Index=Yes
Language=
Title=Oracle 11G Documents
Create CHI file=No
Compatibility=1.1 or later
Error log file=..\_errorlog.txt

[WINDOWS]
main="Oracle 11G Documents(E11882_01)","index.hhc","index.hhk","index.htm","index.htm",,,,,0x33520,222,0x101846,[10,10,800,600],0xB0000,,,,,,0

[FILES]
index.htm

[MERGE FILES]
]]
	local hhclist={}
	for name,is_dir in sys.dir(dir) do
		if not is_dir then 
			local n=name:sub(-4)
			local c=name:sub(1,-5)
			if n==".hhc" and name~="index.hhc" then hhclist[#hhclist+1]=c end
		end
	end
	hhclist=nodele.sort(hhclist,function(a,b)
		x=io.open(dir..a..".hhp","r"):read("*a"):match("Title=([^\n]+)")
		y=io.open(dir..b..".hhp","r"):read("*a"):match("Title=([^\n]+)")
		return x<y
	end
	)
	for i=1,#hhclist do
		hhc=hhc..('<OBJECT type="text/sitemap"><param name="Merge" value="%s.chm::/%s.hhc"></OBJECT>\n'):format(hhclist[i],hhclist[i])
		hhp=hhp..hhclist[i]..".chm\n"
	end
	io.open(dir.."index.hhp","w"):write(hhp)
	io.open(dir.."index.hhc","w"):write(hhc)
	io.open(dir.."index.hhk","w"):write(hhk)
end

function parseErrorMsg()
	local dir="F:\\abc\\server.112\\e10880\\"
	local hhk={[[
	<HTML><HEAD>
		<meta content="Microsoft HTML Help Workshop 4.1" name="GENERATOR">
		<!-- Sitemap 1.0 -->
	  </HEAD>
	  <BODY>
		<OBJECT type="text/site properties">
		  <param name="Window Styles" value="0x800025">
		</OBJECT><UL>]]}
	for name,is_dir in sys.dir(dir) do
		if not is_dir and name:find("%.html?$") then
			local txt=io.open(dir..name,"r"):read("*a")
			for k in txt:gmatch([[<a%s+name="([^"]+%-%d+)"]]) do
				hhk[#hhk+1]=string.format([[
			<LI><OBJECT type="text/sitemap">
			  <param name="Name" value="%s">
			  <param name="Local" value="server.112\e10880\%s#%s">
			</OBJECT></LI>]],k,name,k)
			end
		end
	end
	hhk[#hhk+1]="</UL></BODY></HTML>"
	io.open("F:\\abc\\server.112.e10880.hhk","w"):write(nodele.concat(hhk,'\n'))
end
xmlParser:new([[server.112\e11013]],1)
--BuildJobs("f:\\BM\\E11882_01\\","f:\\BM\\newdoc11\\",6)
--BuildBatch("D:\\BM\\newdoc\\")
--parseErrorMsg()
--xmlParser.listdir(xmlParser.listdir,"f:\\abc\\nav\\","nav\\",1)