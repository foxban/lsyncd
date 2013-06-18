-----
-- User configuration file for lsyncd.
-- This needs lsyncd >= 2.0.3
--
-- This configuration will execute a command on the remote host
-- after every successfullycompleted rsync operation.
-- for example to restart servlets on the target host or so.

local directpostcmd = {

        -- based on default rsync.
        default.direct,

        -- for this config it is important to keep maxProcesses at 1, so
        -- the postcmds will only be spawned after the rsync completed
        maxProcesses = 1,

        -- called whenever something is to be done
        action = function(inlet)
                local event = inlet.getEvent()
                local config = inlet.getConfig()
                -- if the event is a blanket event and not the startup,
                -- its there to spawn the webservice restart at the target.
                if event.etype == "Blanket" then
                        -- uses rawget to test if "isPostcmd" has been set without
                        -- triggering an error if not.
                        local isPostcmd = rawget(event, "isPostcmd")
                        if event.isPostcmd and event.lastOp == 'Create' then
--                              spawn(event, "/usr/bin/curl",
                                spawn(event, "/bin/echo",
                                        '-X',
                                        'POST',
                                        '-d',
                                        'RESULT="' .. event.pathname .. "\t"  .. 'http://example.com/' .. event.pathname .. '"',
                                        'http://callback.example.com/CdnCallBackInft/php/DataIntf.php');
                        return
                        else
                -- this is the startup, forwards it to default routine.
                return default.direct.action(inlet)
                end
                        error("this should never be reached")
                end
                -- for any other event, a blanket event is created that
                -- will stack on the queue and do the postcmd when its finished
                local sync = inlet.createBlanketEvent()
                sync.isPostcmd = true
                sync.pathname = event.pathname
                sync.lastOp = event.etype
                -- the original event is simply forwarded to the normal action handler
                return default.direct.action(inlet)
        end,

        -- called when a process exited.
        -- this can be a rsync command, the startup rsync or the postcmd
        collect = function(agent, exitcode)
                -- for the ssh commands 255 is network error -> try again
                local isPostcmd = rawget(agent, "isPostcmd")
                if not agent.isList and agent.etype == "Blanket" and isPostcmd then
                        if exitcode ~= 0 then
                                error("submit curl call failed with exitcode = " .. exitcode)
                        end
                        return
                else
                        --- everything else, forward to default collection handler
                        return default.collect(agent,exitcode)
                end
                error("this should never be reached")
        end

        -- called before anything else
        -- builds the target from host and targetdir
--      prepare = function(config)
--              if not config.host then
--                      error("rsyncpostcmd neets 'host' configured", 4)
--              end
--              if not config.targetdir then
--                      error("rsyncpostcmd needs 'targetdir' configured", 4)
--              end
--              if not config.target then
--                      config.target = config.host .. ":" .. config.targetdir
--              end
--              return default.direct.prepare(config)
--      end
}


sync {
        directpostcmd,
        source = "/src",
        target = "/target",
        delete = false,
        init = false,
}
