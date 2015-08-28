# ensime-vim

ENSIME for the Editor of the Beast (Vim)

# demo

![alt tag](https://raw.github.com/yazgoo/ensime4vim/master/demo.gif)

# howto

You need vim with ruby enabled, which you can check via:

    $ vim --version|grep +ruby -o
    +ruby

For example under ubuntu:
    
    $ sudo apt-get install vim-gnome

You need to clone this repository first.
All the following commands should be run from your scala directory.

First you need ensime sbt plugin:    
    
    $ echo addSbtPlugin("org.ensime" % "ensime-sbt" % "0.1.7") >> ~/.sbt/0.13/plugins/plugins.sbt

Then, generate .ensime file:

    $ sbt gen-ensime

In a new terminal, start ensime server:

    $ /path/to/ensime4vim/start_ensime.sh .ensime

In another terminal, start ensime bridge:

    $ /path/to/ensime4vim/ensime.rb

Finally, launch vim with the plugin and the file(s) you want to edit:

    $ vim -S /path/to/ensime4vim/ensime.vim src/scaloid/example/HelloScaloid.scala

# developer info

Needs some love. Please get in contact if you would like to help! There was some old work that is no longer compatible with the ENSIME server but it may serve as a good starting place:

* https://github.com/megaannum/vimside
* https://github.com/jlc/envim
* https://github.com/psuter/vim-ensime \ https://github.com/andreypopp/ensime

Reference launch script is https://gist.github.com/fommil/4ff3ad5b134280de5e46 (only works on Linux but should be adaptable to OS X)
