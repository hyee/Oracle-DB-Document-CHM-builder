local source_doc_root=[[f:\BM\E66230_01\]]
local target_doc_root=[[f:\BM\newdoc12\]]

--[[--FOR 11g
local source_doc_root='f:\\BM\\E11882_01\\'
local target_doc_root='f:\\BM\\newdoc11\\'
--]]

--[[
    (c)2016-2017 by hyee, MIT license, https://github.com/hyee/Oracle-DB-Document-CHM-builder

    .hhc/.hhk/.hhp files are all created under the root path

    .hhc => Content rules(buildJson): target.json
    .hhk => Index rules(buildIdx):
        1. Common books => index.htm:
            <dl> -> <dd[class='*ix']>content,<a[href]>
            <div> -> <ul> -> <li> -> <[ul|a]>
        2. Javadoc books(contains 'allclasses-frame.html') => index-all.html, index-files\index-[1-30].html:
            <a (href="*.html#<id>" | href="*.html" title=)>content</a>
        3. nav\[sql-keywords|catalog_views]*.htm -> key.json:
            <span> -> <b><a>
        4. Glossary => glossary.htm
            <p[class="glossterm"]>[content]<a[name|id])>[content]</a></p>
        5. Book Oracle Error messages(self.errmsg):
            <dt> -> (<span>->)? <a[name|id]>
        6. Book PL/SQL Packages Reference and APLEX API:
            target.json -> First word in upper-case
    .hhp => Project rules(buildHhp):
        1. Include all files
        2. Enable options: Create binary TOC/Create binary indexes/Compile full-text search/show MSDN menu
    HTML file substitution rules(processHTML):
        1. For javadoc, only replace all &lt/gt/amp as >/</& in javascript due to running into errors
        2. For others:
            1). Remove all <script>/<a[href="#BEGIN"]>/<header>/<footer> elements, used customized header instead
            2). For all 'a' element, remove all 'onclick' and 'target' attributes
            3). For all links that point to the top 'index.htm', replace as 'MS-ITS:index.chm::/index.htm'
            4). For all links that point to other books:
                a. Replace '.htm?<parameters>' as '.htm'
                b. Caculate the <relative_path> based on the root path and replace '\' as '.', assign as the <file_name>
                c. Final address is 'MS-ITS:<file_name>.chm::/<relative_path>/<html_file(#...)?>'
    Book list rules: all directories that contains 'toc.htm'

--]]

local chm_builder=[[C:\Program Files (x86)\HTML Help Workshop\hhc.exe]]
local plsql_package_ref={ARPLS=1,AEAPI=1,['appdev.112\\e40758']=1,['appdev.112\\e12510']=1}
local errmsg_book={ERRMG=1,['server.112\\e17766']=1}
local html=require("htmlparser")
local json=require("json")
local io,pairs,ipairs,math=io,pairs,ipairs,math
local global_keys,global_key_file=nil,target_doc_root..'key.json'

local reps={
    ["\""]="&quot;",
    ["<"]="&lt;",
    [">"]="&gt;"
}

local function rp(s) return reps[s] end
local function strip(str)
    return str:gsub("[\n\r\b]",""):gsub("^[ ,]*(.-)[ ,]*$", "%1"):gsub('<.->',''):gsub("  +"," "):gsub("[\"<>]",rp):gsub("%s*&reg;?%s*"," ")
end

local jcount={}
local builder={}
function builder.new(dir,build,copy)
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
        ver=errmsg_book==source_doc_root:find('E11882_01') and '11g' or '12c',
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
    if copy then
        local targetroot='"'..full_dir..'"'
        local sourceroot=source_doc_root..dir.."\\"
        local lst={"toc.htm","index.htm","title.htm"}
        for j=1,3 do builder.exists(sourceroot..lst[j]) end
        local exec=io.popen("mkdir "..targetroot..' 2>nul & xcopy "'..sourceroot..'*" '..targetroot.." /E/Y/Q  /EXCLUDE:exclude.txt")
        exec:close()
    end
    if builder.exists(full_dir.."title.htm",true) then 
        o.title="title.htm"
    else
        o.title="toc.htm"
    end
    if not global_keys then 
        global_keys=builder.read(global_key_file)
        if global_keys then 
            global_keys=json.decode(global_keys)
        else
            global_keys={}
        end
    end
    if builder.exists(full_dir..'allclasses-frame.html') then o.is_javadoc=true end
    setmetatable(o,builder)
    builder.__index=builder
    if build then 
        o:startBuild()
    end
    return o
