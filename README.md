# ensime-vim

ENSIME for the Editor of the Beast (Vim)

# demo

![alt tag](https://raw.github.com/yazgoo/ensime-vim/master/demo.gif)

# howto

You need vim with ruby enabled, which you can check via:

    $ vim --version|grep +ruby -o
    +ruby

For example under ubuntu:
    
    $ sudo apt-get install vim-gnome

You need to clone this repository first.
All the following commands should be run from your scala directory.

First you need ensime sbt plugin:    
    
    $ echo addSbtPlugin("org.ensime" % "ensime-sbt" % "0.1.7") \
        >> ~/.sbt/0.13/plugins/plugins.sbt

Then, generate .ensime file:

    $ sbt gen-ensime

In a new terminal, start ensime server:

    $ /path/to/ensime4vim/start_ensime.sh .ensime

In another terminal, start ensime bridge:

    $ /path/to/ensime4vim/ensime.rb

Finally, launch vim with the plugin and the file(s) you want to edit:

    $ vim -S /path/to/ensime4vim/ensime.vim src/scaloid/example/HelloScaloid.scala

# available commands


command         |   description
----------------|----------------------------------------------------------
EnType          | displays type under cursor
EnDocUri        | displays document url under cursor
EnTypeCheck     | launch a check on current file (launched on save)
EnCompleteFunc  | get an autocompletion menu (via ctrl+X ctrl+U) - blocking


# design

![alt tag](https://raw.github.com/yazgoo/ensime-vim/master/ensime-vim.png)

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
