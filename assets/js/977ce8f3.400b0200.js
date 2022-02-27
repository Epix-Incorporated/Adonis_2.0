"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[2510],{35366:function(e){e.exports=JSON.parse('{"functions":[{"name":"CleanCache","desc":"Clears any expired cache entries. This is called automatically when data is set.","params":[],"returns":[],"function_type":"method","source":{"line":64,"path":"src/MainModule/Packages/System.Utilities/Shared/Utilities.lua"}},{"name":"SetData","desc":"Sets the given index in the cache to the value provided.","params":[{"name":"key","desc":"Cache key used to update and retrieve stored values","lua_type":"any"},{"name":"value","desc":"Value to store","lua_type":"any"},{"name":"data","desc":"Optional table describing how to handle stored data","lua_type":"CacheEntryData"}],"returns":[],"function_type":"method","source":{"line":79,"path":"src/MainModule/Packages/System.Utilities/Shared/Utilities.lua"}},{"name":"GetData","desc":"Returns the value associated with the provided key.","params":[{"name":"key","desc":"","lua_type":"any"}],"returns":[{"desc":"","lua_type":"any"}],"function_type":"method","source":{"line":95,"path":"src/MainModule/Packages/System.Utilities/Shared/Utilities.lua"}}],"properties":[],"types":[{"name":"CacheEntryData","desc":"Responsible for configuration of individual cache entries.","fields":[{"name":"Value","lua_type":"any","desc":"Cache entry value"},{"name":"Timeout","lua_type":"int","desc":"Optional timeout for this specific cache entry"},{"name":"AccessResetsTimer","lua_type":"bool","desc":"If true, this entry\'s timeout timer will be reset whenever data is accessed"},{"name":"CacheTime","lua_type":"int","desc":"os.time() when the cache was last updated (or accessed)"}],"source":{"line":42,"path":"src/MainModule/Packages/System.Utilities/Shared/Utilities.lua"}}],"name":"MemoryCache","desc":"Responsible for temporary memory storage.","tags":["Utilities","Package: System.Utilities"],"realm":["Client","Server"],"source":{"line":34,"path":"src/MainModule/Packages/System.Utilities/Shared/Utilities.lua"}}')}}]);