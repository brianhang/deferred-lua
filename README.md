# deferred-lua
Lua implementation of the [Promises/A+](https://promisesaplus.com/) standard (not completely compliant due to some differences between JS and Lua) for Garry's Mod. One different is the `next` is used instead of `then` since `then` is a keyword in Lua. If you have never used promises before, you should check out [this explanation](https://codeburst.io/javascript-promises-explained-with-simple-real-life-analogies-dd6908092138). While this isn't JavaScript, the concepts are the same.

## Installation
Place the `deferred.lua` file somewhere and include it with
```lua
include("path/to/deferred.lua")
```

## Examples
Basic usage:
```lua
local function fetch(url)
    local d = deferred.new()
    http.Fetch(url, function(body, size, headers, code)
        d:resolve(body)
    end, function(err)
        d:reject(err)
    end)
    return d
end

fetch("https://google.com")
    :next(function(body)
        print("Body is: ", body)
    end)
```

Chaining promises
```lua
fetch("https://google.com")
    :next(function(body)
        print("Body is: ", body)
        return #body
    end)
    :next(function(length)
        print("And the length is: ", length)
    end)
```

Handling rejection
```lua
fetch("https://google.com")
    :next(function(body)
        print("Body is: ", body)
        return #body
    end)
    :next(function(length)
        print("And the length is: ", length)
    end)
    :catch(function(err)
        print("Oops!", err)
    end)
```
or
```lua
fetch("https://google.com")
    :next(function(body)
        print("Body is: ", body)
        return #body
    end)
    :next(function(length)
        print("And the length is: ", length)
    end)
    :next(nil, function(err)
        print("Oops!", err)
    end)
```

## Usage
### Promise
From MDN:
> The `Promise` object represents the eventual completion (or failure) of an asynchronous operation, and its resulting value.

#### `Promise:catch(onRejected)`
This method adds a rejection handler to the promise chain. It is equivalent to doing `Promise:next(nil, onRejected)`.

#### `Promise:next(onResolved, onRejected)`
See the [Promise/A+ `then` method](https://promisesaplus.com/#the-then-method).

#### `Promise:reject(reason)`
Rejects the promise with the given reason.

#### `Promise:resolve(value)`
Resolves the promise to the given value. 

### deferred
This is the actual library for creating promises.

#### `deferred.all(promises)`
Returns a `Promise` that resolves to a table where the *i*th element is what the *i*th promise in `promises` resolves to after all the promises have been resolved. The promise will reject with the reason of the first promise within `promises` to reject. If `promises` is empty, then the returned promise resolves to an empty table `{}`.

Example:
```lua
local function fetch(url)
    local d = deferred.new()
    http.Fetch(url, function(body)
        d:resolve(body)
    end, function(err)
        d:reject(err)
    end)
    return d
end

deferred.all({ fetch("https://google.com"), fetch("https://github.com") })
    :next(PrintTable)
-- HTML is printed in console...
```

#### `deferred.any(promises)`
Returns a `Promise` that resolves to the value of the first resolved promise in `promises`.

Example:
```lua
local snails = {}
for i = 1, 10 do
    local d = deferred.new()
    timer.Simple(math.random(1, 5), function()
        d:resolve(i)
    end)
    snails[#snails + 1] = d
end

deferred.any(snails):next(function(winner)
    print("Winner is snail #"..winner)
end)
-- Winner is snail #5
```

#### `deferred.each(promises, fn)`
For each promise `p` in the `promises` table, as soon as `p` resolves to a value `x`, `fn` is called with `x` as the first argument, the index corresponding to `p` in `promises` as the second argument, and the length of `promises` as the third argument. This method returns a `Promise` that is resolved to `nil` after all the promises have finished. Note that this happens **sequentially**. If a promise in `promises` is the first to be rejected, then the returned promise will reject with the same reason.

#### `deferred.filter(promises, filter)`
This function takes a table of promises and a function `filter` and returns a promise that resolves to a table of values that satisfy `filter` in order of the given `promises`. As the *i*th promise in `promises` resolves to a value `x`, `filter` is called with `x` as the first argument, *i* as the second argument (the index of the promise), and the length of `promises` as the third argument. If `filter` returns a truthy value, then `x` as added to the table that the returned promise resolves to. If a promise in `promises` is the first to be rejected, then the returned promise will reject with the same reason.

Example:
```lua
local function fetch(url)
    local d = deferred.new()
    http.Fetch(url, function(body, size, headers, code)
        d:resolve({ url = url, code = code })
    end, function(err)
        d:reject(err)
    end)
    return d
end

deferred.filter(
    { fetch("https://google.com"), fetch("https://httpstat.us/404") },
    function(res) return res.code ~= 404 end
):next(PrintTable)
-- 1:
--                code    =       200
--                url     =       https://google.com
```

#### `deferred.fold(promises, fn, initial)`
The promises in `promises` are evaluated **sequentially** and the left-folds the resolved value into a single value using the `fn` accumulator function. This method returns a `Promise` that resolves to the accumulated value. If a promise in `promises` is the first to be rejected, then the returned promise will reject with the same reason. See https://en.wikipedia.org/wiki/Fold_(higher-order_function)

Example:
```lua
local snails = {}
for i = 1, 10 do
    local d = deferred.new()
    local time = math.random(1, 5)
    timer.Simple(time, function()
        d:resolve(time)
    end)
    snails[#snails + 1] = d
end

deferred.fold(snails, function(acc, time) return math.max(acc, time) end, 0)
    :next(function(longestTime)
        print("The slowest snail took "..longestTime.." seconds to finish.")
    end)
-- The slowest snail took 5 seconds to finish.
```

#### `deferred.isPromise(value)`
Returns `true` if `value` is a promise, `false` otherwise.

#### `deferred.map(values, fn)`
Given a table of values and a function `fn` that takes in one of the values as input and returns a promise, this method returns a new promise that resolves to a table where the *i*th value is the the resolved value of `fn(values[i])`. If a promise returned by `fn` is the first to be rejected, then the returned promise will reject with the same reason. See https://en.wikipedia.org/wiki/Map_(higher-order_function)

Example:
```lua
local urls = {"https://google.com", "https://garrysmod.com"}

local function fetch(url)
    local d = deferred.new()
    http.Fetch(url, function(body, size, headers, code)
        d:resolve(size)
    end, function(err)
        d:reject(err)
    end)
    return d
end

deferred.map(urls, fetch):next(PrintTable)
-- 1       =       11384
-- 2       =       23297
```

#### `deferred.new()`
Returns a new `Promise` object.

#### `deferred.reject(reason)`
Returns a new `Promise` object that immediately rejects with `reason` as the reason.

#### `deferred.resolve(value)`
Returns a new `Promise` object that immediately resolves to `value`.

#### `deferred.some(promises, count)`
Give a table of promises and a non-negative integer `count`, this method returns a promise that resolves to a table of the first `count` resolved values in the order that the promises are resolved. If a promise in `promises` is the first to be rejected, then the returned promise will reject with the same reason.

Example:
```lua
local snails = {}
for i = 1, 10 do
    local d = deferred.new()
    timer.Simple(math.random(1, 10), function()
        d:resolve(i)
    end)
    snails[#snails + 1] = d
end

deferred.some(snails, 3):next(function(results)
    print("First place is snail #"..results[1])
    print("Second place is snail #"..results[2])
    print("Third place is snail #"..results[3])
end)

-- First place is snail #6
-- Second place is snail #9
-- Third place is snail #5
```

## Testing
To test, use `lua_openscript path/to/deferred_test.lua` in your console. Or, you can include the `deferred_test.lua` file directly.

## Credits
Inspired by [zserge's lua-promises](https://github.com/zserge/lua-promises/).