end

function builder.read(file)
    local f,err=io.open(file,'r')
    if not f then
        return nil,err
    else
        local text=f:read('*a')
        f:close()
        return text
    end
end

function builder.exists(file,silent)
    local text,err=builder.read(file)
    return text
end

function builder.save(path,text)
    if type(path)=="table" then
        print(debug.traceback())
    end
    local f=io.open(path,"w")
    f:write(text)
    f:close()
end

function builder:getContent(file)
    local txt=self.exists(file)
    if not txt then return end
    local title=txt:match([[<meta name="doctitle" content="([^"]+)"]])
    if not title then title=txt:match("<title>(.-)</title>") end
    if title then title=title:gsub("%s*&reg;?%s*"," "):gsub("([\1-\127\194-\244][\128-\193])", ''):gsub('%s*|+%s*',''):gsub('&.-;','') end
    local root=html.parse(txt):select("div[class^='IND']")
    return root and root[1] or nil,title
end

function builder:buildGlossary(tree)
    local text=self.read(self.full_dir..'glossary.htm')
    if not text then return end
    local nodes=html.parse(text):select('p[class="glossterm"]')
    for _,p in ipairs(nodes) do
        local a=p.nodes[1]
        local ref=a.attributes.id or a.attributes.name
        if a.name=="a" and ref then
            local content=a:getcontent():gsub('%s+$','')
            if content=="" then
                content=p:getcontent():gsub('<.->',''):gsub('%s+$','')
            end
            tree[#tree+1]={name=content,ref={'glossary.htm#'..ref}}
        end
    end
end

function builder:buildIdx()
    local hhk={[[<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN"><HTML><HEAD>
        <meta content="Microsoft HTML Help Workshop 4.1" name="GENERATOR">
        <!-- Sitemap 1.0 -->
      </HEAD>
      <BODY><UL>]]}

    local c=self:getContent(self.idx)
    if not c and not self.errmsg and not self.is_javadoc and not global_keys[self.name] then return end

    local function append(level,txt)
        hhk[#hhk+1]='\n    '..string.rep("  ",level).. txt
    end

    local tree,sql_keys={},global_keys[self.name] or {}
    if self.errmsg then
        tree=self.errmsg
        print(#tree..' Error codes are indexed.')
    elseif self.is_javadoc then --process java-doc api
        local text=self.read(self.full_dir..'index-all.html')
        if not text then
            local f=io.popen('dir /s/b "'..self.full_dir..'index-*.htm*"')
            local files={}
            for path in f:lines() do files[#files+1]=self.read(path) end
            text=table.concat(files,'')
            if text=='' then text=nil end
        end
        if text then
            local nodes=html.parse(text):select("a")
            local addrs={}
            for idx,a in ipairs(nodes) do
                if a.attributes.href and a.attributes.href:find('.htm',1,true) then
                    local content=a:getcontent():gsub('<.->',''):gsub('%s+$','')
                    local ref=a.attributes.href:gsub('^%.[\\/]?',''):gsub('/','\\')
                    if ((ref:find('#',1,true) or 0)> 2 or a.attributes.title) and content~="" and not addrs[content..ref] then
                        addrs[content..ref]=1
                        tree[#tree+1]={name=content,ref={ref}}
                    end
                end
            end
        end
    elseif c then
        local nodes=c:select("dd[class*='ix']")
        local treenode={}
        for _,node in ipairs(nodes) do
            local level=tonumber(node.attributes.class:match('l(%d+)ix'))
            if level then
                local content=node:getcontent():gsub('%s+$','')

                local n={name=content:gsub('[%s,%.]*<.*>.*$','') ,ref={}}
                for _,a in ipairs(node:select("a")) do
                    n.ref[#n.ref+1]=a.attributes.href
                end
                treenode[level]=n
                if level>1 then
                    table.insert(treenode[level-1],n)
                    if #n.ref>0 then
                        for lv=1,level-1 do
                            if #treenode[lv].ref==0 then treenode[lv].ref=n.ref end
                        end
                    elseif content:lower():find('>see<',1,true) and #treenode[level-1].ref==0 then
                        treenode[level-1].ref[1]='#SEE#'..content:gsub('<.->',''):gsub('^%s*See%s*','')
                    end
                else
                    tree[#tree+1],sql_keys[n.name:upper()]=n,nil
                end
            end
        end

        if #nodes==0 then
            local uls=c:select("div > ul")
            local function access_childs(li,level)
                if li.name~="li" or not li.nodes[1] then return end
                local content=li:getcontent():gsub('^%s+','')
                local n={name=content:gsub('[%s,]+<.*>.*$',''),ref={}}
                if n.name=="" then return end
                if level==1 then 
                    tree[#tree+1],sql_keys[n.name:upper()]=n,nil
                elseif n.name=="about" then
                    level,n=level-1,treenode[level-1]
                else
                    table.insert(treenode[level-1],n)
                end
                treenode[level]=n
                
                local lis=li:select("li")
                if li.nodes[1].name~="ul" then
                    for _,a in ipairs(li:select("a")) do
                        n.ref[#n.ref+1]=a.attributes.href
                    end

                    if level>1 and #n.ref==0 and #treenode[level-1].ref==0 then
                        if content:lower():find('see.*:') then
                            treenode[level-1].ref[1]='#SEE#'..n.name:gsub('<.->',''):gsub('^.-:%s*','')
                        end
                    else
                        for lv=1,level-1 do
                            if #treenode[lv].ref==0 then treenode[lv].ref=n.ref end
                        end
                    end
                else
                    for _,child in ipairs(li.nodes[1].nodes) do
                        access_childs(child,level+1)
                    end
                end
            end

            for _,ul in ipairs(uls) do
                for _,li in ipairs(ul.nodes) do
                    access_childs(li,1)
                end
            end
        end
    end

    local counter=#tree
    self:buildGlossary(tree)
    if #tree>counter then
        print((#tree-counter)..' glossaries are indexed.')
        counter=#tree
    end

    for name,ref in pairs(sql_keys) do 
        tree[#tree+1]={name=ref[1],ref={ref[2]}}
    end

    if #tree>counter then
        print((#tree-counter)..' additional keywords are indexed.')
        counter=#tree
    end

    counter=0
    local function travel(level,node,parent)
        if not parent then
            for i=1,#node do 
                travel(level,node[i],node) 
            end
            return
        end
        if node.name~="" then
            for i=1,#node.ref do
                counter=counter+1
                append(level+1,"<LI><OBJECT type=\"text/sitemap\">")
                if node.ref[i]:find("^#SEE#")==1 then
                    append(level+2,([[<param name="Name"  value="%s">]]):format(node.name))
                    append(level+2,([[<param name="See Also" value="%s">]]):format(node.ref[i]:sub(6)))
                else
                    append(level+2,([[<param name="Name"  value="%s">]]):format(node.name))
                    append(level+2,([[<param name="Local" value="%s">]]):format(self.dir..'\\'..node.ref[i]))
                end
                if i==#node.ref and #node>0 then
                    append(level+1,'</OBJECT><UL>')
                    for i=1,#node do travel(level+1,node[i],node) end
                    append(level+1,'</UL>')
                else
                    append(level,'</OBJECT>')
                end
            end
        end
    end
    travel(0,tree)
    append(0,"</UL></BODY></HTML>")
    self.hhk=self.name..".hhk"
    self.save(self.root..self.hhk,table.concat(hhk))
    self.index_count=#tree..'/'..counter
    print('Totally '..self.index_count..' items are indexed.')
end

function builder:buildJson()
    self.hhc=self.name..".hhc"
    local hhc={
    [[<HTML><HEAD>
        <meta content="Microsoft HTML Help Workshop 4.1" name="GENERATOR">
        <!-- Sitemap 1.0 -->
      </HEAD>
      <BODY>
        <OBJECT type="text/site properties">
          <param name="Window Styles" value="0x800225">
          <param name="comment" value="title:Online Help">
          <param name="comment" value="base:toc.htm">
        </OBJECT><UL>]]}
    local function append(level,txt)
        hhc[#hhc+1]='\n    '..string.rep("  ",level*2).. txt
    end

    local txt=self.read(self.json)
    if not txt then
        local title,href
        if self.name:lower()=="nav" then 
            self.topic='All Books for Oracle Database Online Documentation Library'
            self.topic_count='5/5'
            href='portal_booklist.htm'
            self.toc=self.full_dir..href
            self.title=href
            append(1,[[<LI><OBJECT type="text/sitemap">
            <param name="Name" value="All Books for Oracle Database Online Documentation Library">
            <param name="Local" value="nav\portal_booklist.htm">
            <param name="ImageNumber" value="21">
          </OBJECT>
      <LI><OBJECT type="text/sitemap">
            <param name="Name" value="All Data Dictionary Views">
            <param name="Local" value="nav\catalog_views.htm">
            <param name="ImageNumber" value="21">
          </OBJECT>
      <LI><OBJECT type="text/sitemap">
            <param name="Name" value="All SQL, PL/SQL and SQL*Plus Keywords">
            <param name="Local" value="nav\sql_keywords.htm">
            <param name="ImageNumber" value="21">
          </OBJECT>
      <LI><OBJECT type="text/sitemap">
            <param name="Name" value="Master Glossary">
            <param name="Local" value="nav\mgloss.htm">
            <param name="ImageNumber" value="21">
          </OBJECT>
      <LI><OBJECT type="text/sitemap">
            <param name="Name" value="Master Index">
            <param name="Local" value="nav\mindx.htm">
            <param name="ImageNumber" value="21">
          </OBJECT>]])
        else
            local _,title=self:getContent(self.toc)
            href='toc.htm'
            self.topic=title
            if self.toc:find('e13993') or self.toc:find('JAFAN') then
                self.topic='Oracle Database RAC FAN Events Java API Reference'
            elseif self.toc:find('JAXML') then
                self.topic='Oracle Database XML Java API Reference'
            end
            append(1,"<LI><OBJECT type=\"text/sitemap\">")
            append(2,([[<param name="Name"  value="%s">]]):format(self.topic))
            append(2,([[<param name="Local" value="%s">]]):format(self.dir..'\\'..href))
            append(1,"</OBJECT>")
        end
       
        append(0,"</UL></BODY></HTML>")
        self.save(self.root..self.hhc,table.concat(hhc))
        print('Book:',self.topic)
        return 
    end
    local root=json.decode(txt)
    local counter,last_node,sql_keys=0
    if plsql_package_ref[self.dir] then print('Found PL/SQL API and indexing the content.') end
    local function travel(node,level)
        if node.t then
            node.t=node.t:gsub("([\1-\127\194-\244][\128-\193])", ''):gsub('%s*|+%s*',''):gsub('&.-;',''):gsub('\153',"'")
            last_node=node.h
            counter=counter+1
            append(level+1,"<LI><OBJECT type=\"text/sitemap\">")
            append(level+2,([[<param name="Name"  value="%s">]]):format(node.t))
            append(level+2,([[<param name="Local" value="%s">]]):format(self.dir..'\\'..node.h))
            if plsql_package_ref[self.dir] then
                local first=node.t:match('^[^%s]+')
                if not sql_keys then
                    sql_keys=global_keys[self.name] or {}
                    global_keys[self.name]=sql_keys
                end
                if first:upper()==first and level<4 then --index package name and method
                    sql_keys[node.t:upper()]={node.t,node.h}
                end
            end
            if node.c then
                append(level+1,"</OBJECT><UL>") 
                for index,child in ipairs(node.c) do
                    travel(child,level+1)
                end
                if level==0 and last_node and not last_node:lower():find('^index%.htm') then
                    if self.exists(self.idx,true) then
                        counter=counter+1
                        append(1,"<LI><OBJECT type=\"text/sitemap\">")
                        append(2,[[<param name="Name"  value="Index">]])
                        append(2,([[<param name="Local" value="%s">]]):format(self.dir..'\\index.htm'))
                        append(1,"</OBJECT>") 
                    end
                end
                append(level+1,"</UL>") 
            else
                append(level+1,"</OBJECT>") 
            end
        elseif #node>0 then
            for index,child in ipairs(node) do
                travel(child,level+1)
            end
        end

    end
    travel(root.docs[1],0)
    append(0,"</UL></BODY></HTML>")
    self.save(self.root..self.hhc,table.concat(hhc))
    self.topic=root.docs[1].t
    self.topic_count=#root.docs[1].c..'/'..counter
    print('Book:',self.topic)
    print('Totally '..self.topic_count..' topics are created.')
    return self.topic
end

function builder:processHTML(file,level)
    if not file:lower():find("%.html?$") then return end
    local prefix=string.rep("%.%./",level)
    local txt=self.read(file)
    if self.is_javadoc then
        txt=txt:gsub('(<script)(.-)(</script>)',function(a,b,c)
            return a..b:gsub('&lt;','>'):gsub('&amp;','&'):gsub('&gt;','<')..c
        end)
        self.save(file,txt)
        return
    elseif self.dir and errmsg_book[self.dir] then --deal with the error message book
        if not self.errmsg then self.errmsg={} end
        local doc=html.parse(txt):select("dt")
        local name=file:match("[^\\/]+$")
        for idx,node in ipairs(doc) do
            local a=node.nodes[1]
            if a.name~='a' and a.nodes[1] then node,a=a,a.nodes[1] end
            local ref=a.attributes.id or a.attributes.name
            if a.name=='a' and ref and not a.attributes.href then
                local content=node:getcontent():gsub('.*</a>%s*',''):gsub('<.->',''):gsub('%s+$',''):gsub('%s+',' ')
                if content:find(':') then
                    self.errmsg[#self.errmsg+1]={name=content:match('[^%s:]+'),ref={name..'#'..ref}}
                end
            end
        end
    end

    local count=0
    self.topic=self.topic or ""
    local dcommon_path=string.rep('../',level)..'dcommon'
    local header=[[<table summary="" cellspacing="0" cellpadding="0">
        <tr>
        <td align="left" valign="top"><b style="color:#326598;font-size:12px">%s<br/><i style="color:black">%s  Release 2</i></b></td>
        <td width="60" align="center" valign="top"><a href="index.htm"><img width="24" height="24" src="%s/gifs/index.gif" alt="Go to Index" /><br />
        <span class="icon">Index</span></a></td>
        <td width="70" align="center" valign="top"><a href="toc.htm"><img width="24" height="24" src="%s/gifs/doclib.gif" alt="Go to Documentation Home" /><br />
        <span class="icon">Content</span></a></td>
        <td width="80" align="center" valign="top"><a href="MS-ITS:nav.chm::/nav/portal_booklist.htm"><img width="24" height="24" src="%s/gifs/booklist.gif" alt="Go to Book List" /><br />
        <span class="icon">Book List</span></a></td>
        <td width="80" align="center" valign="top"><a href="MS-ITS:nav.chm::/nav/mindx.htm"><img width="24" height="24" src="%s/gifs/masterix.gif" alt="Go to Master Index" /><br />
        <span class="icon">Master Index</span></a></td>
        </tr>
        </table>]]
    header=header:format(self.topic:gsub("Oracle","Oracle&reg;"),(self.ver=='12c' and '12c' or '11g'),dcommon_path,dcommon_path,dcommon_path,dcommon_path)
    txt,count=txt:gsub("\n(%s+parent%.document%.title)","\n//%1"):gsub("&amp;&amp;","&&")
    txt,count=txt:gsub('%s*<header>.-</header>%s*','')
    txt=txt:gsub('%s*<footer>.*</footer>%s*','')
    txt=txt:gsub([[(%s*<script.-<%/script>%s*)]],'')
    txt=txt:gsub('%s*<a href="#BEGIN".-</a>%s*','')
    txt=txt:gsub('(<[^>]*) onload=".-"','%1')
    txt=txt:gsub([[(<a [^>]*)onclick=(["'"]).-%2]],'%1')
    txt=txt:gsub([[(<a [^>]*)target=(["'"]).-%2]],'%1')
    if count>0 then
        txt=txt:gsub('(<div class="IND .->)','%1'..header,1)
    end
    txt=txt:gsub('href="'..prefix..'([^"]+)%.pdf"([^>]*)>PDF<',function(s,d)
        return [[href="javascript:location.href='file:///'+location.href.match(/\:((\w\:)?[^:]+[\\/])[^:\\/]+\:/)[1]+']]..s:gsub("/",".")..[[.chm'"]]..d..'>CHM<'
    end)

    if level>0 then
        txt=txt:gsub([[(["'])]]..prefix..'index%.html?%1','%1MS-ITS:index.chm::/index.htm%1')
    end

    txt=txt:gsub('"('..prefix..'[^%.][^"]-)([^"\\/]+.html?[^"\\/]*)"',function(s,e)
        if e:find('.css',1,true) or e:find('.js',1,true) or s:find('dcommon') then return '"'..s..e..'"' end
        local t=s:gsub('^'..prefix,'')
        if t=='' then return '"'..s..e..'"' end
        e=e:gsub('(html?)%?[^#]+','%1')
        return '"MS-ITS:'..t:gsub("/",".").."chm::/"..t..e..'"'
    end)

    if level==2 and self.parent then
        txt=txt:gsub([["%.%./([^%.][^"]-)([^"\/]+.html?[^"\/]*)"]],function(s,e)
            t=self.parent..'/'..s
            e=e:gsub('(html?)%?[^#]+','%1')
            return '"MS-ITS:'..t:gsub("[\\/]+",".").."chm::/"..t:gsub("[\\/]+","/")..e..'"'
        end)
    end

    if self.name and self.name:lower()=="nav" and (file:find('sql_keywords',1,true) or file:find('catalog_views',1,true)) then
        for _,span in ipairs(html.parse(txt):select("span")) do
            local b,a=span.nodes[1],span.nodes[2]
            if a and b.name=='b' and a.name=='a' and (a.attributes.href or ""):find('MS-ITS',1,true) then
                local index_name=b:getcontent():gsub('[:%s]+$','')
                local book,href=a.attributes.href:match('MS%-ITS:(.+)%.chm::/(.+)')
                if not global_keys[book] then global_keys[book]={} end
                global_keys[book][index_name:upper()]={index_name,href:sub(#book+2):gsub('/','\\')}
            end
        end
    end
    if not txt then print("file",file,"miss matched!") end
    self.save(file,txt)
end

function builder:listdir(base,level,callback)
    local root=target_doc_root..base
    local f=io.popen(([[dir /b/s %s*.htm]]):format(root))
    for file in f:lines() do
        local _,depth=file:sub(#root+1):gsub('[\\/]','')
        self:processHTML(file,level+depth)
        if callback then callback(file:sub(#target_doc_root+1),root,level+depth) end
    end
    f:close()
    --if self.errmsg then self:buildIdx() end
end

function builder:buildHhp()
    local title=self.topic
    local hhp=string.format([[[OPTIONS]
        Binary TOC=No
        Binary Index=Yes
        Topics=%s
        Indexes=%s
        Compiled File=%s.chm
        Contents File=%s
        Index File=%s
        Default Window=main
        Default Topic=%s\%s
        Default Font=
        Full-text search=Yes
        Auto Index=Yes
        Enhanced decompilation=Yes
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
        self.topic_count or '1/1',self.index_count or '0/0',self.name,self.hhc,self.hhk,self.dir,self.title,title,self.name,
        title,self.hhc,self.hhk,self.dir,self.title,self.dir,self.title,self.name)
    hhp=hhp..table.concat(self.filelist,'\n')
    local _,depth=self.dir:gsub('[\\/]','')
    self.save(self.root..self.name..".hhp",hhp:gsub('[\n\r]+%s+','\n'))
    if self.name:lower()=='nav' then
        os.execute('copy /Y html5.css '..target_doc_root..'nav\\css') 
        self.save(global_key_file,json.encode(global_keys))
    end
end

function builder:startBuild()
    print(string.rep('=',100).."\nBuilding "..self.dir..'...')
    self.filelist={}
    if not self.dir:find('dcommon') then self:buildJson() end 
    self:listdir(self.dir..'\\',self.depth,function(item) table.insert(self.filelist,item) end)
    if not self.dir:find('dcommon') then
        self:buildIdx()
        self:buildHhp()
    end
end

function builder.BuildAll(parallel)
    local tasks={}
    local fd=io.popen(([[dir /s/b "%stoc.htm"]]):format(source_doc_root))
    local book_list={"nav"}
    for dir in fd:lines() do
        local name=dir:sub(#source_doc_root+1):gsub('[\\/][^\\/]+$','')
        if name~="nav" then book_list[#book_list+1]=name end
    end
    fd:close()
    os.remove(global_key_file)
    builder.new('dcommon',true,true)
    for i,book in ipairs(book_list) do
        local this=builder.new(book,true,true)
        local idx=math.fmod(i-1,parallel)+1
        if i==1 then-- for nav
            idx=parallel+1 
        end
        if not tasks[idx] then tasks[idx]={} end
        local obj='"'..chm_builder..'" "'..target_doc_root..this.name..'.hhp"'
        if errmsg_book[book] then
            tasks[idx][#tasks[idx]+1]=obj
        else
            table.insert(tasks[idx],1,obj)
        end
    end
    table.insert(tasks[#tasks],'"'..chm_builder..'" "'..target_doc_root..'index.hhp"')
    for i=1,#tasks do
        builder.save(i..".bat",table.concat(tasks[i],"\n")..'\nexit\n')
        if i<=parallel then
            os.execute('start "Compiling CHMS '..i..'" '..i..'.bat')
        end
    end
    print('Since compiling nav.chm takes longer time, please execute '..(parallel+1)..'.bat separately if necessary.')
    builder.BuildBatch()
end

function builder.BuildBatch()
    local dir=target_doc_root
    builder.topic='Oracle 12c Documents(E66230_01)'
    if source_doc_root:find('E11882_01') then
        builder.topic='Oracle 11g Documents(E11882_01)'
    end
    builder.save(dir..'index.htm',builder.read(source_doc_root..'index.htm'))
    builder.processHTML(builder,dir..'index.htm',0)
    local hhc=[[<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<HTML>
<HEAD>
<meta name="generator" content="Microsoft&reg; HTML Help Workshop 4.1">
<!-- Sitemap 1.0 -->
</head>
<body>
   <OBJECT type="text/site properties">
     <param name="Window Styles" value="0x800225">
     <param name="comment" value="title:Online Help">
     <param name="comment" value="base:index.htm">
   </OBJECT>
   <UL>
      <LI><OBJECT type="text/sitemap">
            <param name="Name" value="Portal">
            <param name="Local" value="index.htm">
            <param name="ImageNumber" value="13">
          </OBJECT>
      <LI><OBJECT type="text/sitemap">
            <param name="Name" value="CHM File Overview">
            <param name="Local" value="chm.htm">
            <param name="ImageNumber" value="39">
          </OBJECT>
   </UL>
]]
    local hhk=[[
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<HTML>
<HEAD>
<meta name="generator" content="Microsoft&reg; HTML Help Workshop 4.1">
<!-- Sitemap 1.0 -->
<BODY>
   <OBJECT type="text/site properties">
     <param name="Window Styles" value="0x800025">
     <param name="comment" value="title:Online Help">
     <param name="comment" value="base:index.htm">
   </OBJECT>
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
        Enhanced decompilation=Yes
        Language=
        Title=]]..builder.topic..[[
        Create CHI file=No
        Compatibility=1.1 or later
        Error log file=..\_errorlog.txt
        Full text search stop list file=
        Display compile progress=Yes
        Display compile notes=Yes

        [WINDOWS]
        main="]]..builder.topic..[[","index.hhc","index.hhk","index.htm","index.htm",,,,,0x33520,222,0x101846,[10,10,800,600],0xB0000,,,,,,0

        [FILES]
        index.htm
        chm.htm

        [MERGE FILES]
        ]]
    local hhclist={}
    local f=io.popen(([[dir /b "%s*.hhc"]]):format(dir))
    for name in f:lines() do
        local n=name:sub(-4)
        local c=name:sub(1,-5)
        if n==".hhc" and name~="index.hhc" then
            local txt=builder.read(dir..c..".hhp")
            local title=txt:match("Title=([^\n]+)")
            hhclist[#hhclist+1]={file=c,title=title,chm=c..".chm",topic_count=txt:match("Topics=([^\n]+)"),index_count=txt:match("Indexes=([^\n]+)")}
        end
    end
    f:close()

    table.sort(hhclist,function(a,b) return a.title<b.title end)

    local html={'<table border><tr><th align="left">CHM File Name</th><th>Topics</th><th>Indexes</th><th align="left">Book Name</th></tr>'}
    local row=[[<tr><td><a href="javascript:location.href='file:///'+location.href.match(/\:((\w\:)?[^:]+[\\/])[^:\\/]+\:/)[1]+'%s'">%s</a></td><td>%s</td><td>%s</td><td>%s</td></tr>]]
    local item='   <OBJECT type="text/sitemap">\n     <param name="Merge" value="%s.chm::/%s.hhc">\n   </OBJECT>\n'
    for i,book in ipairs(hhclist) do
        html[#html+1]=row:format(book.chm,book.chm,book.topic_count or 'N/A',book.index_count or 'N/A',book.title)
        hhc=hhc..(item):format(book.file, book.file)
        hhp=hhp..book.chm.."\n"
    end
    html=table.concat(html,'\n')..'</table><br/><p style="font-size:12px">@2016 by hyee https://github.com/hyee/Oracle-DB-Document-CHM-builder</p>'
    
    hhc=hhc..'</BODY></HTML>'
    builder.save(dir.."chm.htm",html)
    builder.save(dir.."index.hhp",hhp:gsub('[\n\r]+%s+','\n'))
    builder.save(dir.."index.hhc",hhc)
    builder.save(dir.."index.hhk",hhk)
end

function builder.scanInvalidLinks()
    local max_books=3
    local f=io.popen('dir /s/b "'..target_doc_root..'*errorlog.txt"')
    for file in f:lines() do
        local filelist={}
        local txt,err=builder.read(file)
        if txt then
            for book in txt:gmatch('[\n\r]([%w%.]+)\\%w') do
                if not filelist[book] then
                    filelist[book],filelist[#filelist+1]=book,book
                end
                if #filelist>max_books then
                    print('Detected book '..book..' may contains invalid links: '..table.concat(filelist,','))
                end
            end
        else
            print(err)
        end
    end
end

local arg={...}
if arg[1] then
    local p=tonumber(arg[1])
    if p==0 then
        builder.BuildBatch()
    elseif p==-1 then
        builder.scanInvalidLinks()
    elseif p and p>0 then 
        builder.BuildAll(p)
    else
        builder.new(arg[1],true,true)        
    end        
end

--builder.new('ERRMG',1,1)
--builder.BuildAll(6)
--builder.BuildBatch()