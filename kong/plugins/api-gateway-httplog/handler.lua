-- If you're not sure your plugin is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the plugin is being loaded at least.

--assert(ngx.get_phase() == "timer", "The world is coming to an end!")

-- loads the HTTP module and any libraries it requires
local http = require("socket.http")
local JSON = require("JSON")

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

-- load the base plugin object and create a subclass
local plugin = require("kong.plugins.base_plugin"):extend()

-- constructor
function plugin:new()
  plugin.super.new(self, plugin_name)
  http.TIMEOUT = 2
  -- do initialization here, runs in the 'init_by_lua_block', before worker processes are forked

end

---------------------------------------------------------------------------------------------
-- In the code below, just remove the opening brackets; `[[` to enable a specific handler
--
-- The handlers are based on the OpenResty handlers, see the OpenResty docs for details
-- on when exactly they are invoked and what limitations each handler has.
--
-- The call to `.super.xxx(self)` is a call to the base_plugin, which does nothing, except logging
-- that the specific handler was executed.
---------------------------------------------------------------------------------------------


--[[ handles more initialization, but AFTER the worker process has been forked/created.
-- It runs in the 'init_worker_by_lua_block'
function plugin:init_worker()
  plugin.super.access(self)

  -- your custom code here

end --]]

--[[ runs in the ssl_certificate_by_lua_block handler
function plugin:certificate(plugin_conf)
  plugin.super.access(self)

  -- your custom code here

end --]]

--[[ runs in the 'rewrite_by_lua_block' (from version 0.10.2+)
-- IMPORTANT: during the `rewrite` phase neither the `api` nor the `consumer` will have
-- been identified, hence this handler will only be executed if the plugin is
-- configured as a global plugin!
function plugin:rewrite(plugin_conf)
  plugin.super.rewrite(self)

  -- your custom code here

end --]]

--[[ runs in the 'access_by_lua_block'
function plugin:access(plugin_conf)
  plugin.super.access(self)

  -- your custom code here
  ngx.req.set_header("Hello-World", "this is on a request")

end --]]

--[[ runs in the 'header_filter_by_lua_block'
function plugin:header_filter(plugin_conf)
  plugin.super.access(self)

  -- your custom code here, for example;
  ngx.header["Bye-World"] = "this is on the response"

end --]]

--[[ runs in the 'body_filter_by_lua_block'
function plugin:body_filter(plugin_conf)
  plugin.super.access(self)

  -- your custom code here

end --]]

-- runs in the 'log_by_lua_block'
function plugin:log(plugin_conf)

  local querystring = ngx.encode_args(ngx.req.get_uri_args())
  local host = ngx.var.host
  local remote_addr = ngx.var.remote_addr
  local uri = ngx.var.uri
  local start_time_nginx = ngx.req.start_time()
  local request_time = ngx.now() - start_time_nginx
  local status_code = ngx.status
  local user_agent = ngx.req.get_headers()['User-Agent']
  local token = ngx.req.get_headers()['jwt']
  local x_source = ngx.req.get_headers()['X-Source']
  local request_method = ngx.req.get_method()
  local referer = ngx.req.get_headers()['Referer']

  if (type(user_agent) == "table") then
    user_agent = user_agent[1]
  end

  if (type(token) == "table") then
    token = token[1]
  end

  if token ~= nil then
    token = tostring(token)
  end

  user_agent = tostring(user_agent)

  local start_time = os.date("!%Y-%m-%dT%TZ", start_time_nginx)
  local JSONRequestArray = {
    ip_address = remote_addr,
    host = host,
    uri = uri,
    querystring = querystring,
    start_time = start_time,
    request_time = request_time,
    status_code = status_code,
    user_agent = user_agent,
    token = token,
    x_source = x_source,
    request_method = request_method,
    referer = referer
  }

  if plugin_conf.api_data then
    JSONRequestArray['api_data'] = plugin_conf.api_data
  else
    JSONRequestArray['api_data'] = nil
  end

  local jsonRequest = JSON:encode(JSONRequestArray)

  local headers = {
    ['content-type'] = "application/json",
    ['content-length'] = string.len(jsonRequest),
    ["connection"] = "close",
    Authorization = "Token " .. plugin_conf.token
  }
  if plugin_conf.host then
    headers['Host'] = plugin_conf.host
  end
  local result, respcode, respheaders, respstatus = http.request {
    url = plugin_conf.endpoint,
    method = "POST",
    headers = headers,
    source = ltn12.source.string(jsonRequest)
  }
  print("[ api-gateway-httplog ] Got a '" .. tostring(respcode) .. "' response code from API-mgmt(" .. plugin_conf.endpoint .. ").")

end


-- set the plugin priority, which determines plugin execution order
plugin.PRIORITY = 9

-- return our plugin object
return plugin
