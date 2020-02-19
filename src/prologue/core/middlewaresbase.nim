import asyncdispatch

import context, route


proc doNothingClosureMiddleware*(): HandlerAsync


proc test() {.async.} =
  var doNothing: seq[HandlerAsync] = @[]
  doNothing.add doNothingClosureMiddleware()

waitFor test()

proc switch*(ctx: Context) {.async.} =
  ## TODO make middlewares check in compile time
  if ctx.middlewares.len == 0:
    let
      handler = findHandler(ctx)
      next = handler.handler
    var
      middlewares = handler.middlewares

    # for findHandler in handler.excludeMiddlewares:
    #   let idx = middlewares.find(findHandler)
    #   if idx != -1:
    #     middlewares[idx] = doNothingClosureMiddleware()

    ctx.middlewares = middlewares & next
    ctx.first = false

  ctx.size += 1
  if ctx.size <= ctx.middlewares.len:
    let next = ctx.middlewares[ctx.size - 1]
    await next(ctx)
  elif ctx.first:
    let
      handler = findHandler(ctx)
      lastHandler = handler.handler
      middlewares = handler.middlewares
    ctx.middlewares = ctx.middlewares & middlewares & lastHandler
    ctx.first = false
    let next = ctx.middlewares[ctx.size - 1]
    await next(ctx)


proc doNothingClosureMiddleware*(): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    await switch(ctx)

# type
#   Handler = proc() {.closure.}

# proc doNothingClosureMiddleware*(): Handler =
#   result = proc(ctx: Context) {.async.} =
#     discard

# discard doNothingClosureMiddleware()

# proc test() =
#   let x: seq[HandlerAsync] =
#   let x: HandlerAsync = doNothingClosureMiddleware()

# test()
