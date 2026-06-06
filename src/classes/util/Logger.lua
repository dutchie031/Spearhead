
local Util = require("classes.util.Util")

--- @class Logger
--- @field LoggerName string the name of the logger
--- @field LogLevel string the log level of the logger
local LOGGER = {}
do
    local PreFix = "Spearhead"

    ---comment
    ---@param logger_name any
    ---@param logLevel LogLevel
    ---@return Logger
    function LOGGER.new(logger_name, logLevel)
        LOGGER.__index = LOGGER
        local self = setmetatable({}, LOGGER)
        self.LoggerName = logger_name or "(loggername not set)"
        self.LogLevel = logLevel or "INFO"

        return self
    end

    ---@param message any the message
    function LOGGER:info(message)
        if message == nil then
            return
        end
        message = Util.toString(message)

        if self.LogLevel == "INFO" or self.LogLevel == "DEBUG" then
            env.info("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
        end
    end

    ---comment
    ---@param message string
    function LOGGER:warn(message)
        if message == nil then
            return
        end
        message = Util.toString(message)

        if self.LogLevel == "INFO" or self.LogLevel == "DEBUG" or self.LogLevel == "WARN" then
            env.warning("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
        end
    end

    ---@param message any -- the message
    function LOGGER:error(message)
        if message == nil then
            return
        end

        message = Util.toString(message)

        if self.LogLevel == "INFO" or self.LogLevel == "DEBUG" or self.LogLevel == "WARN" or self.LogLevel == "ERROR" then
            env.error("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
        end
    end

    ---@param message any the message
    function LOGGER:debug(message)
        if message == nil then
            return
        end

        message = Util.toString(message)
        if self.LogLevel == "DEBUG" then
            env.info("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "][DEBUG] " .. message)
        end
    end
end

return LOGGER