/**
 * main.d
 *
 * an example of how to use belleglade in a program
 *
 * Based on the Gtkmm example by:
 * Jonathon Jongsma
 *
 * and the original GTK+ example by:
 * (c) 2005-2006, Davyd Madeley
 *
 * Authors:
 *   Chris Bare (D/belleglade version)
 *   Jonas Kivi (D version)
 *   Jonathon Jongsma (C++ version)
 *   Davyd Madeley (C version)
 */

module main;

import example;
import std.stdio;


import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;

int main(string[] args)
{
	Application application;

		writeln("WRWEs sdf sdf sfdsfd fsd");


	void activate(GioApplication app)
	{
		Example  ex = new Example ();

		application.addWindow (ex.mainWindow);
		
		ex.mainWindow.showAll();
	}

	application = new Application("org.belleglade.example", GApplicationFlags.FLAGS_NONE);
	application.addOnActivate(&activate);
	return application.run(args);
}
