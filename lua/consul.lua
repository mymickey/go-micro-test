--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

local local_conf         = require("apisix.core.config_local").local_conf()
local http               = require("resty.http")
local core               = require("apisix.core")
local ipmatcher          = require("resty.ipmatcher")
local ipairs             = ipairs
local tostring           = tostring
local type               = type
local math_random        = math.random
local error              = error
local ngx                = ngx
local ngx_timer_at       = ngx.timer.at
local ngx_timer_every    = ngx.timer.every
local string_sub         = string.sub
local string_find        = string.find
local log                = core.log

local default_weight
local applications

local schema = {
    type = "object",
    properties = {
        host = {
            type = "array",
            minItems = 1,
            items = {
                type = "string",
            },
        },
        prefix = {type = "string"},
        fetch_interval = {type = "integer", minimum = 1, default = 30},
        weight = {type = "integer", minimum = 0},
        timeout = {
            type = "object",
            properties = {
                connect = {type = "integer", minimum = 1, default = 2000},
                send = {type = "integer", minimum = 1, default = 2000},
                read = {type = "integer", minimum = 1, default = 5000},
            }
        },
    },
    required = {"host"}
}


local _M = {
    version = 0.1,
}


local function service_info()
    local host = local_conf.discovery.consul and local_conf.discovery.consul.host
    if not host then
        log.error("do not set consul.host")
        return
    end

    local basic_auth
    -- TODO Add health check to get healthy nodes.
    local url = host[math_random(#host)]
    local auth_idx = string_find(url, "@", 1, true)
    if auth_idx then
        local protocol_idx = string_find(url, "://", 1, true)
        local protocol = string_sub(url, 1, protocol_idx + 2)
        local user_and_password = string_sub(url, protocol_idx + 3, auth_idx - 1)
        local other = string_sub(url, auth_idx + 1)
        url = protocol .. other
        basic_auth = "Basic " .. ngx.encode_base64(user_and_password)
    end
    if local_conf.discovery.consul.prefix then
        url = url .. local_conf.discovery.consul.prefix
    end
    if string_sub(url, #url) ~= "/" then
        url = url .. "/"
    end

    return url, basic_auth
end


local function request(request_uri, basic_auth, method, path, query, body)
    local url = request_uri .. path
    log.warn("consul url:", url, ".")
    local headers = core.table.new(0, 5)
    headers['Connection'] = 'Keep-Alive'
    headers['Accept'] = 'application/json'

    if basic_auth then
        headers['Authorization'] = basic_auth
    end

    if body and 'table' == type(body) then
        local err
        body, err = core.json.encode(body)
        if not body then
            return nil, 'invalid body : ' .. err
        end
        -- log.warn(method, url, body)
        headers['Content-Type'] = 'application/json'
    end

    local httpc = http.new()
    local timeout = local_conf.discovery.consul.timeout
    local connect_timeout = timeout and timeout.connect or 2000
    local send_timeout = timeout and timeout.send or 2000
    local read_timeout = timeout and timeout.read or 5000
    log.warn("connect_timeout:", connect_timeout, ", send_timeout:", send_timeout,
            ", read_timeout:", read_timeout, ".")
    httpc:set_timeouts(connect_timeout, send_timeout, read_timeout)
    return httpc:request_uri(url, {
        version = 1.1,
        method = method,
        headers = headers,
        query = query,
        body = body,
        ssl_verify = false,
    })
end

local function parse_micro_instance(item)
    local ip = item.ServiceTaggedAddresses.lan_ipv4.Address
    local port = item.ServiceTaggedAddresses.lan_ipv4.Port
    local server_name = item.ServiceName
    return ip, port, server_name
end

local function get_all_service_names(request_uri,basic_auth)
    local svc = core.table.new(1, 0)
    local res, err = request(request_uri, basic_auth, "GET", "v1/catalog/services")
    if not res then
        log.error("failed to fetch catalog", err)
        return
    end
    if not res.body or res.status ~= 200 then
        log.error("failed to fetch catalog, status = ", res.status)
        return
    end
    local json_str = res.body
    local data, err = core.json.decode(json_str)
    if not data then
        log.error("invalid get svc name response body: ", json_str, " err: ", err)
        return
    end
    local apps = data
    local up_apps = core.table.new(0, #apps)
    
    log.error("resp data get all svc names: ",json_str )
    for server_name, _ in pairs(apps) do
        local is_web = string_find(server_name, ".web", 1, true)
        if is_web then
            core.table.insert(svc,server_name)
        end
    end
    return svc
end

local function get_service_detail(request_uri,basic_auth,names)
    local up_apps = core.table.new(0, 1)
    for _, svc_name in pairs(names) do
        log.warn("get_service_detail name ", svc_name)
        local svc_path = "v1/catalog/service/" .. svc_name
        log.warn("get_service_detail path ",svc_path)
        local res, err = request(request_uri, basic_auth, "GET", svc_path)
        if not res then
            log.error("failed to fetch svc detail", err)
            return
        end
        if not res.body or res.status ~= 200 then
            log.error("failed to fetch svc detail, status = ", res.status)
            return
        end
        local json_str = res.body
        local data, err = core.json.decode(json_str)
        if not data then
            log.error("invalid svc detail response body: ", json_str, " err: ", err)
            return
        end
        local apps = data

        log.error("resp data: ",json_str )
        for _, app in pairs(apps) do
            local ip, port, server_name = parse_micro_instance(app)
            log.warn("get service ",server_name, " ip ",ip ," port ",port)
            if ip and port and server_name then
                local nodes = up_apps[server_name]
                if not nodes then
                    nodes = core.table.new(1, 0)
                    up_apps[server_name] = nodes
                end
                core.table.insert(nodes, {
                    host = ip,
                    port = port,
                    weight = default_weight,
                })
            end
        end
    end
    return up_apps
end

local function fetch_full_registry(premature)
    if premature then
        return
    end

    local request_uri, basic_auth = service_info()
    if not request_uri then
        return
    end

    local names = get_all_service_names(request_uri,basic_auth)
    local up_apps = get_service_detail(request_uri,basic_auth,names)
    
    applications = up_apps
    log.warn("update services: ", core.json.encode(applications))
end


function _M.nodes(service_name)
    if not applications then
        log.error("failed to fetch nodes for : ", service_name)
        return
    end

    return applications[service_name]
end


function _M.init_worker()
    if not local_conf.discovery.consul then
        error("do not set consul")
        return
    end
    if not local_conf.discovery.consul.host then
        error("do not set consul.host")
        return
     end
    if not #local_conf.discovery.consul.host == 0 then
        error("do not set consul.host == 0")
        return
    end

    local ok, err = core.schema.check(schema, local_conf.discovery.consul)
    if not ok then
        error("invalid consul configuration: " .. err)
        return
    end
    default_weight = local_conf.discovery.consul.weight or 100
    log.info("default_weight:", default_weight, ".")
    local fetch_interval = local_conf.discovery.consul.fetch_interval or 30
    log.info("fetch_interval:", fetch_interval, ".")
    ngx_timer_at(0, fetch_full_registry)
    ngx_timer_every(fetch_interval, fetch_full_registry)
end


return _M