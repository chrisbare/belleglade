# belleglade
a tool to make working with GtkD and glade easier by generating a D class that connects handlers to methods

Inspired by https://github.com/burner/gladeD but written from scratch.

Unlike gladeD, the class generated is not derived from a Gtk class, so you can have multiple windows in one file if you prefer. Belleglade also takes care of some eccentricities in Gtk's naming
conventions when the function names get too long.

Belleglade processes a .glade file and generates a .d file based on it. Any widget which has an ID assigned in glade becomes a class member. Any signals defined are attached to a class method of the
same name. This makes it easy to create another class and override all the handler methods to implment your functionality.

Example
-------
Given a file called exampleui.glade, run belleglade:
`belleglade -i exampleui.glade -o exampleui.d -c ExampleUI -m exampleui`
This generates exampleui.d containing:
```d
module exampleui;

import std.stdio;
public import gtk.ApplicationWindow;
public import gtk.Box;
public import gtk.Button;
import gtk.Builder;

abstract class ExampleUI
{
	string __gladeString = "XML from glade file goes here so it is built into your code";
	Builder __builder;
	ApplicationWindow mainWindow;
	Button redAlert;
	Button w0004;	// note if you do not assign an ID, but do define a handler, an id is generated

	this ()
	{
		__builder = new Builder ();
		__builder.addFromString (__gladeString);

		mainWindow = cast(ApplicationWindow)__builder.getObject("mainWindow");
		redAlert = cast(Button)__builder.getObject("redAlert");
		w0004 = cast(Button)__builder.getObject("w0004");

		redAlert.addOnClicked(&redAlertHandler);
		w0004.addOnClicked(&genericButtonHandler);
	}

	void redAlertHandler (Button w)
	{
		writeln("redAlertHandler stub called");
	}

	void genericButtonHandler (Button w)
	{
		writeln("genericButtonHandler stub called");
	}
}
```
Then you can subclass ExampleUI and define your own handlers.
```
class Example: ExampleUI
{
	override
	void redAlertHandler (Button w)
	{
		writeln("Red Alert Handler stub overridden in subclass");
	}
}
```
A working version of this example is in the example directory.

Usage
-----
-i      --input Required: The glade file you want to transform. The input file must be a valid glade file. Errors in the glade file will not be detected.
-o     --output Required: The file to write the resulting module to.
-c  --classname Required: The name of the resulting class.
-m --modulename Required: The module name of the resulting file.
-h       --help           This help information


Notes
-----
The generated object corresponds to the <interface> and is not a widget.
if an object has no id and no signal handlers, it is ignored.
if an object has no id but has signal handlers, an id is automatically assigned.
if it has an id, it's type is added to the import list. (no dupes)
if it has an id, a variable is created for it and populated.
if it has signals, a delegate is created and connected.
the widget namespace is flatened, so all id's must be unique.
License
-------
GPL3
