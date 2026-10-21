-- Bounded, event-driven diagnostics in the executor workspace.
local Http=game:GetService("HttpService")
return function(context)
    local folder="logs/larp"
    local stamp=os.date("!%Y-%m-%d_%H-%M-%SZ").."_"..Http:GenerateGUID(false):sub(1,8)
    local latest=folder.."/latest.log"
    local part=1
    local path=folder.."/"..stamp..".log"
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
        writefile(path,"")
        if environment.__LarpbloxLatestLogSession==stamp then writefile(latest,"")end
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
            initialize()
            if size+#data>limit then
                part=part+1
                path=folder.."/"..stamp.."_"..tostring(part)..".log"
                writefile(path,"");size=0;buffer=""
                if environment.__LarpbloxLatestLogSession==stamp then writefile(latest,"")end
            end
            buffer=buffer..data
            if type(appendfile)=="function"then
                appendfile(path,data)
                if environment.__LarpbloxLatestLogSession==stamp then appendfile(latest,data)end
            else
                writefile(path,buffer)
                if environment.__LarpbloxLatestLogSession==stamp then writefile(latest,buffer)end
            end
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
    return {log=log,close=function()if closed then return end;log("session_end");flush();closed=true end,path=latest,sessionPath=path}
end
