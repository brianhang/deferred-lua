# deferred-lua
Lua implementation of the [Promises/A+](https://promisesaplus.com/) standard for Garry's Mod. One different is the `next` is used instead of `then` since `then` is a keyword in Lua.

## Installation
Place the `deferred.lua` file somewhere and include it with
```lua
include("path/to/deferred.lua")
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
For each promise `p` in the `promises` table, as soon as `p` resolves to a value `x`, `fn` is called with `x` as the first argument, the index corresponding to `p` in `promises` as the second argument, and the length of `promises` as the third argument. This method returns a `Promise` that is resolved to `nil` after all the promises have finished. Note that this happens **sequentially**. The returned promise is rejected with the same reason as the first promise to get rejected.

#### `deferred.filter(promises, filter)`
Returns a `Promise` which resolves to a table containing the resolved values in `promises` that satisfies `filter`. To satisfy `filter, `filter(x)` must be true where `x` is the resolved value of a promise.

#### `deferred.fold(promises, fn, initial)`
The promises in `promises` are evaluated **sequentially** and the left-folds the resolved value into a single value using the `fn` accumulator function. This method returns a `Promise` that resolves to the accumulated value. See https://en.wikipedia.org/wiki/Fold_(higher-order_function)

Example:
```lua
local snails = {}
for i = 1, 10 do
    local d = deferred.new()
    local time = math.random(1, 5)
    timer.Simple(math.random(1, 5), function()
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
#### `deferred.new()`
#### `deferred.reject(reason)`
#### `deferred.resolve(value)`
#### `deferred.some(promises, count)`

## Credits
Inspired by [zserge's lua-promises](https://github.com/zserge/lua-promises/).
