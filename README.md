# Oracle-DB-Document-CHM-builder
Generate Oracle database 11g/12c online documentations into offline CHM file set. 
<br/>Features:
* One book per CHM file, can be used separately, refer to `index.chm->CHM File Overview`
* `index.chm` to combine the contents and indexes of all books
* Supports cross-books searching
* Portable and no depedency in all Windows platforms

# Histories
* 2017-11-15: added some books: ZRLRA,Key Vault,BigData,Audit Vault,Airline,R Enterprise,ExaLogic
* 2017-11-09: added prev/next navications; enhancement on building contents 
* 2017-11-07: updated to latest docs 
* 2017-10-18: added 12.1 documentations 
* 2017-10-15: somes fixes on the page layouts; updated to the latest documents; included Exadata into 12.2 documents 
* 2016-11-16: initial draft

# Available Prebuilt CHM Books:
Refer to https://pan.baidu.com/s/1hrTfE9e <br/> or OneDrive: https://1drv.ms/f/s!Akx26bLmnboFki7M-Pkf39TpWoRc


# Screen-shots
![startup](img/default.jpg)<br/>
![search](img/index.jpg)<br/>
![files](img/filelist.jpg)<br/>

# Dependencies
All dependent libraries have been included in this project:
* LuaJIT        : https://github.com/LuaJIT/LuaJIT
* lua-htmlparser: https://github.com/msva/lua-htmlparser
* Json4Lua      : https://github.com/craigmj/json4lua

# Build Steps For Further Reference
* Download Oracle db offline document(http://docs.oracle.com/en/database/) in HTML format and extract as the source
* Install Microsoft HTML Help Workshop(https://msdn.microsoft.com/en-us/library/ms669985.aspx)
* Copy files from source into a new destination, excluding pdf/mobi/epub files
* Build content file (.hhc) based on `target.json`
* Build index file (.hhk) based on `index.htm` and `glossary.htm` for common books
* Build index file (.hhk) based on `index-all.html` for Javadoc API
* Build index file (.hhk) based on `nav\sql-keywords*.htm` and `nav\catalog_views*.htm`
* Build index file (.hhk) for book `Oracle Error Messages`/`PL/SQL Packages and Types Reference`/`APEX API`
* Build project file (.hhp) to include all needed files
* Rewrite all HTML files to adjust some elements for offline purpose
* Change some css files to adjust the HTML layouts
* Build .bat files for compile purpose
* Launch .bat files to compile all documents
* Create index.chm 

# Interfaces(file chm.lua)
* Build single book: `chm <sub-dir>` or `builder.new(<sub-dir>,true,true)`
* Build all books:   `chm <parallel_degree>` or `builder.BuildAll(<parallel_degree>)`
* Build project files for `index.chm`: `chm 0` or  `builder.BuildBatch()`
* Verify the logs to see if a CHM has convered multiple books: `chm -1` or `builder.scanInvalidLinks()`