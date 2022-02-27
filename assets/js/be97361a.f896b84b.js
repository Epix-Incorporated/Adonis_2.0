"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[8896],{36607:function(e){e.exports=JSON.parse('{"functions":[{"name":"GetKeys","desc":"Returns remote communication keys to the client if not already retrieved.","params":[{"name":"p","desc":"","lua_type":"Player"}],"returns":[],"function_type":"static","tags":["Remote Command"],"source":{"line":56,"path":"src/MainModule/Packages/System.Core/Server/Modules/Remote.lua"}},{"name":"VerifyRemote","desc":"Allows the client to verify integrity of the remote event","params":[{"name":"p","desc":"Player","lua_type":"Player"},{"name":"t","desc":"Test value","lua_type":"string"}],"returns":[],"function_type":"static","tags":["Remote Command"],"source":{"line":79,"path":"src/MainModule/Packages/System.Core/Server/Modules/Remote.lua"}},{"name":"ClientReady","desc":"Triggered by clients when they are finished their setup process and are ready for normal communication.","params":[{"name":"p","desc":"","lua_type":"Player"}],"returns":[],"function_type":"static","source":{"line":91,"path":"src/MainModule/Packages/System.Core/Server/Modules/Remote.lua"}},{"name":"SessionData","desc":"Allows the client to send data to a session their player is a member of. Handled by ServerSession.","params":[{"name":"p","desc":"","lua_type":"Player"},{"name":"sessionKey","desc":"Session key","lua_type":"string"},{"name":"...","desc":"Data to be passed","lua_type":"any"}],"returns":[],"function_type":"static","source":{"line":113,"path":"src/MainModule/Packages/System.Core/Server/Modules/Remote.lua"}},{"name":"Setting","desc":"Returns a setting if that setting has ClientAllowed set to true in its declaration data.","params":[{"name":"p","desc":"","lua_type":"Player"},{"name":"setting","desc":"","lua_type":"string"}],"returns":[{"desc":"","lua_type":"setting value"}],"function_type":"static","source":{"line":128,"path":"src/MainModule/Packages/System.Core/Server/Modules/Remote.lua"}},{"name":"SetUserSettings","desc":"Updates UserSettings using data within the provided settings table in the format of [setting] = value","params":[{"name":"p","desc":"","lua_type":"Player"},{"name":"settings","desc":"","lua_type":"table"}],"returns":[],"function_type":"static","source":{"line":141,"path":"src/MainModule/Packages/System.Core/Server/Modules/Remote.lua"}}],"properties":[],"types":[],"name":"Server.Remote.Commands","desc":"Remote (client-to-server) commands","tags":["Remote Commands","Package: System.Core"],"realm":["Server"],"source":{"line":21,"path":"src/MainModule/Packages/System.Core/Server/Modules/Remote.lua"}}')}}]);