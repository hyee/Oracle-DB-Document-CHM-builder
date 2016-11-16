
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

local builder={}
function builder.new(self,dir,build)
	dir=dir:gsub('[\\/]+','\\'):gsub("\\$","")
	if dir:find(target_doc_root,1,true)==1 then dir=dir:sub(#target_doc_root+1) end
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
		o:startBuild()
	end
	return o
end

function builder.save(path,text)
	io.open(path,"w"):write(text)		
end

function builder.getContent(self,file)
	--print(file)
	local f=io.open(file,"r")
	if not f then return print('Unable to open file '..file) end
	local txt=f:read("*a")
	f:close() 
	--print(1)
	local title=txt:match([[<meta name="doctitle" content="([^"]+)"]])
	if not title then title=txt:match("<title>(.-)</title>") end
	title=title:gsub("%s*&reg;?%s*"," "):gsub("([\1-\127\194-\244][\128-\193])", '')
	local root=html.parse(txt):select("div[class^='IND']")
	return root and root[1] or {} ,title
end

function builder.buildIdx(self)
	local c=self:getContent(self.idx)
	if not c then return end
	local hhk=
	{[[<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN"><HTML><HEAD>
		<meta content="Microsoft HTML Help Workshop 4.1" name="GENERATOR">
		<!-- Sitemap 1.0 -->
	  </HEAD>
	  <BODY><UL>]]}
	local function append(level,txt)
		hhk[#hhk+1]='\n    '..string.rep("  ",level).. txt
	end

	local nodes=c:select("dd[class*='ix']")
	local tree={}
	local treenode={}
	for _,node in ipairs(nodes) do
		local level=tonumber(node.attributes.class:match('l(%d+)ix'))
		if level then
			local n={name=node:getcontent(),ref={}}
			local found=false
			for _,a in ipairs(node.nodes) do
				if a.name=='a' then
					if not found then found,n.name=true,n.name:gsub(',?%s<a.*','') end
					n.ref[#n.ref+1]=self.dir..'\\'..a.attributes.href
				end
			end
 			treenode[level]=n
			if level>1 then
				table.insert(treenode[level-1],n)
				if #treenode[level-1].ref==0 then treenode[level-1].ref=n.ref end
			else
				tree[#tree+1]=n
			end
		end
	end
	
	local function travel(level,node,parent)
		if not parent then
			for i=1,#node do 
				travel(level,node[i],node) 
			end
			return
		end
		if node.name~="" then
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
					for i=1,#node do travel(level+1,node[i],node) end
					append(level+1,'</UL></LI>')
				else
					append(level,'</OBJECT></LI>')
				end
			end
		end
	end
	travel(0,tree)
	append(0,"</UL></BODY></HTML>")
	self.hhk=self.name..".hhk"
	self.save(self.root..self.hhk,table.concat(hhk))
end

function builder.buildJson(self)
	self.hhc=self.root..self.name..".hhc"
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

	local f=io.open(self.json)
	if not f then
		local title,href
		if self.toc:lower():find('\\nav\\') then 
			self.topic='All Books for Oracle Database Online Documentation Library'
			href='portal_booklist.htm'
			self.toc=self.full_dir..'href.htm'
		else
			local _,title=self:getContent(self.toc)
			href='toc.htm'
			self.topic=title
		end
		append(1,"<LI><OBJECT type=\"text/sitemap\">")
		append(2,([[<param name="Name"  value="%s">]]):format(self.topic))
		append(2,([[<param name="Local" value="%s">]]):format(self.dir..'\\'..href))
		append(1,"</OBJECT></LI>")
		append(0,"</UL></BODY></HTML>")
		self.save(self.hhc,table.concat(hhc))
		return 
	end
	local txt=f:read("*a")
	f:close() 
	local root=json.decode(txt)
	local last_node
	local function travel(node,level)
		if node.t then
			node.t=node.t:gsub("([\1-\127\194-\244][\128-\193])", '')
			last_node=node.h
			append(level+1,"<LI><OBJECT type=\"text/sitemap\">")
			append(level+2,([[<param name="Name"  value="%s">]]):format(node.t))
			append(level+2,([[<param name="Local" value="%s">]]):format(self.dir..'\\'..node.h))
			if node.c then
				append(level+1,"</OBJECT><UL>") 
				for index,child in ipairs(node.c) do
					travel(child,level+1)
				end
				if level==0 and last_node and not last_node:lower():find('^index%.htm') then
					local f=io.open(self.idx,'r')
					if f then
						f:close()
						append(1,"<LI><OBJECT type=\"text/sitemap\">")
						append(2,[[<param name="Name"  value="Index">]])
						append(2,([[<param name="Local" value="%s">]]):format(self.dir..'\\index.htm'))
						append(1,"</OBJECT></LI>") 
					end
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
	travel(root.docs[1],0)
	
	append(0,"</UL></BODY></HTML>")
	self.save(self.hhc,table.concat(hhc))
	self.topic=root.docs[1].t
	return self.topic
end

function builder:listdir(this,dir,base,level,callback)
	local function parseHtm(file,level)
		if not file:lower():find("%.html?$") then return end
		local prefix=string.rep("%.%./",level)
		local f=io.open(file,'r')
		local txt=f:read("*a")
		local count=0
		f:close()
		txt,count=txt:gsub("\n(%s+parent%.document%.title)","\n//%1"):gsub("&amp;&amp;","&&")
		txt=txt:gsub('<header>.-</header>','')
		txt=txt:gsub('<footer>.*</footer>','')
		txt=txt:gsub('%s*<a href="#BEGIN".-</a>%s*','')
		txt=txt:gsub('href="'..prefix..'([^"]+)%.pdf"([^>]*)>PDF<',function(s,d)
			return [[href="javascript:location.href ='file:///'+location.href.match(/\:((\w\:)?[^:]+[\\/])[^:\\/]+\:/)[1]+']]..s:gsub("/",".")..[[.chm'"]]..d..'>CHM<'
		end)

		txt=txt:gsub('"('..prefix..[[[^"]-)([^"\/]+.html?[^"]*)"]],function(s,e)
			if e:find('.css',1,true) or e:find('.js',1,true) then return '"'..s..e..'"' end
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
			txt=txt:gsub([["%.%./([^%.][^"]-)([^"\/]+.html?[^"]*)"]],function(s,e)
				t=self.parent..'/'..s
				return '"MS-ITS:'..t:gsub("[\\/]+",".").."chm::/"..t:gsub("[\\/]+","/")..e..'"'
			end)
		end
		if not txt then print("file",file,"miss matched!") end
		local f=io.open(file,'w')
		f:write(txt)
		f:close()
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

function builder.buildHhp(self)
	local title=self.topic
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
	]],
		self.name,self.hhc,self.hhk,self.dir,self.title,title,self.name,
		title,self.hhc,self.hhk,self.dir,self.title,self.dir,self.title,self.name)}
	hhp[1]=hhp[1]:gsub("\n\t\t\t","\n")
	local function append(txt) hhp[#hhp+1]='\n'..txt end
	local _,depth=self.dir:gsub('[\\/]','')
	self:listdir(self.listdir,self.full_dir,self.dir..'\\',self.depth,append)
	self.save(self.root..self.name..".hhp",table.concat(hhp))
end

function builder:startBuild()
	print("building "..self.dir)
	self:buildIdx()
	self:buildJson()
	self:buildHhp()
end

function BuildJobs(parallel)
	local source,target=source_doc_root,target_doc_root
	local lst={"toc.htm","index.htm","title.htm"}
	local tasks={}
	local fd=sys.handle()
	local i=1
	for name,is_dir in sys.dir(source) do
		local found=false
		if is_dir then
			for n,isdir in sys.dir(source..name.."\\") do
				if isdir then
					local targetroot='"'..target..name.."\\"..n..'"'
					local sourceroot=source..name.."\\"..n.."\\"
					local flag=false
					for j=1,3 do
						local f=sourceroot..lst[j]
						if not fd:open(f,"r") then
							print(f,"not exists")
						elseif j<=2 then
							found,flag=true,true
						end
						fd:close()
					end
					if flag then
						os.execute("mkdir "..targetroot)
						os.execute('xcopy "'..sourceroot..'*" '..targetroot.." /E/Y/Q  /EXCLUDE:exclude.txt")
						o=builder:new(targetroot:sub(2,-2),1)
						local idx=math.fmod(i,parallel)+1
						if not tasks[idx] then tasks[idx]={} end
						tasks[idx][#tasks[idx]+1]='"'..chm_builder..'" "'..target..o.name..'.hhp"'
						i=i+1
					end
				end
			end
			if not found then
				local targetroot='"'..target..name..'"'
				local sourceroot=source..name.."\\"
				for j=1,3 do
					local f=sourceroot..lst[j]
					if not fd:open(f,"r") then
						print(f,"not exists")
					end
					fd:close()
				end
				os.execute("mkdir "..targetroot)
				os.execute('xcopy "'..sourceroot..'*" '..targetroot.." /E/Y/Q  /EXCLUDE:exclude.txt")
				if name~='dcommon' then 
					local o=builder:new(targetroot:sub(2,-2),1)
					local idx
					if name=='nav' then 
						idx=parallel+1
					else
						idx=math.fmod(i,parallel)+1
					end
					if not tasks[idx] then tasks[idx]={} end
					tasks[idx][#tasks[idx]+1]='"'..chm_builder..'" "'..target..o.name..'.hhp"'
					i=i+1
				end
			end
		end
	end
	os.execute('copy /Y html5.css '..target..'nav\\css')
	for i=1,#tasks do
		io.open(i..".bat","w"):write(table.concat(tasks[i],"\n"))
	end
	print('\nPlease run 1.bat -- 6.bat simulatenously to build the CHMs in parallel..')
end


function BuildBatch()
	local dir=target_doc_root
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
	hhclist=table.sort(hhclist,function(a,b)
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
	io.open("F:\\abc\\server.112.e10880.hhk","w"):write(table.concat(hhk,'\n'))
end
--builder:new([[appdev.112\e10764]],1)
BuildJobs(6)
--BuildBatch()
--parseErrorMsg()
--builder.listdir(builder.listdir,"f:\\abc\\nav\\","nav\\",1)