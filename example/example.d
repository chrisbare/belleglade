module example;

import std.stdio;
import exampleui;

/* inherit from the generated class and override the signal handlers */
class Example: ExampleUI
{
	override
	void redAlertHandler (Button w)
	{
		writeln("Red Alert Handler stub overridden in subclass");
	}
}
