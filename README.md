# Oracle-DB-Document-CHM-builder
Generate Oracle database online document into offline CHMs file set. For self use and is user-unfriendly. Still in dev.

# Dependencies
All dependent libraries have been included in this project:
* LuaJIT: https://github.com/LuaJIT/LuaJIT
* lua-htmlparser: https://github.com/msva/lua-htmlparser
* luasys: https://github.com/tnodir/luasys

# Build Steps
* Download Oracle db offline document(http://docs.oracle.com/en/database/) in HTML format and extract as the source
* Install Microsoft HTML Help Workshop(https://msdn.microsoft.com/en-us/library/ms669985.aspx)
* Copy files from source into a new destination, excluding pdf/js/mobi/epub files
* Build content file (.hhc) based on `target.json`
* Build index file (.hhk) based on `index.htm`
* Build project file (.hhp) which includes all files
* Rewrite all HTML files to adjust all cross-document hyperlinks for offline purpose
* change some css files to adjust the HTML layouts
* Build .bat files for compile purpose
* Launch .bat files to compile all documents
* Create index.chm 