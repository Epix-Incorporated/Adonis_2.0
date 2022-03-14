--[[
    Author: Sceleratis
    Description: Provides CLI-like argument parsing.
]]


return {
    Trim = function(self, str: string)
        return string.match(str, "^%s*(.-)%s*$")
    end,

    ReplaceCharacters = function(self, str: string, chars: {}, replaceWith)
        for i, char in ipairs(chars) do
            str = string.gsub(str, char, replaceWith or "")
        end
        return str
    end,

    RemoveQuotes = function(self, str: string)
        return self:ReplaceCharacters(str, {'^"(.+)"$', "^'(.+)'$"}, "%1")
    end,

    SplitString = function(self, str: string, splitChar: string, removeQuotes: boolean)
        local segments = {}
        local sentinel = string.char(0)
        local function doSplitSentinelCheck(x: string) return string.gsub(x, splitChar, sentinel) end
        local quoteSafe = self:ReplaceCharacters(str, {'%b""', "%b''"}, doSplitSentinelCheck)
        for segment in string.gmatch(quoteSafe, "([^".. splitChar .."]+)") do
            local result = self:Trim(string.gsub(segment, sentinel, splitChar))
            if removeQuotes then
                result = self:RemoveQuotes(result)
            end
            table.insert(segments, result)
        end
        return segments
    end,

    ConvertToParams = function(self, args, stopAtFirstParamArg)
        local result = {}
        local curParam
        local curPos = 1
        local curArg = args[curPos]

        while curArg do
            local gotParam = curArg:match("^%-%-(.+)") or curArg:match("^%-(.+)")

            if gotParam then
                curParam = gotParam
                result[curParam] = ""
            elseif curParam then
                result[curParam] = result[curParam] .. curArg

                --// If we only want one match per param
                if stopAtFirstParamArg then
                    curParam = nil
                end
            else
                table.insert(result, curArg)
            end

            curPos += 1
            curArg = args[curPos]
        end

        return result
    end,

    ConvertToDataType = function(self, str: string)
		str = string.lower(str)
        if tonumber(str) then
            return tonumber(str)
        elseif table.find({"false", "no", "off"}, str) then
            return false
        elseif table.find({"true", "yes", "on"}, str) then
            return true
		end
		return str
    end,

    Parse = function(self, str: string, split: string?, removeQuotes: boolean?, stopAtFirstParamArg: boolean?)
        local removeQuotes = if removeQuotes ~= nil then removeQuotes else true
        local stopAtFirstParamArg = if stopAtFirstParamArg ~= nil then stopAtFirstParamArg else true
        local extracted = self:SplitString(str, split or ' ', false)
        local params = self:ConvertToParams(extracted, stopAtFirstParamArg)

        for ind,value in pairs(params) do
            local trueVal = self:ConvertToDataType(value)
            params[ind] = if type(trueVal) == "string" and removeQuotes then self:RemoveQuotes(trueVal) else trueVal
        end

        return params
    end
}
