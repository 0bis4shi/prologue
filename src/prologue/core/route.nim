import httpcore, cgi
import hashes, strutils, strtabs, tables

import context

import regex

when not defined(production):
  import ../naive/request

type
  PrologueError* = object of Exception
  RouteError* = object of PrologueError
  RouteResetError* = object of RouteError
  DuplicatedRouteError* = object of RouteError

  WebAction* = enum
    Http, Websocket

  UrlPattern* = tuple
    route: string
    matcher: HandlerAsync
    httpMethod: seq[HttpMethod]
    webAction: WebAction
    middlewares: seq[HandlerAsync]


proc initPath*(route: string, httpMethod = HttpGet): Path =
  Path(route: route, httpMethod: httpMethod)

proc initRePath*(route: Regex, httpMethod = HttpGet): RePath =
  RePath(route: route, httpMethod: httpMethod)

proc pattern*(route: string, handler: HandlerAsync, httpMethod = HttpGet,
    webAction: WebAction = Http, middlewares: seq[HandlerAsync] = @[]): UrlPattern =
  (route, handler, @[httpMethod], webAction, middlewares)

proc pattern*(route: string, handler: HandlerAsync, httpMethod: seq[HttpMethod],
    webAction: WebAction = Http, middlewares: seq[HandlerAsync] = @[]): UrlPattern =
  (route, handler, httpMethod, webAction, middlewares)

proc hash*(x: Path): Hash =
  var h: Hash = 0
  h = h !& hash(x.route)
  h = h !& hash(x.httpMethod)
  result = !$h

proc newPathHandler*(handler: HandlerAsync, middlewares: seq[HandlerAsync] = @[]): PathHandler =
  PathHandler(handler: handler, middlewares: middlewares)

proc newRouter*(): Router =
  Router(callable: initTable[Path, PathHandler]())

proc newReRouter*(): ReRouter =
  ReRouter(callable: newSeq[(RePath, PathHandler)]())

proc findHandler*(ctx: Context): PathHandler =
  ## fixed route -> regex route -> params route
  ## Follow the order of addition
  let rawPath = initPath(route = ctx.request.url.path,
    httpMethod = ctx.request.reqMethod)

  # find fixed route
  if rawPath in ctx.router.callable:
    return ctx.router.callable[rawPath]

  # find regex route
  for (path, pathHandler) in ctx.reRouter.callable:
    if path.httpMethod != rawPath.httpMethod:
      continue
    var m: RegexMatch
    echo rawPath
    if rawPath.route.match(path.route, m):
      for name in m.groupNames():
        ctx.request.pathParams[name] = m.groupFirstCapture(name, rawPath.route)
      return pathHandler

  let
    pathList = rawPath.route.split("/")

  # find params route
  for route, handler in ctx.router.callable.pairs:
    let routeList = route.route.split("/")
    var flag = true
    if pathList.len == routeList.len:
      for idx in 0 ..< pathList.len:
        if pathList[idx] == routeList[idx]:
          continue

        if routeList[idx].startsWith("{"):
          # should be checked in addRoute
          let key = routeList[idx]
          if key.len <= 2:
            raise newException(RouteError, "{} shouldn't be empty!")
          let
            params = key[1 ..< ^1]

          ctx.request.pathParams[params] = decodeUrl(pathList[idx])
        else:
          flag = false
          break
      if flag:
        return handler
  return newPathHandler(defaultHandler)
