import std.experimental.logger;
import std.getopt;
import std.string;
import std.stdio;
import std.file;
import std.regex;
import std.conv;
import hunt.xml;

import std.traits;

class Signal
{
	string name;
	string handler;

	this (string n, string h)
	{
		name = n;
		handler = h;
	}
}

class Widget
{
	string type;
	string id;
	bool givenid = false;
	Signal[] signals;
	Element mainElement;

	this (Element w)
	{
		string prefix;
		mainElement = w;
		Attribute idattr = w.firstAttribute ("id");
		type = w.firstAttribute ("class").getValue();

		if (idattr)
		{
			givenid = true;
			id = idattr.getValue();
		}

		if (type in altPrefix)
			prefix = altPrefix[type];
		else
			prefix = "gtk.";
		
		imports[prefix ~ type[3..$]] = 1;

		widgets ~= this;
	}

	void
	addSignal (Element w)
	{
		string name = w.firstAttribute ("name").getValue();
		string handler = w.firstAttribute ("handler").getValue();

		if (!name.empty && !handler.empty)
		{
			signals ~= new Signal (name, handler);
			if (id is null)
			{
				id = format("w%04d", widgets.length);
				mainElement.appendAttribute (new Attribute ("id", id));
			}
		}
	}

	void dump ()
	{
		tracef ("%s %s", type, id);
		foreach (s; signals)
			tracef("    %s %s", s.name, s.handler);
	}
}

int[string] imports;
Widget[] widgets;
int[string] handlers;


/* when you add a handler to a signal from a parent class, the handler's
 * parameter type must be that of the parent class, not the derived class.
 * there are also cases where the handler must take more than 1 parameter.
 * the default case where the handler takes 1 param of the same type as the
 * widget, there is no need for an entry here
 * This approach is incomplete because you'd really to fill out the complete
 * table of type/signal relationships.
 * This just handles the common issues I've encountered.
 * the first index is the widget type
 * the second index is the signal name
 * the parameter list to use in the handler
 */
string[][string][string] paramType;
void initParamTypes ()
{
	//                                                       first 2 are required the rest is an optional import list
	// paramType["widget"]			["signal"] 			= ["return type", "paramater list", "import list", ...];
	// below is the default if there is no entry here
//	paramType["anytype"]			["*"] 				= ["void", "anytype w"];
	paramType["ApplicationWindow"]	["destroy"] 		= ["void", "Widget w", "gtk.Widget"];
	paramType["ApplicationWindow"]	["key-press-event"]	= ["bool", "GdkEventKey* e, Widget w","gdk.Event","gtk.Widget"];
	paramType["ImageMenuItem"]		["activate"]		= ["void", "MenuItem w", "gtk.MenuItem"];
	paramType["TextEntry"]			["activate"]		= ["void", "Entry w", "gtk.Entry"];
	paramType["CheckButton"]		["toggled"]			= ["void", "ToggleButton w", "gtk.ToggleButton"];
	paramType["AboutDialog"]		["close"]			= ["void", "Dialog w", "gtk.Dialog"];
	paramType["AboutDialog"]		["response"]		= ["void", "int i, Dialog w", "gtk.Dialog"];

}

/* The import for GtkSourceView is gsv.SourceView. this translates it.
 * There may be others to add.
 */
string[string] altPrefix;
void initAltPrefix ()
{
	altPrefix["GtkSourceView"] = "gsv.";
}

int main (string[] args)
{
	string helpmsg = "belleglade transforms glade files into D source files that " ~
		"make gtkd fun to use.\n" ~
		"stub handlers will be created for all defined signal handlers.\n";

	string moduleName = "somemodule";
	string className = "SomeClass";
	string fileName = "mainwinui.glade";
	string output = "somemodule";
	GetoptResult rslt;
	LogLevel ll = LogLevel.trace;
	Document doc;

	if (args.length < 5)
		args ~= ["-h"];
	try
	{
		rslt = getopt(args,
			std.getopt.config.required,
			"input|i", "The glade file you want to transform. The input file must" ~
			" be a valid glade file. Errors in the glade file will not be " ~
			"detected.", &fileName,
			std.getopt.config.required,
			"output|o", "The file to write the resulting module to.", &output,
			std.getopt.config.required,
			"classname|c", "The name of the resulting class.", &className,
			std.getopt.config.required,
			"modulename|m", "The module name of the resulting file.", &moduleName,
			"logLevel|l", "This option controles the LogLevel of the program. "
			~ "See std.logger for more information.", &ll);
	}
	catch (Exception e)
	{
        stderr.writefln("Error processing command line arguments: %s", e.msg);
		rslt.helpWanted = true;
	}

	if(rslt.helpWanted)
	{
		defaultGetoptPrinter(helpmsg, rslt.options);
		return (0);
	}

	initParamTypes ();
	initAltPrefix ();
	try
	{
		doc = Document.load(fileName);
	}
	catch (Exception e)
	{
		error (e.msg);	
		return (-1);
	}

	findWidgets (doc.firstNode ("interface"));

	trace (widgets);

	addExtraImports ();

	// capitalize only the first character 
	string first = capitalize (className);
	string rest = className[1..$];
	className = first[0] ~ rest;
	// re-generate the xml because we might have added an automatic id
	string xml = to!string (doc);
	writeOutput (output, moduleName, className, xml);
	return (0);
}

