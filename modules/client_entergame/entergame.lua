EnterGame = {}

-- private variables
local loadBox
local enterGame
local protocolLogin

-- private functions
local function onError(protocol, message, errorCode)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  if not errorCode then
    EnterGame.clearAccountFields()
  end

  local errorBox = displayErrorBox(tr("Login Error"), message)
  connect(errorBox, {onOk = EnterGame.show})
end

local function onSessionKey(protocol, sessionKey)
  G.sessionKey = sessionKey
end

local function onCharacterList(protocol, characters, account, otui)
  -- Save 'Stay logged in' setting
  g_settings.set("staylogged", enterGame:getChildById("stayLoggedBox"):isChecked())

  if enterGame:getChildById("rememberPasswordBox"):isChecked() then
    local account = g_crypt.encrypt(G.account)
    local password = g_crypt.encrypt(G.password)

    g_settings.set("account", account)
    g_settings.set("password", password)

    g_settings.set("autologin", enterGame:getChildById("autoLoginBox"):isChecked())
  else
    EnterGame.clearAccountFields()
  end

  loadBox:destroy()
  loadBox = nil

  for _, characterInfo in pairs(characters) do
    if characterInfo.previewState and characterInfo.previewState ~= PreviewState.Default then
      characterInfo.worldName = characterInfo.worldName .. ", Preview"
    end
  end

  CharacterList.create(characters, account, otui)
  CharacterList.show()
end

local function onUpdateNeeded(protocol, signature)
  loadBox:destroy()
  loadBox = nil

  if EnterGame.updateFunc then
    local continueFunc = EnterGame.show
    local cancelFunc = EnterGame.show
    EnterGame.updateFunc(signature, continueFunc, cancelFunc)
  else
    local errorBox = displayErrorBox(tr("Update needed"), tr("Your client needs updating, try redownloading it."))
    connect(errorBox, {onOk = EnterGame.show})
  end
end

-- public functions
function EnterGame.init()
  enterGame = g_ui.displayUI("entergame")
  g_keyboard.bindKeyDown("Ctrl+G", EnterGame.openWindow)

  local account = g_settings.get("account")
  local password = g_settings.get("password")
  local stayLogged = g_settings.getBoolean("staylogged")
  local autologin = g_settings.getBoolean("autologin")
  local clientVersion = g_settings.getInteger("client-version")
  if clientVersion == 0 then
    clientVersion = 1074
  end

  EnterGame.setAccountName(account)
  EnterGame.setPassword(password)

  enterGame:getChildById("autoLoginBox"):setChecked(autologin)
  enterGame:getChildById("stayLoggedBox"):setChecked(stayLogged)

  EnterGame.toggleAuthenticatorToken(clientVersion, true)
  EnterGame.toggleStayLoggedBox(clientVersion, true)

  enterGame:hide()

  if g_app.isRunning() and not g_game.isOnline() then
    enterGame:show()
  end
end

function EnterGame.firstShow()
  EnterGame.show()

  local account = g_crypt.decrypt(g_settings.get("account"))
  local password = g_crypt.decrypt(g_settings.get("password"))
  local host = g_settings.get("host")
  local autologin = g_settings.getBoolean("autologin")
  if #host > 0 and #password > 0 and #account > 0 and autologin then
      addEvent(
          function()
              if not g_settings.getBoolean("autologin") then
                  return
              end
              EnterGame.doLogin()
          end
      )
  end
end

function EnterGame.terminate()
  g_keyboard.unbindKeyDown("Ctrl+G")
  enterGame:destroy()
  enterGame = nil
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
  if protocolLogin then
    protocolLogin:cancelLogin()
    protocolLogin = nil
  end
  EnterGame = nil
end

function EnterGame.show()
  if loadBox then
    return
  end
  enterGame:show()
  enterGame:raise()
  enterGame:focus()
end

function EnterGame.hide()
  enterGame:hide()
end

function EnterGame.openWindow()
  if g_game.isOnline() then
    CharacterList.show()
  elseif not g_game.isLogging() and not CharacterList.isVisible() then
    EnterGame.show()
  end
end

