script_name("AutoUpdater")
script_version("1.2.10b")

local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- ================= НАСТРОЙКИ ССЫЛОК И ВЕРСИИ =================
local CURRENT_VERSION = "1.2.10b" 

local INFO_URL   = "https://raw.githubusercontent.com/1XAIZEN/script/refs/heads/main/update.json"
local SCRIPT_URL = "https://raw.githubusercontent.com/1XAIZEN/script/refs/heads/main/!autoreport.lua"
-- =============================================================

local showUpdateWindow = imgui.new.bool(false)
local updateData = {
    version = "",
    changelog = ""
}
local isDownloading = false
local downloadStatusText = ""

-- Функция проверки обновлений
function checkUpdate()
    local tempFilePath = getWorkingDirectory() .. "\\update_temp.json"
    
    downloadUrlToFile(INFO_URL, tempFilePath, function(id, status, p1, p2)
        if status == 6 then
            if doesFileExist(tempFilePath) then
                local file = io.open(tempFilePath, "r")
                if file then
                    local content = file:read("*a")
                    file:close()
                    os.remove(tempFilePath)

                    local ok, parsed = pcall(decodeJson, content)
                    if ok and parsed and parsed.version then
                        local remoteVer = tostring(parsed.version):match("^%s*(.-)%s*$")
                        local currentVer = tostring(CURRENT_VERSION):match("^%s*(.-)%s*$")

                        if remoteVer ~= currentVer then
                            updateData.version = remoteVer
                            updateData.changelog = parsed.changelog or "Список изменений не указан."
                            showUpdateWindow[0] = true
                        end
                    end
                end
            end
        end
    end)
end

-- Функция скачивания и замены скрипта
function installUpdate()
    isDownloading = true
    downloadStatusText = "Скачивание обновления..."
    
    local currentScriptPath = thisScript().path
    
    downloadUrlToFile(SCRIPT_URL, currentScriptPath, function(id, status, p1, p2)
        if status == 6 then
            downloadStatusText = "Успешно! Перезагрузка скрипта..."
            lua_thread.create(function()
                wait(1200)
                thisScript():reload()
            end)
        elseif status == -1 then
            downloadStatusText = "Ошибка скачивания! Проверьте ссылку."
            isDownloading = false
        end
    end)
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    checkUpdate()

    wait(-1)
end

-- Интерфейс mimgui
local newFrame = imgui.OnFrame(
    function() return showUpdateWindow[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(420, 280), imgui.Cond.FirstUseEver)

        if imgui.Begin(u8"Доступно обновление!", showUpdateWindow, imgui.WindowFlags.NoCollapse) then
            imgui.Text(u8"Текущая версия: " .. CURRENT_VERSION)
            imgui.TextColored(imgui.ImVec4(0.2, 1.0, 0.2, 1.0), u8"Доступна версия: " .. updateData.version)
            
            imgui.Separator()
            imgui.Text(u8"Список изменений:")
            
            -- Окно с текстом изменений
            imgui.BeginChild("ChangelogRegion", imgui.ImVec2(0, 110), true)
            -- ИСПРАВЛЕНИЕ ТУТ: текст из JSON уже в UTF-8, оборачивать в u8() не нужно!
            imgui.TextWrapped(updateData.changelog)
            imgui.EndChild()
            
            imgui.Separator()

            if isDownloading then
                imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.0, 1.0), u8(downloadStatusText))
            else
                if imgui.Button(u8"Установить", imgui.ImVec2(130, 32)) then
                    installUpdate()
                end
                
                imgui.SameLine()
                
                if imgui.Button(u8"Закрыть", imgui.ImVec2(130, 32)) then
                    showUpdateWindow[0] = false
                end
            end

            imgui.End()
        end
    end
)