void
findWidgets (Element top)
{
	Widget wid;
	tracef ("---------- %s %s", top.getName(), top.getType());

	for (Element child = top.firstNode(); child; child = child.nextSibling())
	{
		tracef ("---------- %s <%s>", child.getName(), child.getType());
		if (child.getName() == "object")
		{
			wid = new Widget (child);

			for (Element child2 = child.firstNode(); child2; child2 = child2.nextSibling())
			{
				tracef ("---------- %s <<%s>>", child2.getName(), child2.getType());
				if (child2.getName () == "signal")
				{
					trace ("calling add signal!!!");
					wid.addSignal (child2);
				}
				if (child2.getName () == "child")
					findWidgets (child2);
			}
		}
	}
}

void
addExtraImports ()
{
	foreach (w; widgets)
	{
		if (w.type[3..$] in paramType)
			foreach (s; w.signals)
			{
				if (s.name in paramType[w.type[3..$]])
					foreach (imp; paramType[w.type[3..$]][s.name][2..$])
					{
//tracef ("extra %s", imp);
						imports[imp] = 1;
					}
			}
	}
}

void
writeOutput (string output, string moduleName, string className, string xml)
{
	File f;

	try
	{
		f = File(output, "w");
	}
	catch (Exception e)
	{
		errorf ("Cannot open %s\n%s", output, e.msg);	
	}	

	f.writef ("module %s;\n\n", moduleName);

	writeImports (f);
	defineClass (f, className, xml);
	connectWidgets (f);
	connectHandlers (f);
	defineHandlers (f);
	
	f.writef ("}\n");
}

void writeImports (File f)
{
	f.writef ("import std.stdio;\n");
	foreach (i, x; imports)
		f.writef ("public import %s;\n", i);
}

void defineClass (File f, string name, string xml)
{
	f.writef ("import gtk.Builder;\n\n");
	f.writef ("abstract class %s\n{\n", name);
	f.writef ("	string __gladeString = `%s`;\n", xml);

	f.writef ("	Builder __builder;\n");

	foreach (w; widgets)
		if (w.givenid || (w.signals.length > 0))
			f.writef ("	%s %s;\n", w.type[3..$], w.id);

	f.writef ("\n	this ()\n	{\n");
	f.writef ("		__builder = new Builder ();\n");
	f.writef ("		__builder.addFromString (__gladeString);\n\n");
}

void connectWidgets (File f)
{
	foreach (w; widgets)
		if (w.givenid || (w.signals.length > 0))
			f.writef ("		%s = cast(%s)__builder.getObject(\"%s\");\n", w.id, w.type[3..$], w.id);

	f.writef ("\n");
}

void connectHandlers (File f)
{
	foreach (w; widgets)
	{
		foreach (s; w.signals)
		{
			// if the signal name has 2 dashes, Gtkd appears to leave off the
			// last word when creating the addOn... function
			auto dash = regex ("(.*)-(.*)-(.*)");
			auto matches = matchAll(s.name, dash);
			if (matches.empty)
			{
				dash = regex ("(.*)-(.*)");
				matches = matchAll(s.name, dash);
			}
			
			//there are some signal names with a - instead of camel
			//case, gtkd fixes them, so fix them to match
			//if there are multiple - separated words, only the first 2 are
			//used in the gtkd api
			if (!matches.empty)
			{
				f.writef ("		%s.addOn%s%s(&%s);\n", w.id,
					capitalize(matches.front[1]),
					capitalize(matches.front[2]),
					s.handler);
			}
			else
				f.writef ("		%s.addOn%s(&%s);\n", w.id, capitalize(s.name), s.handler);
		}
	}

	f.writef ("	}\n");
}

void defineHandlers (File f)
{
	string params;
	string rettype;
	foreach (w; widgets)
	{
		foreach (s; w.signals)
		{
			params = "";
			rettype = "void";
			// skip handlers we've already printed
			if(s.handler in handlers)
				break;
			// convert param types where needed
			if (w.type[3..$] in paramType)
			{
//tracef ("widget matched %s", w.type);
				if (s.name in paramType[w.type[3..$]])
				{
//tracef ("signal matched %s", s.name);
					rettype = paramType[w.type[3..$]][s.name][0];
					params = paramType[w.type[3..$]][s.name][1];
				}
			}

			handlers[s.handler] = 1;
			if (params.empty)
				f.writef ("\n	%s %s (%s w)\n", rettype, s.handler, w.type[3..$]);
			else
				f.writef ("\n	%s %s (%s)\n", rettype, s.handler, params);
			f.writef ("	{\n		writeln(\"%s stub called\");\n", s.handler);
			if (rettype == "bool")
				f.writef ("		return true;\n");
			f.writef ("	}\n");
		}
	}
}
