local json = require "json"
local lyaml = require 'lyaml'
local http = require "resty.http"

local CONFIG_FILE_PATH = '/code/config/backends.yaml'
local TIMEOUT = 1000


local function load_configs()
    local config_file = io.open(CONFIG_FILE_PATH, 'r')
    if not config_file then
        ngx.log(ngx.ERR, 'File missing, cannot parse: ' .. CONFIG_FILE_PATH)
        return nil
    end

    local yaml_content = config_file:read('*a')
    config_file:close()

    return lyaml.load(yaml_content)
end


local function proxy_request(backend, uri)
    local httpc = http.new()
    httpc:set_timeout(TIMEOUT)
    local uri = 'http://' .. backend .. uri
    local response, err = httpc:request_uri(uri, {
        method = 'GET',
    })

    if err ~= nil then
        ngx.log(ngx.ERR, 'Request failed: ' .. uri .. ' error: ' .. err)
        return nil
    elseif response.status ~= 200 then
        ngx.log(ngx.ERR, 'Request failed: ' .. uri .. ' status: ' .. tostring(response.status) .. ' reason: ' .. tostring(response.reason))
        return nil
    end
    return response.body
end


local function get_from_zipkin()
    local res = {}
    local configs = load_configs()
    for _, backend in ipairs(configs['backends']) do
        response = proxy_request(backend, ngx.var.request_uri)
        if response ~= nil then
            services = json:decode(response)
            for _, s in ipairs(services) do
                table.insert(res, s)
            end
        end
    end
    return ngx.HTTP_OK, json:encode(res)
end


local function main()
    local status = ngx.HTTP_METHOD_NOT_IMPLEMENTED
    local body = nil

    local known_paths = {
        ['/zipkin/api/v2/services'] = true,
        ['/zipkin/api/v2/spans'] = true,
        ['/zipkin/api/v2/traces'] = true,
        ['/zipkin/api/v2/dependencies'] = true,
    }
    if known_paths[ngx.var.uri] or string.find(ngx.var.uri, '/zipkin/api/v2/trace/') then
        status, body = get_from_zipkin()
    end
    ngx.status = status
    ngx.print(body)
    ngx.flush()
    ngx.eof()
end


main()

-- vim: ts=4 sw=4 et
