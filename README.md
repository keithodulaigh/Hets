# Hets (The heterogeneous tool set)

Hets is a parsing, static analysis and proof management tool incorporating various provers and different specification languages, thus providing a tool for heterogeneous specifications. Logic translations are first-class citizens.

### Supported languages

* general-purpose logics: [Propositional](http://en.wikipedia.org/wiki/Propositional_calculus), [QBF](http://en.wikipedia.org/wiki/QBF), [TPTP](http://www.tptp.org/)/SoftFOL, [CASL](http://www.cofi.info/CASL) (FOL), [HasCASL](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/HasCASL/) (HOL)
* logical frameworks: [Isabelle](http://www.cl.cam.ac.uk/research/hvg/Isabelle/), [LF](http://en.wikipedia.org/wiki/LF_%28logical_framework%29), DFOL
* modeling languages: [Meta-Object Facility (MOF)](https://en.wikipedia.org/wiki/Meta-Object_Facility), [Query/View/Transformation (QVT)](https://en.wikipedia.org/wiki/QVT)
* ontologies and constraint languages: [OWL](http://www.w3.org/TR/owl2-overview/), [CommonLogic](http://cl.tamu.edu/), [RelScheme](http://en.wikipedia.org/wiki/Database_schema), ConstraintCASL
* reactive systems: CspCASL, [CoCASL](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/CoCASL/), ModalCASL, [Maude](http://maude.cs.uiuc.edu/)
* programming languages: [Haskell](http://www.haskell.org/), [VSE](http://www.dfki.de/vse/systems/vse/)
* logics of specific tools: Reduce, DMU ([CATIA](http://en.wikipedia.org/wiki/CATIA))

### The following provers have been connected to Hets:

* [minisat](http://minisat.se/) and [zChaff](http://www.princeton.edu/~chaff/zchaff.html), which are SAT solvers,
* [SPASS](http://www.spass-prover.org/), [Vampire](http://en.wikipedia.org/wiki/Vampire_(theorem_prover)), [Darwin](http://combination.cs.uiowa.edu/Darwin/), [Hyper](http://userpages.uni-koblenz.de/~bpelzer/hyper/) and MathServe, which are automatic first-order theorem provers,
* [Pellet](http://clarkparsia.com/pellet/) and [Fact++](http://owl.man.ac.uk/factplusplus/), description logic tableau provers,
* [Leo-II](http://page.mi.fu-berlin.de/cbenzmueller/leo/) and [Satallax](http://www.ps.uni-saarland.de/~cebrown/satallax/), automated higher-order provers,
* [Isabelle](http://www.cl.cam.ac.uk/Research/HVG/Isabelle/), an interactive higher-order theorem prover,
* [CSPCASL-prover](http://dx.doi.org/10.1016/j.entcs.2009.08.018), an Isabelle-based prover for CspCASL,
* [VSE](http://www.dfki.de/vse/systems/vse/), an interactive prover for dynamic logic.

The structuring constructs of the heterogeneous specification language are those of the language [CASL](http://www.cofi.info/CASL), plus some constructs to select languages (logics) and language translations. The heterogeneous specification language of Hets is called [HetCASL](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/HetCASL/index_e.htm). However, Hets can also read other structuring constructs, like those of Haskell, Maude or OWL. All these are mapped to so-called development graphs and processed with a proof calculus for heterogeneous development graphs that allows to decompose global proof obligations into local ones (during this, Hets also needs to compute [colimits](http://en.wikipedia.org/wiki/Limit_%28category_theory%29#Colimits_2) of theories over the involved logics).

Hets is based on a graph of logics and logic translations. The overall architecture is depicted below. Adding new logics and logic translations to Hets can be done with moderate effort by adding some Haskell code to the Hets source. With the [Latin](https://trac.omdoc.org/LATIN/) project, this becomes much easier: logics (and in the near future also logic translations) can be declaratively specified in [LF](http://twelf.plparty.org/wiki/Bibliography_of_LF).

![Architecture of the heterogeneous tool set Hets](https://github.com/spechub/attachment/raw/a0f26aadac374988f7bee3e191e95ca30e7be511/hets2010.png)

## Using Hets

You can try out Hets using the [Web-based interface](http://pollux.informatik.uni-bremen.de:8000/)

#### The best way to use hets is under Ubuntu. Possibly run this OS in a virtual box.
A compressed (1.2G, uncompressed 4.2G) virtual box image can be [downloaded from here](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/vbox-x86-linux). username/password is ubuntu/reverse.

### Installing Hets under Ubuntu Trusty Tahr (14.04)

#### The basic system
```
sudo apt-add-repository ppa:hets/hets
sudo apt-get update
sudo apt-get install hets-core
```

* additionally, you can install (via apt-get) hets-ontology
* for the full system including all of these, use hets instead of hets-core

#### Hets development
For Hets development additionally type in
```
sudo apt-add-repository -s "deb http://ppa.launchpad.net/hets/hets/ubuntu trusty main"
sudo apt-get update
sudo apt-get build-dep hets
```

### Hets Images for Mac OS X 10.9 (Mavericks)

These [Disk images for the Hets application](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/intel-mac/dmgs/) have only limited functionality. (GTK based menus are missing.)

### Hets binaries
(these are usually not needed but may replace the binaries from above)

* Linux x86
	* [Daily snapshot](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/linux/daily/)
	* [Latest release](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/linux/releasedhets.bz2)
	* [All versions](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/linux/versions/)
* Linux x86_64
	* [Daily snapshot](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/linux64/daily/)
	* [Latest release](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/linux64/releasedhets.bz2)
	* [All versions](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/linux64/versions/)
* Intel Mac (Mavericks)
	* [Daily snapshot](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/intel-mac/daily/)
	* [Latest release](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/intel-mac/releasedhets.bz2)
	* [All versions](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/intel-mac/versions/)
* Solaris
	* [Daily snapshot](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/pc-solaris/daily/)
	* [Latest release](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/pc-solaris/releasedhets.bz2)
	* [All versions](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/pc-solaris/versions/)

#### How to use a hets binary?

Just download the binary and put it somewhere in the $PATH.

* Our current linux binaries also rely on gtk-2 and glade-2 libraries for more and better menus. Thus you may need to install additional libraries. Use ldd (or "otools -L hets" on Macs) to see which libraries are missing.)
* For displaying development graphs (with the -g option), you need to install [uDraw(Graph)](http://www.informatik.uni-bremen.de/uDrawGraph/en/) (formerly known as daVinci) that relies on [Tcl/Tk (version 8.4 or 8.5)](http://www.tcl.tk/software/tcltk/8.4.html) (which probably has been already installed on your computer anyway). Make sure uDrawGraph and wish are in your $PATH.

Download the [CASL libraries](http://www.cofi.info/Libraries) and set $HETS_LIB to the folder containing these.

### Quickstart

Hets is called with
```
hets filename
```
or
```
hets -g filename
```
For entering the command line mode, just call
```
hets -I
```
For a short description of the options, call
```
hets --help
```

### Restful Interface
See [RESTful Interface](https://github.com/spechub/Hets/wiki/RESTful-Interface)

### User Documentation

A good starting point is the [Hets user guide](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/UserGuide.pdf) and the [Hets user guide for Common Logic users](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/UserGuideCommonLogic.pdf). Furthermore two vidoes showing a heterogeneous proof are available:

* [A small video showing a heterogeneous proof](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/hets.m2v)
* [A new video (H.264-Codec) showing a heterogeneous proof](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/Hets.mov)

For a formal introduction to hets see the introductory paper [The Heterogeneous Tool Set](http://www.informatik.uni-bremen.de/~till/papers/hets-paper.pdf) by Till Mossakowski, Christian Maeder, Klaus Lüttich and Stefan Wölfl. For more in-depth information about Hets see the thesis [Heterogeneous specification and the heterogeneous tool set](http://www.informatik.uni-bremen.de/~till/papers/habil.pdf) by Till Mossakowski.

For questions related to hets there is a [mailing list](http://www.informatik.uni-bremen.de/mailman/listinfo/hets-users).

### Emacs Mode for CASL specifications

To support writing CASL specifications we have an [emacs mode](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/emacs_mode)

### Including specifications in LaTeX documents

With the option "-o pp.tex" hets can produce nice LaTeX output from your specifictions that can be embedded in your publications using the [hetcasl.sty](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/hetcasl.sty) style file.

## Development

A good starting point is the code documentation for [Hets - the Heterogeneous Tool Set](http://www.informatik.uni-bremen.de/agbkb/forschung/formal_methods/CoFI/hets/src-distribution/versions/Hets/docs/).

Since Hets is rather large and complex we recommend following the interactive session in [Debugging and Testing Hets](https://github.com/spechub/Hets/wiki/Debugging-and-Testing-Hets) to get familiar with the central datastructures of Hets.

The formal background and the general structure of Hets is described in chapter 7 of [Heterogeneous specification and the heterogeneous tool set](http://www.informatik.uni-bremen.de/~till/papers/habil.pdf).

### Haskell

Hets is written in [Haskell](http://www.haskell.org), and is compiled using [GHC](http://www.haskell.org/ghc) using a couple of [language extensions](http://www.haskell.org/ghc/docs/latest/html/users_guide/ghc-language-features.html). Among the Haskell [books and tutorials](http://www.haskell.org/haskellwiki/Books_and_tutorials) we recommend [Real World Haskell](http://book.realworldhaskell.org/).
The [language definition](http://www.haskell.org/onlinereport) covers the Haskell98 standard which we are supposed to stick to in most cases. Make sure that you are familiar with at least the most common [library functions of the Prelude](http://www.haskell.org/onlinereport/prelude-index.html).
For searching or looking up any [library functions](http://www.haskell.org/ghc/docs/latest/html/libraries) you may also try [Hoogle](http://www.haskell.org/hoogle).

Also look into [programming guidelines](http://www.haskell.org/haskellwiki/Programming_guidelines) and [things to avoid in Haskell](http://www.haskell.org/haskellwiki/Things_to_avoid).

### Dependencies
Dependencies can be installed as specified in [Hets Development](#hets-development)

### Contributing changes

Before committing haskell source files you may check compliance to the programming guidelines:
* Use [scan](http://projects.haskell.org/style-scanner/) which can be installed by `cabal install scan`.
* The comments in your haskell sources should not cause `haddock` to fail. After `make` (for re-compiling changed sources) `make doc` will call `haddock`.
* Also check your source with [hlint](http://community.haskell.org/~ndm/hlint/) which you may install by `cabal install hlint`.

Also have a look at the current [Release Notes](https://github.com/spechub/Hets/releases/latest), [Debugging and Testing Hets](https://github.com/spechub/Hets/wiki/Debugging-and-Testing-Hets),[Code Review](https://github.com/spechub/Hets/wiki/Code-Review) and [Branching](https://github.com/spechub/Hets/wiki/Branching).

If you want to participate in the Hets development feel free to tell us via our [mailing list](http://www.informatik.uni-bremen.de/mailman/listinfo/hets-devel) for Hets developers. This mailing list can also be read via http://news.gmane.org/gmane.comp.lang.hets.devel.

If you wish to make larger changes we generally recommend [forking](https://help.github.com/articles/fork-a-repo) this repository. You can however request access to this repository if you plan on contributing regularly.

## Troubleshooting & Useful Tools

## Hints for contributors switching from svn to git

* We recommend the [Git - SVN Crash Course](http://git-scm.com/course/svn.html).
* For github specific info on checking out this repository see [Fetching a remote](https://help.github.com/articles/fetching-a-remote).

## License

The Hets source code is licensed under the GPLv2 or higher
