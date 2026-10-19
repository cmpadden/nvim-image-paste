local M = {}
local uv = vim.uv or vim.loop

local function executable(command)
    return vim.fn.executable(command) == 1
end

local function check_backend()
    if vim.fn.has("macunix") == 1 then
        if executable("osascript") then
            vim.health.ok("macOS: osascript is available (built-in AppKit/JXA backend)")
        else
            vim.health.error("macOS: osascript is missing from PATH")
        end
        return
    end
    if vim.fn.has("unix") ~= 1 then
        vim.health.warn("No image clipboard backend for this platform; text fallback only")
        return
    end

    local wayland = vim.env.WAYLAND_DISPLAY or vim.env.XDG_SESSION_TYPE == "wayland"
    local x11 = vim.env.DISPLAY ~= nil
    if wayland then
        if executable("wl-paste") then
            vim.health.ok("Wayland: wl-paste is available")
        else
            vim.health.warn("Wayland: wl-paste is missing", { "Install wl-clipboard" })
        end
    end
    if x11 then
        if executable("xclip") then
            vim.health.ok("X11: xclip is available" .. (wayland and " (fallback backend)" or ""))
        else
            vim.health.warn(
                "X11: xclip is missing",
                { "Install xclip for X11 image clipboard access" }
            )
        end
    end
    if not wayland and not x11 then
        vim.health.warn("No Wayland or X11 session detected; image clipboard access is unavailable")
    end
end

local function check_storage()
    local dir, err = uv.fs_mkdtemp(uv.os_tmpdir() .. "/nvim-image-paste-health-XXXXXX")
    if not dir then
        vim.health.error("Cannot create a temporary directory: " .. tostring(err))
        return
    end
    local path = dir .. "/probe"
    local fd, open_err = uv.fs_open(path, "wx", 384)
    local ok, write_err
    if fd then
        ok, write_err = uv.fs_write(fd, "probe", 0)
        uv.fs_close(fd)
    end
    local removed = vim.fn.delete(dir, "rf")
    if not fd or ok ~= 5 then
        vim.health.error("Cannot write temporary files: " .. tostring(open_err or write_err))
    else
        vim.health.ok("Temporary files can be written to " .. uv.os_tmpdir())
    end
    if removed ~= 0 then
        vim.health.warn("Could not remove health-check directory: " .. dir)
    end
    vim.health.info("Saved clipboard images survive Neovim exit; the OS may eventually purge them")
end

function M.check()
    vim.health.start("nvim-image-paste")
    if vim.fn.has("nvim-0.10") == 1 then
        vim.health.ok("Neovim 0.10+ is available")
    else
        vim.health.error("Neovim 0.10+ is required (vim.system and vim.uv)")
        return
    end

    check_backend()
    check_storage()

    -- Discover the provider without reading or changing clipboard contents.
    local ok, provider = pcall(vim.fn["provider#clipboard#Executable"])
    if ok and type(provider) == "string" and provider ~= "" then
        vim.health.ok("Text clipboard provider: " .. provider)
    else
        vim.health.warn("No text clipboard provider detected", {
            "Configure vim.g.clipboard or install a provider; see :help clipboard",
        })
    end
    if vim.env.SSH_CONNECTION or vim.env.SSH_TTY then
        vim.health.info(
            "SSH session: images come from this host's clipboard; OSC 52 only transports text"
        )
    end
end

return M
