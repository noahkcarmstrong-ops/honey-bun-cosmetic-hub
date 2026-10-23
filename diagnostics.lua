-- Bounded, event-driven diagnostics in the executor workspace.
local Http=game:GetService("HttpService")
return function(context)
    local folder="logs/larp"
    local stamp=os.date("!%Y-%m-%d_%H-%M-%SZ").."_"..Http:GenerateGUID(false):sub(1,8)
    local latest=folder.."/latest.log"
    local part=1
    local limit=512*1024
    local pending,bytes,queued,closed={},0,false,false
    local size,buffer=0,""
    local warned=false
    local initialized=false
    local environment=type(getgenv)=="function" and getgenv() or _G
    environment.__LarpbloxLatestLogSession=stamp
    local function initialize()
        if initialized then return end
        assert(type(writefile)=="function" and type(makefolder)=="function","File writing unavailable")
        for _,directory in ipairs({"logs",folder})do
            if type(isfolder)~="function" or not isfolder(directory)then
                local ok,err=pcall(makefolder,directory)
                if not ok and not(type(isfolder)=="function" and isfolder(directory))then error(err)end
            end
        end
        if type(readfile)=="function"then
            local ok,old=pcall(readfile,latest)
            if ok and type(old)=="string" and #old>0 then
                local archiveStamp=stamp
                local decoded,first=pcall(Http.JSONDecode,Http,old:match("[^\n]+") or "")
                if decoded and type(first)=="table" and type(first.at)=="number"then
                    archiveStamp=os.date("!%Y-%m-%d_%H-%M-%SZ",math.floor(first.at/1000)).."_"..Http:GenerateGUID(false):sub(1,8)
                end
                writefile(folder.."/"..archiveStamp..".log",old)
            end
        end
        writefile(latest,"")
        initialized=true
    end
    local function clean(value)
        if type(value)~="string"then return value end
        value=value:gsub("https?://%S+","[url]")
        value=value:gsub("[Bb]earer%s+[%w%._%-]+","Bearer [redacted]")
        return value:sub(1,768)
    end
    local function flush()
        queued=false
        if #pending==0 then return end
        local data=table.concat(pending);pending={};bytes=0
        local ok=pcall(function()
            if environment.__LarpbloxLatestLogSession~=stamp then return end
            initialize()
            if size+#data>limit then
                writefile(folder.."/"..stamp.."_"..tostring(part)..".log",buffer)
                part=part+1
                writefile(latest,"");size=0;buffer=""
            end
            buffer=buffer..data
            if type(appendfile)=="function"then appendfile(latest,data)
            else writefile(latest,buffer)end
            size=size+#data
        end)
        if not ok and not warned then warned=true;warn("Larpblox: diagnostic file could not be written.")end
    end
    local lastState={}
    local function log(event,fields)
        if closed or type(writefile)~="function"then return end
        local record={at=DateTime.now().UnixTimestampMillis,event=event}
        for key,value in pairs(context or {})do record[key]=clean(value)end
        for key,value in pairs(fields or {})do
            if type(value)=="string" or type(value)=="number" or type(value)=="boolean"then record[key]=clean(value)end
        end
        if event=="status" or event=="desktop_connection"then
            local state=event=="status" and tostring(record.detail) or tostring(record.connected)
            if lastState[event]==state then return end
            lastState[event]=state
        end
        local ok,line=pcall(Http.JSONEncode,Http,record)
        if not ok then return end
        line=line.."\n";pending[#pending+1]=line;bytes=bytes+#line
        if bytes>=16384 then flush()
        elseif not queued then queued=true;task.defer(flush)end
    end
    log("session_start")
    return {log=log,flush=flush,close=function()if closed then return end;log("session_end");flush();closed=true end,path=latest}
end
