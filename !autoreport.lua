script_name("AutoUpdater")
script_version("1.0.0")

local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- ================= НАСТРОЙКИ ССЫЛОК И ВЕРСИИ =================
-- Версию можно писать как угодно: "1.2.10b", "2.0-fix", "beta_3"
local CURRENT_VERSION = "1.0.0" 

-- ВНИМАНИЕ: Ссылки обязательно должны быть Raw (прямой текст), а не страница гитхаба!
local INFO_URL   = "https://raw.githubusercontent.com/USER/REPO/main/update.json"
local SCRIPT_URL = "https://raw.githubusercontent.com/USER/REPO/main/script.lua"
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
    
    -- Скачиваем JSON во временный файл без зависания игры
    downloadUrlToFile(INFO_URL, tempFilePath, function(id, status, p1, p2)
        if status == 6 then -- Загрузка завершена успешно
            if doesFileExist(tempFilePath) then
                local file = io.open(tempFilePath, "r")
                if file then
                    local content = file:read("*a")
                    file:close()
                    os.remove(tempFilePath) -- Удаляем временный файл

                    -- Парсим JSON
                    local ok, parsed = pcall(decodeJson, content)
                    if ok and parsed and parsed.version then
                        -- Очищаем от случайных пробелов по краям
                        local remoteVer = tostring(parsed.version):match("^%s*(.-)%s*$")
                        local currentVer = tostring(CURRENT_VERSION):match("^%s*(.-)%s*$")

                        -- Если версия на сервере отличается от нашей (например 1.2.10b ~= 1.0.0)
                        if remoteVer ~= currentVer then
                            updateData.version = remoteVer
                            updateData.changelog = parsed.changelog or "Список изменений не указан."
                            showUpdateWindow[0] = true -- Показываем окно с кнопкой
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
    
    local currentScriptPath = thisScript().path -- Путь к текущему запускаемому файлу
    
    downloadUrlToFile(SCRIPT_URL, currentScriptPath, function(id, status, p1, p2)
        if status == 6 then -- Закачка завершена
            downloadStatusText = "Успешно! Перезагрузка скрипта..."
            lua_thread.create(function()
                wait(1200)
                thisScript():reload() -- Перезапуск скрипта уже с новой версией
            end)
        elseif status == -1 then -- Ошибка
            downloadStatusText = "Ошибка скачивания! Проверьте ссылку."
            isDownloading = false
        end
    end)
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    -- Запуск проверки обновления при загрузке скрипта
    checkUpdate()

    wait(-1)
end

-- Интерфейс mimgui (Окно с уведомлением и кнопкой)
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
            
            -- Окно с текстом изменений (со скроллом)
            imgui.BeginChild("ChangelogRegion", imgui.ImVec2(0, 110), true)
            imgui.TextWrapped(u8(updateData.changelog))
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
