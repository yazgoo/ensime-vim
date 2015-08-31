
# ensime-vim

[![Join the chat at https://gitter.im/ensime/ensime-vim](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ensime/ensime-vim?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build Status](https://drone.io/github.com/yazgoo/ensime-vim/status.png)](https://drone.io/github.com/yazgoo/ensime-vim/latest)

ENSIME for the Editor of the Beast (Vim)

# demo

![alt tag](https://raw.github.com/yazgoo/ensime-vim/master/doc/demo.gif)

# howto

You need ensime\_bridge gem:

    $ sudo gem install ensime_bridge

You should also export your BROWSER variable, for example in your bashrc:

    export BROWSER=firefox

All the following commands should be ran from your scala directory.

First you need ensime sbt plugin:    
    
    $ echo addSbtPlugin("org.ensime" % "ensime-sbt" % "0.1.7") \
        >> ~/.sbt/0.13/plugins/plugins.sbt

Then, generate .ensime file:

    $ sbt gen-ensime

Then install vim plugin, with [Vundle](https://github.com/VundleVim/Vundle.vim),
by adding to your .vimrc:

    Plugin 'ensime/ensime-vim'

Or if you're using neovim, with [vim-plug](https://github.com/junegunn/vim-plug)
by adding to your .nvimrc:

    Plug 'ensime/ensime-vim'

Then by doing a :PlugInstall and a :UpdateRemotePlugins under neovim

Finally, launch vim with the file(s) you want to edit:

    $ vim src/scaloid/example/HelloScaloid.scala

# available commands


command         |   description                                                | vim | neovim
----------------|--------------------------------------------------------------|-----|-----------------
EnType          | displays type under cursor                                   |  x  |   x
EnDocUri        | displays documentation url under cursor                      |  x  |   x
EnDocBrowse     | launch $BROWSER (env variable) documentation url             |  x  |   x
EnTypeCheck     | launch a check on current file (launched on save)            |  x  |   x
EnCompleteFunc  | get an autocompletion menu (via ctrl+X ctrl+U) - blocking    |  x  |   x


# design

![alt tag](https://raw.github.com/yazgoo/ensime-vim/master/doc/ensime-vim.png)

Since vim does not support asynchronous flows,
a bridge is used to send and receive messages from ensime,
keeping a unique connection.
The vim plugin regularly checks for new events kept by the bridge 
(currently when the cursor is moved) using multiple connections.

# developer info

Needs some love. Please get in contact if you would like to help! There was some old work that is no longer compatible with the ENSIME server but it may serve as a good starting place:

* https://github.com/megaannum/vimside
* https://github.com/jlc/envim
* https://github.com/psuter/vim-ensime \ https://github.com/andreypopp/ensime

Reference launch script is https://gist.github.com/fommil/4ff3ad5b134280de5e46 (only works on Linux but should be adaptable to OS X)
