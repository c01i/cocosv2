assert(_VERSION == "Lua 5.1")
assert(jit == nil and not pcall(require, "ffi"))
package.preload.runtime_probe = function() return {value = 42} end
assert(require("runtime_probe").value == 42)
local chunk = assert(loadstring(string.dump(function(a) return a + 2 end)))
assert(chunk(40) == 42)
local co = coroutine.create(function() coroutine.yield(21); return 42 end)
local ok, value = coroutine.resume(co)
assert(ok and value == 21)
ok, value = coroutine.resume(co)
assert(ok and value == 42)
assert(string.format("%d", math.floor(42.8)) == "42")
assert(not pcall(function() error("expected failure") end))

-- Weak table collection must retain its original mode semantics, including NUL.
local weak = setmetatable({}, {__mode = "kv"})
do local key, value = {}, {}; weak[key] = value end
collectgarbage("collect")
assert(next(weak) == nil)
local strong = setmetatable({}, {__mode = "\0v"})
do strong.value = {} end
collectgarbage("collect")
assert(strong.value ~= nil)