function EnterGame.setAccountName(account)
  local account = g_crypt.decrypt(account)
  enterGame:getChildById("accountNameTextEdit"):setText(account)
  enterGame:getChildById("accountNameTextEdit"):setCursorPos(-1)
  enterGame:getChildById("rememberPasswordBox"):setChecked(#account > 0)
end

function EnterGame.setPassword(password)
  local password = g_crypt.decrypt(password)
  enterGame:getChildById("accountPasswordTextEdit"):setText(password)
end

function EnterGame.clearAccountFields()
  enterGame:getChildById("accountNameTextEdit"):clearText()
  enterGame:getChildById("accountPasswordTextEdit"):clearText()
  enterGame:getChildById("authenticatorTokenTextEdit"):clearText()
  enterGame:getChildById("accountNameTextEdit"):focus()
  g_settings.remove("account")
  g_settings.remove("password")
end

function EnterGame.toggleAuthenticatorToken(clientVersion, init)
  local enabled = (clientVersion >= 1072)
  if enabled == enterGame.authenticatorEnabled then
    return
  end

  enterGame:getChildById("authenticatorTokenLabel"):setOn(enabled)
  enterGame:getChildById("authenticatorTokenTextEdit"):setOn(enabled)

  local newHeight = enterGame:getHeight()
  local newY = enterGame:getY()
  if enabled then
    newY = newY - enterGame.authenticatorHeight
    newHeight = newHeight + enterGame.authenticatorHeight
  else
    newY = newY + enterGame.authenticatorHeight
    newHeight = newHeight - enterGame.authenticatorHeight
  end

  if not init then
    enterGame:breakAnchors()
    enterGame:setY(newY)
    enterGame:bindRectToParent()
  end

  enterGame:setHeight(newHeight)
  enterGame.authenticatorEnabled = enabled
end

function EnterGame.toggleStayLoggedBox(clientVersion, init)
  local enabled = (clientVersion >= 1074)
  if enabled == enterGame.stayLoggedBoxEnabled then
    return
  end

  enterGame:getChildById("stayLoggedBox"):setOn(enabled)

  local newHeight = enterGame:getHeight()
  local newY = enterGame:getY()
  if enabled then
    newY = newY - enterGame.stayLoggedBoxHeight
    newHeight = newHeight + enterGame.stayLoggedBoxHeight
  else
    newY = newY + enterGame.stayLoggedBoxHeight
    newHeight = newHeight - enterGame.stayLoggedBoxHeight
  end

  if not init then
    enterGame:breakAnchors()
    enterGame:setY(newY)
    enterGame:bindRectToParent()
  end

  enterGame:setHeight(newHeight)
  enterGame.stayLoggedBoxEnabled = enabled
end

function EnterGame.doOpenCreateAccountWindow(self)
  self.hide()
  CreateAccount.show()
end

function EnterGame.doLoginAgain()
  EnterGame.hide()
  protocolLogin = ProtocolLogin.create()
  protocolLogin.onLoginError = onError
  protocolLogin.onSessionKey = onSessionKey
  protocolLogin.onCharacterList = onCharacterList
  protocolLogin.onUpdateNeeded = onUpdateNeeded

  loadBox = displayCancelBox(tr("Please wait"), tr("Connecting to login server..."))
  connect(
      loadBox,
      {
          onCancel = function(msgbox)
              loadBox = nil
              protocolLogin:cancelLogin()
              EnterGame.show()
          end
      }
  )

  g_game.setClientVersion(G.clientVersion)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(G.clientVersion))
  g_game.chooseRsa(G.host)

  if modules.game_things.isLoaded() then
    protocolLogin:login(G.host, G.port, G.account, G.password, G.authenticatorToken, G.stayLogged)
  else
    loadBox:destroy()
    loadBox = nil
    EnterGame.show()
  end
end

function EnterGame.doLogin()
  G.account = enterGame:getChildById("accountNameTextEdit"):getText()
  G.password = enterGame:getChildById("accountPasswordTextEdit"):getText()
  G.authenticatorToken = enterGame:getChildById("authenticatorTokenTextEdit"):getText()
  G.stayLogged = enterGame:getChildById("stayLoggedBox"):isChecked()

  G.host = "127.0.0.1"
  G.port = 7171

  if g_app.hasStartupArg("--test-server") then
    G.host = "127.0.0.1"
    G.port = 7171
  end

  G.clientVersion = 1098

  EnterGame.hide()

  if g_game.isOnline() then
    local errorBox = displayErrorBox(tr("Login Error"), tr("Cannot login while already in game."))
    connect(errorBox, {onOk = EnterGame.show})
    return
  end

  g_settings.set("host", G.host)
  g_settings.set("port", G.port)
  g_settings.set("client-version", G.clientVersion)

  protocolLogin = ProtocolLogin.create()
  protocolLogin.onLoginError = onError
  protocolLogin.onSessionKey = onSessionKey
  protocolLogin.onCharacterList = onCharacterList
  protocolLogin.onUpdateNeeded = onUpdateNeeded

  loadBox = displayCancelBox(tr("Please wait"), tr("Connecting to login server..."))
  connect(
      loadBox,
      {
          onCancel = function(msgbox)
              loadBox = nil
              protocolLogin:cancelLogin()
              EnterGame.show()
          end
      }
  )

  g_game.setClientVersion(G.clientVersion)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(G.clientVersion))
  g_game.chooseRsa(G.host)

  if modules.game_things.isLoaded() then
    protocolLogin:login(G.host, G.port, G.account, G.password, G.authenticatorToken, G.stayLogged)
  else
    loadBox:destroy()
    loadBox = nil
    EnterGame.show()
  end
end
