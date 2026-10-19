-- Run from the repository root:
-- nvim --headless -u NONE -i NONE -l tests/health.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local health = require("nvim-image-paste.health")
local uv = vim.uv
local env_names = { "WAYLAND_DISPLAY", "XDG_SESSION_TYPE", "DISPLAY", "SSH_CONNECTION", "SSH_TTY" }
local original = {
    health = vim.health,
    has = vim.fn.has,
    executable = vim.fn.executable,
    provider = vim.fn["provider#clipboard#Executable"],
    tmpdir = uv.os_tmpdir,
    mkdtemp = uv.fs_mkdtemp,
    open = uv.fs_open,
    system = vim.system,
    env = {},
}
for _, name in ipairs(env_names) do
    original.env[name] = vim.env[name]
end
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local messages, count = {}, 0
local function contains(level, text)
    for _, entry in ipairs(messages) do
        if entry.level == level and entry.text:find(text, 1, true) then
            return true
        end
    end
    error("Missing " .. level .. ": " .. text .. "\n" .. vim.inspect(messages))
end
local function test(name, setup, verify)
    messages = {}
    vim.health = {}
    for _, level in ipairs({ "start", "ok", "warn", "error", "info" }) do
        vim.health[level] = function(text)
            table.insert(messages, { level = level, text = text })
        end
    end
    for _, key in ipairs(env_names) do
        vim.env[key] = nil
    end
    vim.fn.has = function(feature)
        return (feature == "nvim-0.10" or feature == "unix") and 1 or 0
    end
    vim.fn.executable = function()
        return 1
    end
    vim.fn["provider#clipboard#Executable"] = function()
        return "test clipboard"
    end
    uv.os_tmpdir = function()
        return root
    end
    uv.fs_mkdtemp = original.mkdtemp
    uv.fs_open = original.open
    vim.system = function()
        error("Health checks must not execute clipboard commands")
    end
    setup()
    health.check()
    verify()
    local scan = assert(uv.fs_scandir(root))
    assert(not uv.fs_scandir_next(scan), "Health check leaked temporary files")
    count = count + 1
    print("ok - " .. name)
end

local ok, err = xpcall(function()
    test("Wayland and X11 backends, storage, and text provider", function()
        vim.env.WAYLAND_DISPLAY = "test"
        vim.env.DISPLAY = ":test"
    end, function()
        contains("ok", "Neovim 0.10+")
        contains("ok", "Wayland: wl-paste")
        contains("ok", "X11: xclip is available (fallback backend)")
        contains("ok", "Temporary files can be written")
        contains("ok", "Text clipboard provider: test clipboard")
    end)
    test("missing Linux dependencies", function()
        vim.env.XDG_SESSION_TYPE = "wayland"
        vim.env.DISPLAY = ":test"
        vim.fn.executable = function()
            return 0
        end
    end, function()
        contains("warn", "Wayland: wl-paste is missing")
        contains("warn", "X11: xclip is missing")
    end)
    test("headless and remote session without text provider", function()
        vim.env.SSH_CONNECTION = "test"
        vim.fn["provider#clipboard#Executable"] = function()
            return ""
        end
    end, function()
        contains("warn", "No Wayland or X11 session")
        contains("warn", "No text clipboard provider")
        contains("info", "SSH session")
    end)
    for _, available in ipairs({ true, false }) do
        test("macOS backend available: " .. tostring(available), function()
            vim.fn.has = function()
                return 1
            end
            vim.fn.executable = function(command)
                assert(command == "osascript")
                return available and 1 or 0
            end
        end, function()
            contains(available and "ok" or "error", "macOS: osascript")
        end)
    end
    test("unsupported platform", function()
        vim.fn.has = function(feature)
            return feature == "nvim-0.10" and 1 or 0
        end
    end, function()
        contains("warn", "No image clipboard backend")
    end)
    test("old Neovim", function()
        vim.fn.has = function()
            return 0
        end
    end, function()
        contains("error", "Neovim 0.10+ is required")
    end)
    test("unwritable temp directory", function()
        uv.fs_mkdtemp = function()
            return nil, "permission denied"
        end
    end, function()
        contains("error", "Cannot create a temporary directory: permission denied")
    end)
    test("temp file creation failure cleans up", function()
        uv.fs_open = function()
            return nil, "permission denied"
        end
    end, function()
        contains("error", "Cannot write temporary files: permission denied")
    end)
end, debug.traceback)

vim.health = original.health
vim.fn.has = original.has
vim.fn.executable = original.executable
vim.fn["provider#clipboard#Executable"] = original.provider
uv.os_tmpdir = original.tmpdir
uv.fs_mkdtemp = original.mkdtemp
uv.fs_open = original.open
vim.system = original.system
for _, name in ipairs(env_names) do
    vim.env[name] = original.env[name]
end
vim.fn.delete(root, "rf")
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end
print(string.format("Passed %d health tests", count))
vim.cmd("qa!")
