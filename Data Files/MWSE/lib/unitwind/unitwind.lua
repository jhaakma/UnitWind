local validator = require "unitwind.validator"
local UnitWind = {
    schema = {
        name = "UnitWind",
        fields = {
            enabled = { type = "boolean", default = true, required = false},
            highlight = { type = "boolean", default = true, required = false },
            onStart = { type = "function",  required = false },
            onFinish = { type = "function",  required = false },
            beforeTest = { type = "function", required = false },
            afterTest = { type = "function", required = false },
            exitAfter = { type = "boolean", default = false, required = false },
            outputFile = { type = "string", required = false },
            --internal
            totalTests = { type = "number", default = 0, required = false },
            testsPassed = { type = "number", default = 0, required = false },
            testsFailed = { type = "number", default = 0, required = false },
            completedTests = { type = "table", default = {}, required = false },
        }
    }
}
local ansicolors = require("unitwind.ansicolors")

function UnitWind.new(data)
    local unitWind = table.deepcopy(data)
    validator.validate(unitWind, UnitWind.schema)
    setmetatable(unitWind, UnitWind)
    UnitWind.__index = UnitWind
    unitWind:setOutputFile(unitWind.outputFile)
    return unitWind
end

function UnitWind:color(message, color)
    if self.highlight then
        message = ansicolors('%' .. string.format('{%s}%s', color, message))
    end
    return message
end

function UnitWind:rawLog(message, ...)
    if not self.enabled then return end
    local output = tostring(message):format(...)
    --Prints to custom file if defined
    if self.outputFile then
        self.outputFile:write(output .. "\n")
        self.outputFile:flush()
    else
        --otherwise straight to mwse.log
        print(output)
    end
end

function UnitWind:log(message, ...)
    self:rawLog(self:color(message, 'bright blue'), ...)
end

function UnitWind:logWhite(message, ...)
    self:rawLog(self:color(message, 'white'), ...)
end

function UnitWind:error(message, ...)
    self:rawLog(self:color(message, 'red'), ...)
end


function UnitWind:passLog(message, ...)
    local pass = self:color('✔️', 'green')
    self:rawLog(pass .. " " .. message, ...)
end

function UnitWind:failLog(message, ...)
    local fail = self:color('❌', 'red')
    self:rawLog(fail .. " " .. message, ...)
end


function UnitWind:setOutputFile(outputFile)
    if outputFile == nil or string.lower(outputFile) == "mwse.log" then
        self.outputFile = nil
    else
        local errMsg = "[ERROR] Logger:setLogLevel() - Not a valid outputFile (must be a string)"
        assert( type(outputFile) == "string", errMsg)
        self.outputFile = io.open(outputFile, "w")
    end
end


function UnitWind:expect(result)
    if not self.enabled then return end
    local function toBe(expectedResult, isNot)
        if (result == expectedResult) == isNot then
            error(string.format("Expected value to %sbe %s, got: %s.", isNot and "not " or "", expectedResult, result))
        end
        return true
    end

    local function toBeType(expectedType, isNot)
        local thisType = type(result)
        if (thisType == expectedType) == isNot then
            error(string.format("Expected type to %sbe %s, got: %s.", isNot and "not " or "", expectedType, thisType))
        end
        return true
    end

    local expects = {
        toBe = function(expectedResult)
            return toBe(expectedResult, false)
        end,
        toBeType = function(expectedType)
            return toBeType(expectedType, false)
        end,

        NOT = {
            toBe = function(expectedResult)
                return toBe(expectedResult, true)
            end,
            toBeType = function(expectedType)
                return toBeType(expectedType, true)
            end,
        },
    }
    expects.toFail = function()
        local status, error = pcall(result)
        return toBe(not status, true)
    end

    return expects
end


function UnitWind:test(testName, callback)
    if not self.enabled then return end
    self.totalTests = self.totalTests + 1
    self:log(self:color("Running test: ", "cyan") .. testName)
    local status, error = pcall(callback)
    table.insert(self.completedTests, {
        name = testName,
        passed = status,
    })
    if status == true then
        self.testsPassed = self.testsPassed + 1
    else
        self.testsFailed = self.testsFailed + 1
        self:error("Error Message: %s\n%s", error, debug.traceback())
    end
    if self.afterTest then
        self.afterTest()
    end
end

function UnitWind:start(testsName)
    self.testsName = testsName or ""
    self:log("-----------------------------------------------------")
    self:log("Starting: %s", self.testsName)
    self:log("-----------------------------------------------------")
    if self.onStart then
        self.onStart()
    end
end

function UnitWind:reset()
    self.testsName = ""
    self.totalTests = 0
    self.testsPassed = 0
    self.testsFailed = 0
    self.completedTests = {}
end

function UnitWind:finish(exitAfter)
    if not self.enabled then return end
    self:log("-----------------------------------------------------")
    self:log("Finished: %s\n", self.testsName or "")
    self:log("-----------------------------------------------------")

    for _, test in ipairs(self.completedTests) do
        if test.passed then
            self:passLog(test.name)
        else
            self:failLog(test.name)
        end
    end

    local passed = self:color(string.format("%d passed", self.testsPassed), 'green')
    local failed = self:color(string.format("%d failed", self.testsFailed), 'red')
    local total = string.format("%d total", self.totalTests)

    self:log("\n%s, %s, %s\n", passed, failed, total)
    if self.testsPassed == self.totalTests then
        self:log(self:color("ALL TESTS PASSED", 'green'))
    end
    self:log("-----------------------------------------")
    if self.onFinish then
        self.onFinish()
    end
    self:reset()
    if exitAfter or self.exitAfter then
        self:log("Exiting Morrowind")
        os.exit(0)
    end
end


return UnitWind