{CompositeDisposable, Point, Range} = require 'atom'

child_process = require( 'child_process' )

if process.platform is "darwin"
    osaCommands = require( './osa-commands.coffee' )
else
    # windows' id to be used with xdotool (only linux)
    idAtom = ""
    idTerminal = ""


String::addSlashes = ->
  @replace(/[\\"]/g, "\\$&").replace /\u0000/g, "\\0"


sleep = (ms) ->
  start = new Date().getTime()
  continue while new Date().getTime() - start < ms


module.exports =
  config:
    terminalToUse:
      title: 'Terminal emulator to use (Linux only)'
      description: 'Terminal emulator program to open IPython. Default is xterm, gnome typically uses gnome-terminal, KDE uses konsole, etc. Linux only.'
      type: 'string'
      default: 'xterm'
      order: 1
    runpylab:
      title: 'Run IPython with %pylab magic'
      description: 'When opening IPython, %pylab magic will be executed.'
      type: 'boolean'
      default: true
      order: 2
    autoreload:
      title: 'Enable IPython autoreload'
      description: 'All libraries and imports are automatically reloaded at each execution.'
      type: 'boolean'
      default: true
      order: 3
    setwd:
      title: 'Set working directory to script directory'
      description: 'The IPython working directory will be set to the same as the script directory. If a file from a different path is run, the working directory will be updated accordingly.'
      type: 'boolean'
      default: true
      order: 4
    focusOnTerminal:
      title: 'Focus on terminal after sending commands'
      description: 'After code is sent, bring focus to the terminal.'
      type: 'boolean'
      default: false
      order: 5
    notifications:
      title: 'Atom notifications'
      type: 'boolean'
      default: true
      description: 'Send notifications in case of errors/warnings'
      order: 6

  subscriptions: null


  activate: (state) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ipython-exec:run-file': => @runFile()
      'ipython-exec:open-terminal': => @openTerminal()
      'ipython-exec:setwd': => @setWorkingDirectory()


  deactivate: ->
    @subscriptions.dispose()


  osaPrepareCmd: ( CMDs, VARs ) ->
    return "" if CMDs.length is 0
    CMD = "osascript"
    for key, value of VARs
        CMD += " -e 'set " + key + " to "
        if typeof(value) == "string"
            CMD += '"' + value + '"'
        else
            CMD += value
        CMD += "'"
    if typeof(CMDs) is "object"
        for c in CMDs
            CMD += " -e '" + c.trim() + "'"
    else
        CMD += " -e '" + CMDs.trim() + "'"
    return CMD


  # Change grammar to "Python (IDE)"
  changeGrammar: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    if editor.getGrammar().scopeName is 'source.python'
        editor.setGrammar( atom.grammars.grammarForScopeName('source.python.ipython-exec') )


  isTerminalOpen: ->
    if process.platform is "linux"
        try child_process.execSync( "xdotool getwindowname "+idTerminal ); return true
        catch error then return false
    else
        CMD = @osaPrepareCmd( osaCommands.isTerminalOpen, {} )
        val = child_process.execSync( CMD ).toString()
        return ( val[0] is "t" )


  openTerminal: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    @changeGrammar()

    shellProfile = atom.config.get('ipython-exec.shellProfile')

    if process.platform is "linux"
        return if @isTerminalOpen()
        idAtom = child_process.execSync( 'xdotool getactivewindow' ).toString()
        CMD = 'gnome-terminal --title=ATOM-IPYTHON-SHELL'  # atom.config.get('ipython-exec.terminalToUse')
        if shellProfile
            CMD += " --profile="+shellProfile
        CMD += ' -e ipython &'
        child_process.exec( CMD )
        idTerminal = child_process.execSync( 'xdotool search --sync --name ATOM-IPYTHON-SHELL | head -1', {stdio: 'pipe' } ).toString()
        if !atom.config.get('ipython-exec.focusOnTerminal')
            child_process.execSync( 'xdotool windowactivate '+idAtom )
    else
        CMD = @osaPrepareCmd( osaCommands.openTerminal, {'myProfile': shellProfile} )
        child_process.execSync( CMD )
        if atom.config.get('ipython-exec.focusOnTerminal')
            CMD = @osaPrepareCmd( 'tell application "iTerm" to activate', {} )
            child_process.execSync( CMD )

    if atom.config.get('ipython-exec.notifications')
        atom.notifications.addSuccess("[ipython-exec] ipython terminal connected")


  sendCode: (code) ->
    return if not code
    if not @isTerminalOpen()
        if atom.config.get('ipython-exec.notifications')
            atom.notifications.addError("[ipython-exec] Open the ipython terminal first")
        return

    if process.platform is "darwin" then @osx(code)
    else @linux(code)


  setWorkingDirectory: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    if not @isTerminalOpen()
        if atom.config.get('ipython-exec.notifications')
            atom.notifications.addError("[ipython-exec] Open the ipython terminal first")
        return
    @changeGrammar()

    cwd = editor.getPath()
    if not cwd
        if atom.config.get('ipython-exec.notifications')
            atom.notifications.addWarning("[ipython-exec] Cannot get working directory from file: save it first")
        return
    if atom.config.get('ipython-exec.notifications')
        atom.notifications.addSuccess("[ipython-exec] Changing working directory")
    @sendCode( ('cd "' + cwd.substring(0, cwd.lastIndexOf('/')) + '"').addSlashes() )


  runFile: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    if not @isTerminalOpen()
        # if atom.config.get('ipython-exec.notifications')
            # atom.notifications.addError("[ipython-exec] Open the ipython terminal first")
        # return
        @openTerminal()
        sleep(100)
        @setWorkingDirectory()
        sleep(200)
        @sendCode( '%pylab' )
        sleep(3000)
        @sendCode( '%load_ext autoreload' )
        sleep(100)
        @sendCode( '%autoreload 2' )
        sleep(100)
    @changeGrammar()

    cwd = editor.getPath()
    if not cwd
        if atom.config.get('ipython-exec.notifications')
            atom.notifications.addWarning("[ipython-exec] Cannot get working directory from file: save it first")
        return
    if atom.config.get('ipython-exec.notifications')
        atom.notifications.addSuccess("[ipython-exec] Running file...")
    @sendCode( '%run "' + cwd + '"' )


  osx: (codeToExecute) ->
    if atom.config.get 'ipython-exec.focusOnTerminal'
        CMD = @osaPrepareCmd( 'tell application "iTerm" to activate', {} )
        child_process.execSync( CMD ).toString()
    CMD = @osaPrepareCmd( osaCommands.writeText, {'myCode':codeToExecute} )
    child_process.execSync( CMD )


  linux: (codeToExecute) ->
    child_process.execSync( 'xdotool windowactivate '+idTerminal )
    #child_process.execSync( 'xvkbd -text "'+codeToExecute+'\\n"' )
    child_process.execSync( 'xdotool type --delay 10 --clearmodifiers "'+codeToExecute+'"' )
    child_process.execSync( 'xdotool key --clearmodifiers Return' )
    if !atom.config.get 'ipython-exec.focusOnTerminal'
        child_process.execSync( 'xdotool windowactivate '+idAtom )
