include("deferred.lua")

local tests = {
    -- 2.1.1.1: may transition to either the fulfilled or rejected state
    function()
        local d = deferred.new()
        assert(d.state == "pending")
        d:resolve(123)
        assert(d.state == "fulfilled")

        d = deferred.new()
        assert(d.state == "pending")
        d:reject(123)
        assert(d.state == "rejected")
    end,

    -- 2.1.2.1: when fulfilled, must not transition to any other state.
    function()
        local d = deferred.new()
        d:resolve(123)
        assert(d.state == "fulfilled")
        d:reject(456)
        assert(d.state == "fulfilled")
    end,

    -- 2.1.2.2: must have a value, which must not change.
    function()
        local d = deferred.new()
        d:resolve(123)
        assert(d.value == 123)
        d:resolve(456)
        assert(d.value == 123, "d.value = "..tostring(d.value).." != 123")
    end,

    -- 2.1.3.1: when rejected, must not transition to any other state.
    function()
        local d = deferred.new()
        d:reject(123)
        assert(d.state == "rejected")
        d:resolve(456)
        assert(d.state == "rejected")
    end,

    -- 2.1.3.2: must have a reason, which must not change.
    function()
        local d = deferred.new()
        d:reject(123)
        assert(d.reason == 123)
        d:reject(456)
        assert(d.reason == 123)
    end,

    -- 2.2.1: Both onFulfilled and onRejected are optional arguments
    function()
        local d = deferred.new()
        d:next()
        d:resolve(123)
    end,

    -- 2.2.1.1: If onFulfilled is not a function, it must be ignored.
    function()
        local d = deferred.new()
        d:next(123)
        d:resolve(123)
    end,

    -- 2.2.1.2: If onRejected is not a function, it must be ignored.
    function()
        local d = deferred.new()
        d:next(function() end, 123)
        d:resolve(123)

        d = deferred.new()
        d:next(nil, 123)
        d:resolve(123)

        d = deferred.new()
        d:next("wow", 123)
        d:resolve(123)
    end,

    --
    -- 2.2.2. If onFulfilled is a function:
    -- 
    -- 2.2.2.1/2: it must be called after promise is fulfilled, with promise’s
    -- value as its first argument
    function()
        local d = deferred.new()
        d:next(function(v)
            assert(d.state == "fulfilled", "onFulfilled called before fulfilled")
            assert(v == 123)
        end)
        d:resolve(123)
    end,

    -- 2.2.2.3: it must not be called more than once.
    function()
        local once = true
        local d = deferred.new()
        d:next(function()
            assert(once, "onFulfilled called more than once")
            once = false
        end)
        d:resolve(123)
        d:resolve(123)
    end,

    --
    -- 2.2.6: then may be called multiple times on the same promise.  
    --
    -- 2.2.6.1: If/when promise is fulfilled, all respective onFulfilled 
    -- callbacks must execute in the order of their originating calls to then
    function(wait)
        local i = 0
        local d = deferred.new()
        for j = 0, 9 do
            d:next(function()
                assert(i == j)
                i = i + 1
            end)
        end
        d:resolve()
        wait(1, function()
            assert(i == 10, "onFulfill ran "..i.." times, not 10")
        end)
    end,

    -- 2.2.6.2 If/when promise is rejected, all respective onRejected callbacks
    -- must execute in the order of their originating calls to then.
    function(wait)
        local i = 0
        local d = deferred.new()
        for j = 0, 9 do
            d:next(j, function()
                assert(i == j)
                i = i + 1
            end)
        end
        d:reject()
        wait(1, function()
            assert(i == 10, "onReject ran "..i.." times, not 10")
        end)
    end,

    --
    -- 2.2.7: `then` must return a promise:
    -- `promise2 = promise1.then(onFulfilled, onRejected)`
    --
    function()
        local d = deferred.new()
        local promise = d:next()
        assert(istable(promise), "return value of next is not a table")
        assert(isfunction(promise.next), "returned value has no next method")
    end,

    -- 2.2.7.2:  If either `onFulfilled` or `onRejected` throws an exception
    -- `e`, `promise2` must be rejected with `e` as reason
    function(wait)
        local handled = false
        local d = deferred.new()
        d:next(function()
            error("no!")
        end)
        :next(nil, function(reason)
            assert(reason:find("no!"))
            handled = true
        end)
        d:resolve()
        wait(1, function()
            assert(handled, "promise2 did have no! inside reason")
        end)

        local handled2 = false
        d = deferred.new()
        d:next(nil, function()
            error("no!")
        end)
        :next(nil, function(err)
            assert(err:find("no!"))
            handled2 = true
        end)
        d:reject()
        wait(1, function()
            assert(handled2, "promise2 (#2) did not get handled!")
        end)
    end,

    -- 2.2.7.2: If either `onFulfilled` or `onRejected` throws an exception `e`,
    -- `promise2` must be rejected with `e` as the reason
    function()
        local d = deferred.new()
        d:next(function()
            error("test")
        end):next(function()
            assert(false, "should not be resolved")
        end, function(err)
            assert(err:find("test"), "rejected with incorrect reason")
        end)
        d:resolve()

        d = deferred.new()
        d:next(nil, function()
            error("test")
        end):next(function()
            assert(false, "should not be resolved")
        end, function(err)
            assert(err:find("test"), "rejected with incorrect reason")
        end)
        d:reject("wow")
    end,

    -- 2.2.7.3: If `onFulfilled` is not a function and `promise1` is fulfilled,
    -- `promise2` must be fulfilled with the same value
    function()
        local function testResolve(resolveValue)
            local ran = false
            local d = deferred.new()
            d:next(resolveValue):next(function(value)
                assert(value == resolveValue)
                ran = true
            end)
            d:resolve(resolveValue)
            timer.Simple(1, function()
                assert(ran, "promise2 onFulfilled not ran")
            end)
        end

        testResolve(nil)
        testResolve(false)
        testResolve(123)
        testResolve({a = 1, b = 2, c = 3})
        testResolve({foo = function()
            local x = 1
            x = x + 1
        end})
    end,

    -- 2.2.7.4: If `onRejected` is not a function and `promise1` is rejected,
    -- `promise2` must be rejected with the same reason
    function()
        local nonFnValues = {123, true, "wow", nil, function() end}
        nonFnValues[#nonFnValues + 1] = nonFnValues

        for _, value in ipairs(nonFnValues) do
            local d = deferred.new()
            d:next(nil, value):next(nil, function(reason)
                assert(reason == "what")
            end)
            d:reject("what")
        end
    end,

    --
    -- 2.3: Promise Resolution Procedure [[Resolve]](promise, x)
    -- 

    -- 2.3.1: If `promise` and `x` refer to the same object, reject `promise`
    function(wait)
        local d = deferred.new()
        d:resolve(d)
        wait(1, function()
            assert(d.state == "rejected")
        end)

        d = deferred.new()
        local promise = d:next(nil, function()
            return d
        end)
        promise:next(nil, function()
            assert(promise.state == "rejected")
        end)
        d:reject("what")
    end,

    --
    -- 2.3.2: If x is a promise, adopt its state
    -- 
    -- 2.3.2.1: If `x` is pending, `promise` must remain pending until `x` is
    -- fulfilled or rejected.
    function(wait)
        local d = deferred.new()
        local d2 = deferred.new()
        local result
        d:next(function(value)
            result = value
        end)
        d:resolve(d2)
        assert(d.state == "pending")
        wait(0.5, function()
            assert(d.state == "pending", "adopted state not the same")
            d2:resolve(123)
        end)
        wait(1, function()
            assert(d.state == "fulfilled", "state not adopted")
        end)
    end,
    function(wait)
        local d = deferred.new()
        local d2 = deferred.new()
        local result
        d:next(nil, function(value)
            result = value
        end)
        d:resolve(d2)
        assert(d.state == "pending")
        wait(0.5, function()
            assert(d.state == "pending", "adopted state not the same")
            d2:reject(123)
        end)
        wait(1, function()
            assert(d.state == "rejected", "state not adopted")
        end)
    end,

    -- 2.3.2.2: If/when `x` is fulfilled, fulfill `promise` with the same value.
    function(wait)
        local d = deferred.new()
        local d2 = deferred.new()
        local result = nil
        d:next(function(value)
            result = value
        end)
        d:resolve(d2)
        assert(d.value == nil, "d should not have a value")
        assert(result == nil, "result should not be set")
        wait(0.5, function()
            assert(d.value == nil, "d should not have a value")
            assert(result == nil, "result should not be set")
            d2:resolve(123)
        end)
        wait(1, function()
            assert(result == 123, "value not adopted")
        end)
    end,
    function()
        local d = deferred.new()
        local d2 = deferred.new()
        d2:resolve(123)
        d:next(function(value)
            assert(value == 123, "pre-resolved value is not 123")
        end)
        d:resolve(d2)
    end,

    -- 2.3.2.3: If/when `x` is rejected, reject `promise` with the same reason
    function(wait)
        local d = deferred.new()
        local d2 = deferred.new()
        local result
        d:next(nil, function(value)
            result = value
        end)
        d:resolve(d2)
        assert(d.value == nil, "d should not have a value")
        assert(result == nil, "result should not be set")
        wait(0.5, function()
            assert(d.value == nil, "d should not have a value")
            assert(result == nil, "result should not be set")
            d2:reject(123)
        end)
        wait(1, function()
            assert(result == 123, "reason not adopted")
        end)
    end,
    function()
        local d = deferred.new()
        local d2 = deferred.new()
        d2:reject(123)
        d:next(nil, function(value)
            assert(value == 123, "pre-resolved value is not 123")
        end)
        d:resolve(d2)
    end,

    --
    -- 2.3.3 Otherwise, if x is an object or function
    -- Let `next` be `x.next`
    -- 

    -- 2.3.3.3: If `next` is a function, call it with first
    -- argument `resolvePromise`, and second argument `rejectPromise`
    function(wait)
        local d = deferred.new()
        local okay = false
        d:next(function()
            return {
                next = function(resolve, reject)
                    assert(isfunction(resolve), "resolve must be a function")
                    assert(isfunction(reject), "reject must be a function")
                    okay = true
                end
            }
        end)
        d:resolve()
        wait(1, function() assert(okay, "d did not get handled") end)
    end,

    -- 2.3.3.3.1: If/when `resolvePromise` is called with a value `y`,
    -- run [[Resolve]](promise, y)

    -- `y` is not thenable
    function(wait)
        local passed = true
        local nonThenables = {false, 123.4, "hello world", {a = 1, b = 2}}
        local resolvers = {}
        for k, v in ipairs(nonThenables) do
            resolvers[k] = function()
                return {
                    next = function(resolve) resolve(v) end
                }
            end
        end

        for k, resolver in ipairs(resolvers) do
            local d = deferred.new()
            d:next(resolver):next(function(value)
                if (value ~= nonThenables[k]) then
                    print("Expected "..tostring(nonThenables[k])..", got "..tostring(value))
                    passed = false
                end
            end)
            d:resolve()
        end

        wait(1, function()
            assert(passed, "non-thenable resolution failed")
        end)
    end,
    -- `y` is thenable
    function(wait)
        local passed = true
        local nonThenables = {false, 123.4, "hello world", {a = 1, b = 2}}
        local thenables = {}
        for k, v in ipairs(nonThenables) do
            thenables[k] = function()
                return {
                    next = function(resolve, reject)
                        resolve(v)
                    end
                }
            end
        end

        for k, thenable in ipairs(thenables) do
            local d = deferred.new()
            d:next(thenable):next(function(value)
                if (value ~= nonThenables[k]) then
                    print("Expected "..tostring(nonThenables[k])..", got "..tostring(value))
                    passed = false
                end
            end)
            d:resolve()
        end
        
        wait(1, function()
            assert(passed, "thenable resolution failed")
        end)
    end,
    -- `y` is a promise
    function(wait)
        local matched = 0
        local nonThenables = {false, 123.4, "hello world", {a = 1, b = 2}}
        local promises = {}
        for k, v in ipairs(nonThenables) do
            promises[k] = function()
                return {
                    next = function(resolve)
                        local d = deferred.new()
                        wait(0.5, function()
                            d:resolve(v)
                        end)
                        resolve(d)
                    end
                }
            end
        end

        for k, promise in ipairs(promises) do
            local d = deferred.new()
            d:next(promise):next(function(value)
                if (value == nonThenables[k]) then
                    matched = matched + 1
                else
                    print("Expected "..tostring(nonThenables[k])..", got "..tostring(value))
                end
            end)
            d:resolve()
        end
        
        wait(1, function()
            assert(matched == #promises, "promise resolution failed")
        end)
    end,

    -- 2.3.3.3.2: If/when rejectPromise is called with a reason `r`,
    -- reject promise with `r`
    function(wait)
        local ran = false
        local d = deferred.new()
        d:next(function()
            return {
                next = function(_, reject)
                    reject("dang")
                end
            }
        end)
        :next(nil, function(reason)
            assert(reason:find("dang"), "incorrect reason")
            ran = true
        end)
        d:resolve()

        wait(1, function()
            assert(ran, "incorrect reason or did not run")
        end)
    end,

    -- 2.3.3.3.3: If both resolvePromise and rejectPromise are called, or
    -- multiple calls to the same argument are made, the first call takes
    -- precedence, and any further calls are ignored.
    function(wait)
        -- Resolve, then reject
        local d0 = deferred.new()
        local p0 = d0:next(function()
            return {
                next = function(resolve, reject)
                    resolve(123)
                    reject(456)
                end
            }
        end)
        d0:resolve()
        wait(1, function()
            assert(p0.state == "fulfilled", "p0 not fulfilled")
            assert(p0.value == 123, "p0's value is incorrect")
        end)

        -- Reject, then resolve
        local d1 = deferred.new()
        local finalValue1
        local p1 = d1:next(function()
            return {
                next = function(resolve, reject)
                    reject(123)
                    resolve(456)
                end
            }
        end)
        d1:resolve()
        wait(1, function()
            assert(p1.state == "rejected", "p1 not rejected")
            assert(p1.reason == 123, "p1's reason is incorrect")
        end)

        -- Resolve multiple times
        local d2 = deferred.new()
        local p2 = d2:next(function()
            return {
                next = function(resolve, reject)
                    for i = 10, 1, -1 do
                        resolve(i)
                    end
                end
            }
        end)
        d2:resolve()
        wait(1, function()
            assert(p2.state == "fulfilled", "p2 not fulfilled")
            assert(p2.value == 10, "p2's value is not that of first resolve")
        end)

        -- Reject multiple times
        local d3 = deferred.new()
        local p3 = d3:next(function()
            return {
                next = function(resolve, reject)
                    for i = 10, 1, -1 do
                        reject(i)
                    end
                end
            }
        end)
        d3:resolve()
        wait(1, function()
            assert(p3.state == "rejected", "p3 not rejected")
            assert(p3.reason == 10, "p3's value is not that of first reject")
        end)
    end,

    --
    -- 2.3.3.3.4: If calling then throws an exception `e`
    --
    -- 2.3.3.3.4.1: If `resolvePromise` or `rejectPromise` have been called,
    -- ignore it.
    function(wait)
        local d = deferred.new()
        local p = d:next(function()
            return {
                next = function(resolve)
                    resolve(123)
                    error("noo!")
                end
            }
        end)
        d:resolve()
        wait(1, function()
            assert(p.state == "fulfilled", "p is not fulfilled")
            assert(p.value == 123, "p.value = "..tostring(p.value).." ~= 123")
        end)
    end,
    function(wait)
        local d = deferred.new()
        local p = d:next(function()
            return {
                next = function(_, reject)
                    reject(123)
                    error("noo!")
                end
            }
        end)
        d:resolve()
        wait(1, function()
            assert(p.state == "rejected", "p is not rejected")
            assert(p.reason == 123, "p.reason = "..tostring(p.value).." ~= 123")
        end)
    end,

    -- 2.3.3.4: If `next` is not a function, fulfill promise with `x`
    function(wait)
        local function testResolve(value)
            local ran = false
            local d = deferred.new()
            local testValue = {next = value}
            d:next(function()
                return testValue
            end):next(function(value2)
                assert(testValue == value2, tostring(testValue).." != "..tostring(value2))
                ran = true
            end)
            d:resolve()
            wait(1, function()
                assert(ran, "did not get "..tostring(testValue).." back")
            end)
        end

        testResolve(123)
        testResolve(true)
        testResolve(false)
        testResolve(nil)
        testResolve({a = 1, b = 2, c = 3, d = "hello world"})
        testResolve("hello world")
        testResolve(deferred.new())
    end,

    -- 2.3.4: If `x` is not an object or function, fulfill promise with `x`.
    function(wait)
        local function testResolve(value)
            local ran = false
            local d = deferred.new()
            d:next(function(value2)
                assert(value == value2, "value mismatch with "..tostring(value))
                ran = true
            end)
            wait(1, function()
                assert(ran, "did not get "..tostring(value).." back")
            end)
            d:resolve(value)
        end

        testResolve(123)
        testResolve(true)
        testResolve(false)
        testResolve(nil)
        testResolve({a = 1, b = 2, c = 3, d = "hello world"})
        testResolve("hello world")
    end,
}

local ran = 0
local passed = 0
local expected = #tests

local function finishTests()
    print("*********************************************************")
    local count = passed.."/"..expected
    if (passed < expected) then
        MsgC(Color(255, 0, 0), count)
    else
        MsgC(Color(0, 255, 0), count)
    end
    MsgN(" TESTS PASSED")
    print("*********************************************************")
end

DEBUG_IGNOREUNHANDLED = true

for i, test in ipairs(tests) do
    local function done(testPassed, err)
        ran = ran + 1
        passed = passed + (testPassed and 1 or 0)

        if (not testPassed) then
            MsgC(Color(255, 0, 0), "X ")
            print("TEST #"..i.." FAILED!")
            print("\t"..err)
        end

        if (ran == expected) then
            finishTests()
            DEBUG_IGNOREUNHANDLED = false
        end
    end

    local defer = false
    local function wait(time, callback)
        if (defer) then
            expected = expected + 1
        end
        defer = true
        timer.Simple(time, function()
            done(pcall(callback))
        end)
    end

    local status, result = pcall(test, wait)
    if (not defer) then
        done(status, result)
    end
end