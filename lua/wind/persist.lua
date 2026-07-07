local fn = vim.fn

local M = {}

--- Test hook: alternate store directory.
---@type string|nil
M._dir = nil

local cached_path = nil

--- One JSON file per project, keyed by the cwd at first use.
---@return string
local function store_path()
	if not cached_path then
		local dir = M._dir or (fn.stdpath("data") .. "/wind")
		local key = fn.getcwd():gsub("[\\/:]", "%%")
		cached_path = dir .. "/" .. key .. ".json"
	end
	return cached_path
end

--- Test hook: repoint the store and forget the cached path.
---@param dir string|nil
function M._reset(dir)
	M._dir = dir
	cached_path = nil
end

--- Test hook: the resolved store path.
---@return string
function M._path()
	return store_path()
end

---@param node any
---@return boolean
local function valid_tree(node)
	if type(node) ~= "table" then
		return false
	end
	if node[1] == "leaf" then
		local leaf = node[2]
		return type(leaf) == "table"
			and type(leaf.path) == "string"
			and type(leaf.view) == "table"
			and type(leaf.width) == "number"
			and type(leaf.height) == "number"
	end
	if (node[1] ~= "row" and node[1] ~= "col") or type(node[2]) ~= "table" or #node[2] == 0 then
		return false
	end
	for _, child in ipairs(node[2]) do
		if not valid_tree(child) then
			return false
		end
	end
	return true
end

--- Read the project's breaths. Anything malformed discards the whole file:
--- a persisted layout must be trustworthy or absent, never half right.
---@return { held: WindBreath[], last_visited: integer|nil }|nil
function M.load()
	local file = io.open(store_path(), "r")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()

	local ok, decoded = pcall(vim.json.decode, text)
	if not ok or type(decoded) ~= "table" or decoded.version ~= 1 or type(decoded.held) ~= "table" then
		return nil
	end

	local held = {}
	for _, entry in ipairs(decoded.held) do
		if type(entry) ~= "table" or not valid_tree(entry.snapshot) then
			return nil
		end
		held[#held + 1] = { snapshot = entry.snapshot }
	end

	local last_visited = decoded.last_visited
	if type(last_visited) ~= "number" or not held[last_visited] then
		last_visited = nil
	end

	return { held = held, last_visited = last_visited }
end

--- Write-through on every mutation; the file is tiny and the ops are rare.
---@param held WindBreath[]
---@param last_visited integer|nil
function M.save(held, last_visited)
	local path = store_path()
	fn.mkdir(fn.fnamemodify(path, ":h"), "p")

	local ok, encoded = pcall(vim.json.encode, { version = 1, held = held, last_visited = last_visited })
	if not ok then
		return
	end

	local file = io.open(path .. ".tmp", "w")
	if not file then
		require("wind.notify").warn("Could not save breaths to " .. path)
		return
	end
	file:write(encoded)
	file:close()
	os.rename(path .. ".tmp", path)
end

function M.wipe()
	os.remove(store_path())
end

return M
