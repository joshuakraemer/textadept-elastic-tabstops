# Elastic Tabstops for Textadept
This is a module for the [Textadept](https://github.com/orbitalquark/textadept) editor that implements [Elastic Tabstops](https://nickgravgaard.com/elastic-tabstops/), a mechanism to align text invented by Nick Gravgaard. With Elastic Tabstops, tabstops are positioned automatically to fit the text between them and to align them with tabstops on adjacent lines. This means only a single tab has to be inserted between columns, rather than inserting manually the required number of tabs or spaces.

## Dependencies
Textadept 11.0

## Installation
1. Save the file [_elastic_tabstops.lua_](elastic_tabstops.lua) to one of Textadept's _modules_ directories, e.g. _~/.textadept/modules/_.

2. Add the following line to _~/.textadept/init.lua_:
	```
	require("elastic_tabstops")
	```

3. Restart Textadept.

## License
This module is provided under the ISC license. See the file [_LICENSE_](LICENSE) for details.
