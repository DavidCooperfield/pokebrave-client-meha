-- private variables
local topMenu
local fpsUpdateEvent = nil

-- private functions
local function addButton(id, description, icon, callback, panel, toggle, front, index)
  local class
  if toggle then
    class = 'TopToggleButton'
  else
    class = 'TopButton'
  end
  
  if topMenu.reverseButtons then
    front = not front
  end

  local button = panel:getChildById(id)
  if not button then
    button = g_ui.createWidget(class)
    if front then
      panel:insertChild(1, button)
    else
      panel:addChild(button)
    end
  end
  button:setId(id)
  button:setTooltip(description)
  button:setIcon(resolvepath(icon, 3))
  button.onMouseRelease = function(widget, mousePos, mouseButton)
    if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton and mouseButton ~= MouseTouch then
      callback()
      return true
    end
  end
  button.onTouchRelease = button.onMouseRelease
  if not button.index and type(index) == 'number' then
    button.index = index
  end
  
  return button
end

local function resize(reset)
  if ( reset ) then
    topMenu:setWidth(120)
  else
    local width = 0
    for i, child in pairs(topMenu:getChildren()) do 
	  width = width + child:getWidth()
    end
    topMenu:setWidth(width + 82)
  end
end

-- public functions
function init()
  connect(g_game, { onGameStart = online,
                    onGameEnd = offline,
                    onPingBack = updatePing })

  topMenu = g_ui.createWidget('TopMenu', g_ui.getRootWidget())    
  resize(true)
  
  if g_game.isOnline() then
    scheduleEvent(online, 10)
  end
  
  updateFps()  
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                       onGameEnd = offline,
                       onPingBack = updatePing })
  removeEvent(fpsUpdateEvent)
  
  topMenu:destroy()
end

function online()
  if topMenu.hideIngame then
    hide()
  end
  
  showGameButtons()   
  scheduleEvent(function()  
    resize(false) 
  end, 300)

  if topMenu.pingLabel then
    addEvent(function()
      if modules.client_options.getOption('showPing') and (g_game.getFeature(GameClientPing) or g_game.getFeature(GameExtendedClientPing)) then
        topMenu.pingLabel:show()
      else
        topMenu.pingLabel:hide()      
      end
    end)
  end
end

function offline()
  if topMenu.hideIngame then
    show()
  end
	
  resize(true)
  hideGameButtons()
  
  if topMenu.pingLabel then
    topMenu.pingLabel:hide()
  end
end

function updateFps()
  if not topMenu.fpsLabel then return end
  fpsUpdateEvent = scheduleEvent(updateFps, 500)
  text = 'FPS: ' .. g_app.getFps()
  topMenu.fpsLabel:setText(text)
end

function updatePing(ping)

  if not topMenu.pingLabel then return end
  if g_proxy and g_proxy.getPing() > 0 then
    ping = g_proxy.getPing()
  end
  
  local text = 'Ping: '
  local color
  if ping < 0 then
    text = text .. "??"
    color = 'yellow'
  else
    text = text .. ping .. ' ms'
    if ping >= 500 then
      color = 'red'
    elseif ping >= 250 then
      color = 'yellow'
    else
      color = 'green'
    end
  end
  topMenu.pingLabel:setColor(color)
  topMenu.pingLabel:setText(text)
end

function setPingVisible(enable)
  if not topMenu.pingLabel then return end
  topMenu.pingLabel:setVisible(enable)
end

function setFpsVisible(enable)
  if not topMenu.fpsLabel then return end
  topMenu.fpsLabel:setVisible(enable)
end

function addLeftButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.leftButtonsPanel, false, front, index)
end

function addLeftToggleButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.leftButtonsPanel, true, front, index)
end

function addRightButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.rightButtonsPanel, false, front, index)
end

function addRightToggleButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.rightButtonsPanel, true, front, index)
end

function addLeftGameButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.leftGameButtonsPanel, false, front, index)
end

function addLeftGameToggleButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.leftGameButtonsPanel, true, front, index)
end

function addRightGameButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.rightGameButtonsPanel, false, front, index)
end

function addRightGameToggleButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.rightGameButtonsPanel, true, front, index)
end

function showGameButtons()
  topMenu.leftGameButtonsPanel:show()
  topMenu.rightGameButtonsPanel:show()
end

function hideGameButtons()
  topMenu.leftGameButtonsPanel:hide()
  topMenu.rightGameButtonsPanel:hide()
end

function getButton(id)
  return topMenu:recursiveGetChildById(id)
end

function getTopMenu()
  return topMenu
end

function hide()
  topMenu:hide()
  if not topMenu.hideIngame then
    modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'parent', AnchorTop)
  end
  if modules.game_stats then
    modules.game_stats.show()
  end
end

function show()
  topMenu:show()
  if not topMenu.hideIngame then
    modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'topMenu', AnchorBottom)
  end
  if modules.game_stats then
    modules.game_stats.hide()
  end
end

